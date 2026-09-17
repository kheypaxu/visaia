import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/screens/dashboard_screens/dashboard.dart';
import 'package:visaia/services/farm_report_pdf_service.dart';


class FarmDetailScreen extends StatefulWidget {
  final String userId;
  final String farmId;
  final Map<String, dynamic> farmData;

  const FarmDetailScreen({
    super.key,
    required this.userId,
    required this.farmId,
    required this.farmData,
  });

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  static const Color _darkGreen = Color(0xFF1E5E3A);
  static const Color _forestGreen = Color(0xFF135B3B);
  static const Color _cardBg = Color(0xFFF1F4F0);
  static const Color _textBlack = Color(0xFF191C19);
  static const Color _textMuted = Color(0xFF5A6054);
  static const Color _badgeGreen = Color(0xFFB5EDB1);

  bool _isExporting = false;

  String _formatK(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      final val = (amount / 1000);
      return val == val.roundToDouble()
          ? '${val.toStringAsFixed(0)}k'
          : '${val.toStringAsFixed(1)}k';
    }
    return NumberFormat('#,##0').format(amount);
  }

  String _formatYield(double amount) {
    if (amount >= 1000) {
      return NumberFormat('#,##0').format(amount);
    }
    return amount.toStringAsFixed(0);
  }

  void _showExportOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Export Farm Data',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _textBlack,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose format to download or share',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: _textMuted,
                ),
              ),
              const SizedBox(height: 20),
              // PDF Option
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: _cardBg,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _forestGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: _forestGreen),
                ),
                title: Text(
                  'Official Farm Report (PDF)',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  'Formatted executive farm report with cycle & FAW status',
                  style: GoogleFonts.manrope(fontSize: 12, color: _textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: _forestGreen),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportPdf();
                },
              ),
              const SizedBox(height: 12),
              // CSV Option
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: _cardBg,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _forestGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: _forestGreen),
                ),
                title: Text(
                  'Compliance Data (CSV)',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                subtitle: Text(
                  'Spreadsheet data format for regulatory reporting',
                  style: GoogleFonts.manrope(fontSize: 12, color: _textMuted),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: _forestGreen),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportCsv();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _isExporting = true);
    try {
      await FarmReportPdfService.exportAndShareFarmReport(
        userId: widget.userId,
        farmId: widget.farmId,
        farmData: widget.farmData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      await FarmReportPdfService.exportAndShareCsv(
        userId: widget.userId,
        farmId: widget.farmId,
        farmData: widget.farmData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export CSV: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farmName = widget.farmData['name'] as String? ?? 'Farm';
    final location = widget.farmData['address'] as String? ??
        widget.farmData['location'] as String? ??
        'Location not set';

    final service = MonitoringFirestoreService(
      userId: widget.userId,
      farmId: widget.farmId,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: _forestGreen,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Farm Header Info ──
                Text(
                  farmName,
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _textBlack,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: _forestGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        location,
                        style: GoogleFonts.manrope(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: _textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Active Cycle Card ──
                StreamBuilder<List<CycleModel>>(
                  stream: service.getActiveCycles(),
                  builder: (context, cycleSnap) {
                    final cycles = cycleSnap.data ?? [];

                    if (cycles.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _cardBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'ACTIVE CYCLE',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: _textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'No Active Cycle',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: _textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'No cycle currently running',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textBlack,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Start a new crop cycle to track progress and harvest stages.',
                              style: GoogleFonts.manrope(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final activeCycle = cycles.first;
                    String stageText = activeCycle.statusText ?? 'Active';
                    String weekText = 'Ongoing';
                    String cropText = activeCycle.cropVariety.isNotEmpty
                        ? activeCycle.cropVariety
                        : activeCycle.cycleName;
                    double progress = 0.1;

                    if (activeCycle.plantingDate != null) {
                      final days = DateTime.now()
                          .difference(activeCycle.plantingDate!)
                          .inDays;
                      final w = (days / 7).floor() + 1;
                      weekText = 'Week $w';
                      progress = (w / 12).clamp(0.05, 1.0);
                    }

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ACTIVE CYCLE',
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _badgeGreen,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: _forestGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      stageText,
                                      style: GoogleFonts.manrope(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _forestGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            weekText,
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _textBlack,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cropText,
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _textMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFDDE3DA),
                              color: _forestGreen,
                              minHeight: 5.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _textMuted,
                                ),
                              ),
                              Text(
                                '${(progress * 100).round()}%',
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _forestGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ── 2-Column Row: FIELDS & NET INCOME ──
                FutureBuilder<List<FieldModel>>(
                  future: service.getFields(),
                  builder: (context, fieldSnap) {
                    final fieldsCount = fieldSnap.data?.length ?? 0;

                    return StreamBuilder<double>(
                      stream: service.getNetIncome(),
                      builder: (context, incomeSnap) {
                        final netIncome = incomeSnap.data ?? 0.0;

                        return StreamBuilder<List<CycleModel>>(
                          stream: service.getActiveCycles(),
                          builder: (context, activeCycleSnap) {
                            final activeCyclesCount = activeCycleSnap.data?.length ?? 0;

                            return Row(
                              children: [
                                // Left Card: FIELDS
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: _cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.agriculture_rounded,
                                              size: 16,
                                              color: _textMuted,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'FIELDS',
                                              style: GoogleFonts.manrope(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: _textMuted,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '$fieldsCount',
                                          style: GoogleFonts.manrope(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w800,
                                            color: _textBlack,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$activeCyclesCount under active cycle',
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: _textMuted,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Right Card: NET INCOME
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: _cardBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.payments_outlined,
                                              size: 16,
                                              color: _textMuted,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'NET INCOME',
                                              style: GoogleFonts.manrope(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: _textMuted,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '₱${_formatK(netIncome)}',
                                          style: GoogleFonts.manrope(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w800,
                                            color: _textBlack,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          netIncome > 0
                                              ? 'From completed cycles'
                                              : 'No completed cycles yet',
                                          style: GoogleFonts.manrope(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ── Total Yield Banner Card (Dark Green) ──
                StreamBuilder<double>(
                  stream: service.getTotalYield(),
                  builder: (context, yieldSnap) {
                    final yieldVal = yieldSnap.data ?? 0.0;

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _darkGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.hourglass_bottom_rounded,
                                    size: 18,
                                    color: _badgeGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'TOTAL YIELD',
                                    style: GoogleFonts.manrope(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _badgeGreen,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _formatYield(yieldVal),
                                style: GoogleFonts.manrope(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'tons',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            yieldVal > 0 ? 'Total harvested yield' : 'No harvest records yet',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _badgeGreen,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // ── Operations Section ──
                Text(
                  'Operations',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textBlack,
                  ),
                ),
                const SizedBox(height: 12),

                // Export Farm Data Button Tile
                Material(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _showExportOptionsSheet(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.download_rounded,
                              color: _forestGreen,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Export Farm Data',
                                  style: GoogleFonts.manrope(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: _textBlack,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Download CSV for compliance',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: _textBlack,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isExporting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: _forestGreen),
              ),
            ),
        ],
      ),
    );
  }
}
