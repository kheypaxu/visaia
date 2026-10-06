import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:visaia/screens/dashboard_screens/view_income.dart';

class IncomeEstimationScreen extends StatefulWidget {
  final String userId;
  final String activeFarmId;

  const IncomeEstimationScreen({
    super.key,
    required this.userId,
    required this.activeFarmId,
  });

  @override
  State<IncomeEstimationScreen> createState() => _IncomeEstimationScreenState();
}

class _IncomeEstimationScreenState extends State<IncomeEstimationScreen> {
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color accentGreen = Color(0xFF7BC72E);
  static const Color softRed = Color(0xFFFFDADA);
  static const Color deepRed = Color(0xFFBA1A1A);

  bool _isLoading = true;
  bool _isExportingPdf = false;
  String? _errorMessage;
  double _grossIncome = 0;
  double _totalYield = 0;
  double _totalLosses = 0;
  double _avgMarketPrice = 0;
  List<_CropItemInfo> _pendingAuditCrops = [];
  List<_CropItemInfo> _completedCrops = [];
  List<_MonthlyRevenue> _monthlyRevenues = [];
  List<String> _completedCycleIds = [];
  bool _showOneYear = false;
  Map<String, double> _rawMonthlyIncome = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant IncomeEstimationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeFarmId != widget.activeFarmId) {
      _loadData();
    }
  }

  String _getUserFriendlyError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to access this data.';
        case 'unavailable':
          return 'Service is temporarily unavailable. Please try again.';
        case 'not-found':
          return 'Data not found. It may have been deleted.';
        case 'deadline-exceeded':
          return 'Request timed out. Please check your connection and try again.';
        case 'resource-exhausted':
          return 'Too many requests. Please wait a moment and try again.';
        default:
          return 'A database error occurred. Please try again later.';
      }
    }
    if (error is SocketException || error is HttpException) {
      return 'Network error. Please check your internet connection.';
    }
    if (error.toString().contains('network')) {
      return 'No internet connection. Please check your network settings.';
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cyclesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles');

      final querySnap = await cyclesRef
          .where('farmId', isEqualTo: widget.activeFarmId)
          .get();

      double grossIncome = 0;
      double totalYield = 0;
      double totalLosses = 0;
      double totalPriceSum = 0;
      int priceCount = 0;
      final Map<String, double> monthlyIncome = {};
      final List<String> completedCycleIds = [];
      final List<_CropItemInfo> pendingAuditCrops = [];
      final List<_CropItemInfo> completedCrops = [];

      for (final doc in querySnap.docs) {
        final data = doc.data();
        final isCompleted = data['isCompleted'] == true ||
            data['status'] == 'completed' ||
            data['status'] == 'harvested';

        // Only process harvested / completed crops
        if (!isCompleted) continue;

        final isAuditCompleted = data['isAuditCompleted'] == true;
        final cropVariety = data['cropVariety'] ?? data['cropType'] ?? 'Unknown Crop';
        final fieldName = data['fieldName'] ?? 'Unknown Field';

        final totalValue = (data['grossIncome'] as num?)?.toDouble() ??
            (data['totalValue'] as num?)?.toDouble() ??
            (data['income'] as num?)?.toDouble() ??
            0;
        final yield_ = (data['totalYield'] as num?)?.toDouble() ??
            (data['goodYield'] as num?)?.toDouble() ??
            (data['actualYield'] as num?)?.toDouble() ??
            0;
        final damagedYield = (data['damagedYield'] as num?)?.toDouble() ?? 0;
        final marketPrice = (data['marketPrice'] as num?)?.toDouble() ?? 0;
        final pestLoss = (data['damageCost'] as num?)?.toDouble() ??
            (data['pestLoss'] as num?)?.toDouble() ??
            0;
        final otherLoss = (data['totalCycleCost'] as num?)?.toDouble() ??
            (data['otherLoss'] as num?)?.toDouble() ??
            0;
        final netIncome = (data['netIncome'] as num?)?.toDouble() ?? (totalValue - pestLoss - otherLoss);

        grossIncome += totalValue;
        totalYield += yield_;
        totalLosses += pestLoss + otherLoss + (damagedYield > 0 && marketPrice > 0 ? damagedYield * marketPrice : damagedYield);
        if (marketPrice > 0) {
          totalPriceSum += marketPrice;
          priceCount++;
        }

        completedCycleIds.add(doc.id);

        final harvestTs = data['expectedHarvestDate'] ??
            data['harvestDate'] ??
            data['actualHarvestDate'] ??
            data['completedAt'] ??
            data['auditCompletedAt'];
        if (harvestTs is Timestamp) {
          final monthKey = DateFormat('MMM').format(harvestTs.toDate());
          monthlyIncome[monthKey] = (monthlyIncome[monthKey] ?? 0) + totalValue;
        }

        final cropItem = _CropItemInfo(
          cycleId: doc.id,
          name: cropVariety,
          plot: fieldName,
          isAuditCompleted: isAuditCompleted,
          grossIncome: totalValue,
          netIncome: netIncome,
        );

        if (isAuditCompleted) {
          completedCrops.add(cropItem);
        } else {
          pendingAuditCrops.add(cropItem);
        }
      }

      setState(() {
        _grossIncome = grossIncome;
        _totalYield = totalYield;
        _totalLosses = totalLosses;
        _avgMarketPrice = priceCount > 0 ? totalPriceSum / priceCount : 0;
        _pendingAuditCrops = pendingAuditCrops;
        _completedCrops = completedCrops;
        _completedCycleIds = completedCycleIds;
        _rawMonthlyIncome = monthlyIncome;
        _isLoading = false;
      });

      _updateMonthlyRevenues();
    } catch (e) {
      debugPrint('Error loading income data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = _getUserFriendlyError(e);
      });
    }
  }

  void _updateMonthlyRevenues() {
    final now = DateTime.now();
    final months = <String>[];
    final monthValues = <double>[];
    final int monthCount = _showOneYear ? 12 : 6;

    for (int i = monthCount - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('MMM').format(month);
      months.add(key);
      months.length;
      monthValues.add(_rawMonthlyIncome[key] ?? 0);
    }

    final maxVal = monthValues.isEmpty
        ? 1.0
        : monthValues.reduce((a, b) => a > b ? a : b);

    setState(() {
      _monthlyRevenues = List.generate(monthCount, (i) {
        final normalized = maxVal > 0 ? monthValues[i] / maxVal : 0.0;
        return _MonthlyRevenue(month: months[i], level: normalized);
      });
    });
  }

  String _formatCurrency(double value) {
    if (value == 0) return '\u20B10';
    return '\u20B1${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Income Estimation',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'Income Estimate',
                        style: GoogleFonts.epilogue(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: darkGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Financial summary and projections based on current yield estimates and market conditions.',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: textGray,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _isExportingPdf ? null : _exportPdf,
                        icon: _isExportingPdf
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.file_download_outlined, size: 20),
                        label: Text(_isExportingPdf ? 'Generating...' : 'Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 240, 240, 240),
                          foregroundColor: Colors.black,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                      ),

                      const SizedBox(height: 30),

                      _buildGrossIncomeCard(),

                      const SizedBox(height: 30),

                      _buildLossesCard(),

                      const SizedBox(height: 30),

                      Text(
                        'Monthly Income Projection',
                        style: GoogleFonts.epilogue(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on harvest schedules and forward contracts',
                        style: GoogleFonts.manrope(color: textGray, fontSize: 14),
                      ),
                      const SizedBox(height: 15),

                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1E3E1).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildToggleItem("6 Months", !_showOneYear, () {
                              if (_showOneYear) {
                                setState(() => _showOneYear = false);
                                _updateMonthlyRevenues();
                              }
                            }),
                            _buildToggleItem("1 Year", _showOneYear, () {
                              if (!_showOneYear) {
                                setState(() => _showOneYear = true);
                                _updateMonthlyRevenues();
                              }
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      _buildRevenueChart(),

                      const SizedBox(height: 32),

                      // ─── 1. PENDING AUDIT SECTION ─────────────────────────
                      Row(
                        children: [
                          Text(
                            'Pending Audit',
                            style: GoogleFonts.epilogue(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          if (_pendingAuditCrops.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: Text(
                                '${_pendingAuditCrops.length} Pending',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Harvested crops awaiting financial verification. Complete the audit to finalize records.',
                        style: GoogleFonts.manrope(color: textGray, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      if (_pendingAuditCrops.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE8EAE6)),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF2E7D32), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'All harvested crops have been audited',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._pendingAuditCrops.map(
                          (crop) => _buildCropCard(crop),
                        ),

                      const SizedBox(height: 32),

                      // ─── 2. COMPLETED CROPS SECTION ───────────────────────
                      Row(
                        children: [
                          Text(
                            'Completed Crops',
                            style: GoogleFonts.epilogue(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          if (_completedCrops.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFA5D6A7)),
                              ),
                              child: Text(
                                '${_completedCrops.length} Audited',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1B5E37),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Crops with audited and finalized financial figures (locked & read-only).',
                        style: GoogleFonts.manrope(color: textGray, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      if (_completedCrops.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE8EAE6)),
                          ),
                          child: Center(
                            child: Text(
                              'No audited crops yet in this farm',
                              style: GoogleFonts.manrope(
                                fontSize: 13.5,
                                color: textGray,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._completedCrops.map(
                          (crop) => _buildCropCard(crop),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: deepRed.withValues(alpha: 0.7)),
            const SizedBox(height: 20),
            Text(
              'Oops! Something went wrong',
              style: GoogleFonts.epilogue(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: textGray,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrossIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('GROSS INCOME ESTIMATE',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textGray,
                      letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: accentGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.trending_up,
                    color: Color.fromARGB(255, 76, 122, 29), size: 25),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text(_formatCurrency(_grossIncome),
              style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: darkGreen)),
          if (_completedCycleIds.isNotEmpty)
            Text('Based on ${_completedCycleIds.length} completed cycle(s)',
                style: GoogleFonts.manrope(
                    fontSize: 14,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w700)),
          const Divider(height: 40, color: Color(0xFFF1F1F1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                  "Total Yield", "${_totalYield.toStringAsFixed(1)} Tons"),
              _buildMiniMetric("Avg Market Price",
                  _avgMarketPrice > 0 ? "\u20B1${_avgMarketPrice.toStringAsFixed(0)}/Ton" : "N/A"),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLossesCard() {
    return Container(
      padding: const EdgeInsets.all(27),
      decoration: BoxDecoration(
        color: softRed.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ESTIMATED LOSSES',
                  style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: deepRed,
                      letterSpacing: 0.7)),
              const Icon(Icons.bug_report_outlined,
                  color: deepRed, size: 20),
            ],
          ),
          Text('Primarily overall damage impact',
              style: GoogleFonts.manrope(
                  fontSize: 14, color: deepRed.withValues(alpha: 0.7))),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: deepRed.withValues(alpha: 0.1)),
            ),
            child: Text(_formatCurrency(-_totalLosses),
                style: GoogleFonts.manrope(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: deepRed)),
          )
        ],
      ),
    );
  }

  Widget _buildCropCard(_CropItemInfo crop) {
    final isPending = !crop.isAuditCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.35) : const Color(0xFFE8EAE6),
          width: isPending ? 1.2 : 1.0,
        ),
        boxShadow: isPending
            ? [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.name,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: textGray,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          crop.plot,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: textGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isPending ? const Color(0xFFFEF3C7) : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPending ? const Color(0xFFF59E0B) : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPending ? Icons.edit_note_rounded : Icons.verified_rounded,
                      size: 14,
                      color: isPending ? const Color(0xFFB45309) : const Color(0xFF1B5E37),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPending ? 'Pending Audit' : 'Completed & Audited',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isPending ? const Color(0xFFB45309) : const Color(0xFF1B5E37),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CropFinanceScreen(
                    userId: widget.userId,
                    activeFarmId: widget.activeFarmId,
                    cycleId: crop.cycleId,
                  ),
                ),
              );
              if (result == true || mounted) {
                _loadData();
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: isPending ? const Color(0xFF0D4D33) : const Color(0xFFF3F5EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPending ? Icons.edit_document : Icons.arrow_forward_rounded,
                    size: 16,
                    color: isPending ? Colors.white : darkGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPending ? 'Complete Financial Audit' : 'View Financial Report',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: isPending ? Colors.white : darkGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final hasData = _monthlyRevenues.any((r) => r.level > 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_showOneYear ? 'Last 12 Months Revenue Flow' : 'Last 6 Months Revenue Flow',
                  style:
                      GoogleFonts.manrope(fontSize: 12, color: textGray)),
              Row(
                children: [
                  Text('Export',
                      style: GoogleFonts.manrope(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const Icon(Icons.download, size: 15),
                ],
              )
            ],
          ),
          const SizedBox(height: 25),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'No completed cycles yet',
                style: GoogleFonts.manrope(
                    fontSize: 14, color: textGray.withValues(alpha: 0.6)),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyRevenues
                  .map((r) => _buildBar(r.month, r.level))
                  .toList(),
            )
        ],
      ),
    );
  }

  Widget _buildBar(String month, double level) {
    final height = level > 0 ? 100.0 * level : 4.0;
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 100,
              width: _showOneYear ? 18 : 25,
              decoration: BoxDecoration(
                  color: const Color(0xFFE1E3E1),
                  borderRadius: BorderRadius.circular(_showOneYear ? 9 : 12.5)),
            ),
            Container(
              height: height,
              width: _showOneYear ? 18 : 25,
              decoration: BoxDecoration(
                  color: darkGreen,
                  borderRadius: BorderRadius.circular(_showOneYear ? 9 : 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(month,
            style: GoogleFonts.manrope(
                fontSize: _showOneYear ? 8 : 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                GoogleFonts.manrope(fontSize: 13, color: textGray)),
        Text(value,
            style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black)),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
              : null,
        ),
        child: Text(label,
            style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.black : textGray)),
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr = DateFormat('MMMM dd, yyyy').format(now);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            pw.Header(
              level: 0,
              child: pw.Text('Income Estimation Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Generated on: $dateStr',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 24),

            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('GROSS INCOME ESTIMATE',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  pw.Text(_formatCurrency(_grossIncome),
                      style: pw.TextStyle(
                          fontSize: 32, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Based on ${_completedCycleIds.length} completed cycle(s)',
                      style: const pw.TextStyle(
                          fontSize: 12, color: PdfColors.green800)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ESTIMATED LOSSES',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red800)),
                  pw.SizedBox(height: 8),
                  pw.Text(_formatCurrency(-_totalLosses),
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.all(8),
              headers: ['Metric', 'Value'],
              data: [
                ['Total Yield', '${_totalYield.toStringAsFixed(1)} Tons'],
                [
                  'Avg Market Price',
                  _avgMarketPrice > 0
                      ? '\u20B1${_avgMarketPrice.toStringAsFixed(0)}/Ton'
                      : 'N/A'
                ],
                [
                  'Net Income',
                  _formatCurrency(_grossIncome - _totalLosses)
                ],
                ['Completed Cycles', '${_completedCycleIds.length}'],
                ['Completed Crops', '${_completedCrops.length}'],
              ],
            ),
            pw.SizedBox(height: 24),

            if (_completedCrops.isNotEmpty) ...[
              pw.Text('Completed Crops',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
                cellPadding: const pw.EdgeInsets.all(8),
                headers: ['Crop', 'Field', 'Status'],
                data: _completedCrops
                    .map((c) => [c.name, c.plot, 'Completed'])
                    .toList(),
              ),
            ],

            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
                'This report was generated automatically. Values are estimates based on completed cycles.',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey500)),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/income_estimation_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Income Estimation Report - $dateStr',
        ),
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getUserFriendlyError(e)),
            backgroundColor: deepRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }
}

class _CropItemInfo {
  final String cycleId;
  final String name;
  final String plot;
  final bool isAuditCompleted;
  final double grossIncome;
  final double netIncome;

  _CropItemInfo({
    required this.cycleId,
    required this.name,
    required this.plot,
    required this.isAuditCompleted,
    this.grossIncome = 0.0,
    this.netIncome = 0.0,
  });
}

class _MonthlyRevenue {
  final String month;
  final double level;

  _MonthlyRevenue({required this.month, required this.level});
}
