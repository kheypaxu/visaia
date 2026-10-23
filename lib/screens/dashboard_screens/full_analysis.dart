import 'dart:async';
import 'package:visaia/core/models/cycle_audit_policy.dart';
import 'package:visaia/services/pdf_theme_service.dart';
import 'package:visaia/core/models/cycle_metrics.dart';
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

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _cyclesSubscription;
  int _cyclesLoadVersion = 0;

  bool _isLoading = true;
  bool _isExportingPdf = false;
  String? _errorMessage;
  double _grossIncome = 0;
  double _totalYield = 0;
  double _totalLosses = 0;
  double _avgMarketPrice = 0;
  double _netIncome = 0;
  Map<String, double> _financialBreakdown = {};
  List<_OngoingCycleInfo> _ongoingCycles = [];
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
  void reassemble() {
    super.reassemble();
    // Hot reload preserves the lists computed under the previous audit policy.
    // Re-subscribe so unchanged Firestore documents are classified again too.
    _loadData();
  }

  @override
  void didUpdateWidget(covariant IncomeEstimationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.activeFarmId != widget.activeFarmId) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _cyclesLoadVersion++;
    _cyclesSubscription?.cancel();
    super.dispose();
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
    final loadVersion = ++_cyclesLoadVersion;
    await _cyclesSubscription?.cancel();
    if (!mounted || loadVersion != _cyclesLoadVersion) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cyclesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles');

      _cyclesSubscription = cyclesRef
          .where('farmId', isEqualTo: widget.activeFarmId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted || loadVersion != _cyclesLoadVersion) return;
              try {
                _applyCycleSnapshot(snapshot);
              } catch (error) {
                _handleCycleLoadError(error);
              }
            },
            onError: (Object error) {
              if (mounted && loadVersion == _cyclesLoadVersion) {
                _handleCycleLoadError(error);
              }
            },
          );
    } catch (error) {
      if (mounted && loadVersion == _cyclesLoadVersion) {
        _handleCycleLoadError(error);
      }
    }
  }

  // Keep harvest and audit transitions current while this screen is mounted.
  void _applyCycleSnapshot(QuerySnapshot<Map<String, dynamic>> querySnap) {
    double grossIncome = 0;
    double totalYield = 0;
    double totalLosses = 0;
    double pricedYield = 0;
    double pricedValue = 0;
    double netTotal = 0;
    final breakdown = <String, double>{};
    void addAmount(String label, double amount) {
      breakdown[label] = (breakdown[label] ?? 0) + amount;
    }

    final Map<String, double> monthlyIncome = {};
    final List<String> completedCycleIds = [];
    final ongoingCycles = <_OngoingCycleInfo>[];
    final List<_CropItemInfo> pendingAuditCrops = [];
    final List<_CropItemInfo> completedCrops = [];

    for (final doc in querySnap.docs) {
      final data = doc.data();
      if (!hasRecordedHarvest(data)) {
        ongoingCycles.add(
          _OngoingCycleInfo(
            name:
                (data['cycleName'] ??
                        data['cropVariety'] ??
                        data['cropType'] ??
                        'Unnamed cycle')
                    .toString(),
            field: (data['fieldName'] ?? 'Unknown Field').toString(),
            plantingDate: data['plantingDate'] is Timestamp
                ? (data['plantingDate'] as Timestamp).toDate()
                : null,
            harvestDate:
                (data['expectedHarvestDate'] ?? data['harvestDate'])
                    is Timestamp
                ? ((data['expectedHarvestDate'] ?? data['harvestDate'])
                          as Timestamp)
                      .toDate()
                : null,
          ),
        );
        continue;
      }

      final isAuditCompleted = hasCompletedHarvestAudit(data);
      final cropVariety =
          data['cropVariety'] ?? data['cropType'] ?? 'Unknown Crop';
      final fieldName = data['fieldName'] ?? 'Unknown Field';

      final finance = CycleFinance(data);
      final totalValue = finance.gross;
      final yieldKg = recordedYield(data) ?? 0;
      final marketPrice = cycleNumber(data['marketPrice']) ?? 0;
      final netIncome = finance.net;

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
        continue;
      }

      grossIncome += totalValue;
      totalYield += yieldKg;
      totalLosses += finance.damage + finance.costs;
      netTotal += netIncome;
      addAmount('Damage costs', -finance.damage);
      addAmount('Control methods', -finance.control);
      addAmount('Fertilizer', -finance.fertilizer);
      addAmount('Seeds', -finance.seeds);
      addAmount('Other expenses', -finance.other);
      addAmount('Saved cycle cost adjustment', -finance.costAdjustment);
      addAmount('Saved net income adjustment', finance.netAdjustment);
      if (marketPrice > 0 && yieldKg > 0) {
        pricedValue += marketPrice * yieldKg;
        pricedYield += yieldKg;
      }

      completedCycleIds.add(doc.id);

      final harvestTs =
          data['harvestCompletedAt'] ??
          data['actualHarvestDate'] ??
          data['harvestDate'] ??
          data['completedAt'] ??
          data['auditCompletedAt'];
      if (harvestTs is Timestamp) {
        final monthKey = DateFormat('yyyy-MM').format(harvestTs.toDate());
        monthlyIncome[monthKey] = (monthlyIncome[monthKey] ?? 0) + totalValue;
      }
    }

    if (!mounted) return;
    setState(() {
      _grossIncome = grossIncome;
      _totalYield = totalYield;
      _totalLosses = totalLosses;
      _avgMarketPrice = pricedYield > 0 ? pricedValue / pricedYield : 0;
      _netIncome = netTotal;
      _financialBreakdown = breakdown;
      _ongoingCycles = ongoingCycles;
      _pendingAuditCrops = pendingAuditCrops;
      _completedCrops = completedCrops;
      _completedCycleIds = completedCycleIds;
      _rawMonthlyIncome = monthlyIncome;
      _isLoading = false;
      _errorMessage = null;
    });

    _updateMonthlyRevenues();
  }

  void _handleCycleLoadError(Object error) {
    debugPrint('Error loading income data: $error');
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = _getUserFriendlyError(error);
    });
  }

  void _updateMonthlyRevenues() {
    final now = DateTime.now();
    final months = <String>[];
    final monthValues = <double>[];
    final int monthCount = _showOneYear ? 12 : 6;

    for (int i = monthCount - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('yyyy-MM').format(month);
      months.add(DateFormat('MMM').format(month));
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
    return NumberFormat.currency(
      symbol: '\u20B1',
      decimalDigits: 2,
    ).format(value);
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
        actions: [
          IconButton(
            tooltip: 'Refresh cycle and audit status',
            icon: const Icon(Icons.refresh_rounded, color: darkGreen),
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorView()
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Financial summary for the selected farm',
                            style: TextStyle(color: textGray),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isExportingPdf ? null : _exportPdf,
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(
                            _isExportingPdf ? 'Generating...' : 'Export PDF',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: darkGreen,
                    indicatorColor: accentGreen,
                    tabs: [
                      Tab(text: 'Gross Income'),
                      Tab(text: 'Cost Deduction'),
                      Tab(text: 'Audit'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _tabBody('gross', [
                          _buildGrossIncomeCard(),
                          const SizedBox(height: 24),
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
                            'Based on recorded income from completed financial audits',
                            style: GoogleFonts.manrope(
                              color: textGray,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 15),

                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFE1E3E1,
                              ).withValues(alpha: 0.5),
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
                          if (_completedCrops.isEmpty) ...[
                            _buildAuditNotice(),
                            const SizedBox(height: 16),
                          ],
                          _buildRevenueChart(),

                          const SizedBox(height: 32),
                        ]),
                        _tabBody('cost', [
                          _buildLossesCard(),
                          const SizedBox(height: 20),
                          _buildNetIncomeCard(),
                        ]),
                        _tabBody('audit', [
                          _buildAuditNotice(),
                          const SizedBox(height: 16),
                          _buildOngoingCycles(),
                          const SizedBox(height: 24),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B),
                                    ),
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
                            style: GoogleFonts.manrope(
                              color: textGray,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_pendingAuditCrops.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 22,
                                horizontal: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE8EAE6),
                                ),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Color(0xFF2E7D32),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _completedCrops.isEmpty
                                            ? 'No harvested cycles awaiting audit'
                                            : 'All harvested crops have been audited',
                                        style: GoogleFonts.manrope(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textGray,
                                        ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFA5D6A7),
                                    ),
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
                            style: GoogleFonts.manrope(
                              color: textGray,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (_completedCrops.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE8EAE6),
                                ),
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
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAuditNotice() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F5EE),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDDE5D6)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: darkGreen, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Harvest first, then complete the audit',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Record the harvest for a cycle to unlock its financial audit. After you complete the audit, its verified figures will appear in the income summary and monthly income projection. Ongoing cycles and pending audits are excluded from these calculations.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: textGray,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildOngoingCycles() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE8EAE6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey('ongoing-cycles-${widget.activeFarmId}'),
      leading: const Icon(Icons.grass_rounded, color: darkGreen),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        'Ongoing / Not Harvested (${_ongoingCycles.length})',
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: darkGreen,
        ),
      ),
      subtitle: Text(
        'View cycles awaiting a recorded harvest',
        style: GoogleFonts.manrope(fontSize: 12, color: textGray),
      ),
      children: [
        if (_ongoingCycles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No ongoing cycles in this farm.'),
          ),
        for (final cycle in _ongoingCycles)
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            title: Text(
              cycle.name,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              [
                cycle.field,
                if (cycle.plantingDate != null)
                  'Planted ${DateFormat('MMM d, yyyy').format(cycle.plantingDate!)}',
                if (cycle.harvestDate != null)
                  'Expected harvest ${DateFormat('MMM d, yyyy').format(cycle.harvestDate!)}',
                'Not harvested - audit locked',
              ].join('\n'),
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: textGray,
                height: 1.5,
              ),
            ),
            isThreeLine: true,
          ),
      ],
    ),
  );

  Widget _tabBody(String name, List<Widget> children) => SingleChildScrollView(
    key: PageStorageKey('${widget.activeFarmId}-$name'),
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: deepRed.withValues(alpha: 0.7),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
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
              Text(
                'GROSS INCOME ESTIMATE',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textGray,
                  letterSpacing: 1,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Color.fromARGB(255, 76, 122, 29),
                  size: 25,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _formatCurrency(_grossIncome),
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: darkGreen,
            ),
          ),
          if (_completedCycleIds.isNotEmpty)
            Text(
              'Based on ${_completedCycleIds.length} completed audit(s)',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: Colors.green[700],
                fontWeight: FontWeight.w700,
              ),
            ),
          const Divider(height: 40, color: Color(0xFFF1F1F1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                "Total Yield",
                "${_totalYield.toStringAsFixed(1)} kg",
              ),
              _buildMiniMetric(
                "Weighted price",
                _avgMarketPrice > 0
                    ? "\u20B1${_avgMarketPrice.toStringAsFixed(2)}/kg"
                    : "N/A",
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Gross income is the sum of financial-report harvest income. '
            'Yield is recorded in kg; the price is weighted by harvest weight '
            'for cycles with a recorded price. Their product is not the income formula. '
            'Only completed financial audits are included.',
            style: GoogleFonts.manrope(fontSize: 12, color: textGray),
          ),
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
              Text(
                'COSTS & DEDUCTIONS',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: deepRed,
                  letterSpacing: 0.7,
                ),
              ),
              const Icon(Icons.bug_report_outlined, color: deepRed, size: 20),
            ],
          ),
          Text(
            'Damage costs + cycle expenses',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: deepRed.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: deepRed.withValues(alpha: 0.1)),
            ),
            child: Text(
              _formatCurrency(-_totalLosses),
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: deepRed,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFinancialRow('Gross harvest income', _grossIncome),
          for (final entry in _financialBreakdown.entries)
            if (!entry.key.contains('adjustment') || entry.value.abs() >= 0.005)
              _buildFinancialRow(entry.key, entry.value),
        ],
      ),
    );
  }

  Widget _buildNetIncomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: darkGreen,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET INCOME',
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(_netIncome),
              style: GoogleFonts.manrope(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Net income = gross income - damage costs - cycle expenses '
            '+ saved net adjustment (if any). Damaged harvest value is not deducted again. '
            'Saved adjustments reconcile stored totals with itemized amounts.',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: GoogleFonts.manrope(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
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
          color: isPending
              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
              : const Color(0xFFE8EAE6),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPending
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPending
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFA5D6A7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPending
                          ? Icons.edit_note_rounded
                          : Icons.verified_rounded,
                      size: 14,
                      color: isPending
                          ? const Color(0xFFB45309)
                          : const Color(0xFF1B5E37),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isPending ? 'Pending Audit' : 'Completed & Audited',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isPending
                            ? const Color(0xFFB45309)
                            : const Color(0xFF1B5E37),
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
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CropFinanceScreen(
                    userId: widget.userId,
                    activeFarmId: widget.activeFarmId,
                    cycleId: crop.cycleId,
                  ),
                ),
              );
              if (mounted) {
                _loadData();
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              height: 46,
              decoration: BoxDecoration(
                color: isPending
                    ? const Color(0xFF0D4D33)
                    : const Color(0xFFF3F5EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPending
                        ? Icons.edit_document
                        : Icons.arrow_forward_rounded,
                    size: 16,
                    color: isPending ? Colors.white : darkGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPending
                        ? 'Complete Financial Audit'
                        : 'View Financial Report',
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showOneYear
                    ? 'Last 12 Months Revenue Flow'
                    : 'Last 6 Months Revenue Flow',
                style: GoogleFonts.manrope(fontSize: 12, color: textGray),
              ),
            ],
          ),
          const SizedBox(height: 25),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'No completed audits yet',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: textGray.withValues(alpha: 0.6),
                ),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _monthlyRevenues
                  .map((r) => _buildBar(r.month, r.level))
                  .toList(),
            ),
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
                borderRadius: BorderRadius.circular(_showOneYear ? 9 : 12.5),
              ),
            ),
            Container(
              height: height,
              width: _showOneYear ? 18 : 25,
              decoration: BoxDecoration(
                color: darkGreen,
                borderRadius: BorderRadius.circular(_showOneYear ? 9 : 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: GoogleFonts.manrope(
            fontSize: _showOneYear ? 8 : 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(fontSize: 13, color: textGray)),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
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
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.black : textGray,
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);

    try {
      final pdf = pw.Document(theme: await PdfThemeService.load());
      final exportLogo = await PdfThemeService.loadLogo();
      final now = DateTime.now();
      final dateStr = DateFormat('MMMM dd, yyyy').format(now);
      final projectionMonths = List.generate(_showOneYear ? 12 : 6, (i) {
        final count = _showOneYear ? 12 : 6;
        return DateTime(now.year, now.month - count + 1 + i, 1);
      });

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) => [
            PdfThemeService.brandHeader(exportLogo),
            pw.Header(
              level: 0,
              child: pw.Text(
                'Income Estimation Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated on: $dateStr',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
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
                  pw.Text(
                    'GROSS INCOME ESTIMATE',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _formatCurrency(_grossIncome),
                    style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Based on ${_completedCycleIds.length} completed audit(s)',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.green800,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Monthly Income Projection - Last ${projectionMonths.length} Months',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Recorded harvest income for the selected period; future income is not forecast.',
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              height: 130,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  for (final revenue in _monthlyRevenues)
                    pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Container(
                          width: 18,
                          height: revenue.level > 0 ? revenue.level * 100 : 2,
                          color: PdfColors.green900,
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          revenue.month,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Month', 'Harvest income'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green50,
              ),
              cellPadding: const pw.EdgeInsets.all(8),
              data: [
                for (final month in projectionMonths)
                  [
                    DateFormat('MMM yyyy').format(month),
                    _formatCurrency(
                      _rawMonthlyIncome[DateFormat('yyyy-MM').format(month)] ??
                          0,
                    ),
                  ],
              ],
            ),
            pw.SizedBox(height: 24),

            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.red50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'COSTS & DEDUCTIONS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red800,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    _formatCurrency(-_totalLosses),
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red900,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellPadding: const pw.EdgeInsets.all(8),
              headers: ['Metric', 'Value'],
              data: [
                ['Gross harvest income', _formatCurrency(_grossIncome)],
                for (final entry in _financialBreakdown.entries)
                  if (!entry.key.contains('adjustment') ||
                      entry.value.abs() >= 0.005)
                    [entry.key, _formatCurrency(entry.value)],
                ['Total Yield', '${_totalYield.toStringAsFixed(1)} kg'],
                [
                  'Weighted price',
                  _avgMarketPrice > 0
                      ? '\u20B1${_avgMarketPrice.toStringAsFixed(2)}/kg'
                      : 'N/A',
                ],
                ['Completed Audits', '${_completedCycleIds.length}'],
                ['Completed Crops', '${_completedCrops.length}'],
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: PdfColors.green900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NET INCOME',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      _formatCurrency(_netIncome),
                      style: pw.TextStyle(
                        fontSize: 36,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Net = gross harvest income - damage costs - cycle expenses + saved net adjustment. Only completed financial audits are included. Yield is in kg; weighted price is informational, not the income formula.',
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Audit',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Pending Audit (${_pendingAuditCrops.length})',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (_pendingAuditCrops.isEmpty)
              pw.Text('No crops awaiting audit.')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Crop', 'Field', 'Gross income', 'Net income'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellPadding: const pw.EdgeInsets.all(8),
                data: [
                  for (final crop in _pendingAuditCrops)
                    [
                      crop.name,
                      crop.plot,
                      _formatCurrency(crop.grossIncome),
                      _formatCurrency(crop.netIncome),
                    ],
                ],
              ),
            pw.SizedBox(height: 16),
            if (_completedCrops.isNotEmpty) ...[
              pw.Text(
                'Completed Audit (${_completedCrops.length})',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellPadding: const pw.EdgeInsets.all(8),
                headers: ['Crop', 'Field', 'Gross income', 'Net income'],
                data: _completedCrops
                    .map(
                      (c) => [
                        c.name,
                        c.plot,
                        _formatCurrency(c.grossIncome),
                        _formatCurrency(c.netIncome),
                      ],
                    )
                    .toList(),
              ),
            ] else
              pw.Text('No completed audits yet.'),

            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'This report was generated automatically. Values are based on completed financial audits.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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

class _OngoingCycleInfo {
  final String name;
  final String field;
  final DateTime? plantingDate;
  final DateTime? harvestDate;

  const _OngoingCycleInfo({
    required this.name,
    required this.field,
    this.plantingDate,
    this.harvestDate,
  });
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
