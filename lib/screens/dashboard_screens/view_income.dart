import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class CropFinanceScreen extends StatefulWidget {
  final String userId;
  final String activeFarmId;
  final String cycleId;

  const CropFinanceScreen({
    super.key,
    required this.userId,
    required this.activeFarmId,
    required this.cycleId,
  });

  @override
  State<CropFinanceScreen> createState() => _CropFinanceScreenState();
}

class _CropFinanceScreenState extends State<CropFinanceScreen> {
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color bgSoftGreen = Color(0xFFF3F5EE);
  static const Color errorRed = Color(0xFFBA1A1A);

  bool _isLoading = true;
  bool _isExportingPdf = false;
  String? _errorMessage;
  String _cropName = '';

  // Controllers for income inputs
  final TextEditingController _harvestIncomeController = TextEditingController();
  final TextEditingController _damageCostController = TextEditingController();
  
  // Controllers for cycle costs
  final TextEditingController _controlMethodController = TextEditingController();
  final TextEditingController _fertilizerController = TextEditingController();
  final TextEditingController _seedsController = TextEditingController();
  final TextEditingController _otherExpensesController = TextEditingController();

  double _grossIncome = 0;
  double _totalCycleCost = 0;
  double _damageCost = 0;
  double _netIncome = 0;
  double _profitPercentage = 0;
  int _cycleCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCycleData();
  }

  @override
  void dispose() {
    _harvestIncomeController.dispose();
    _damageCostController.dispose();
    _controlMethodController.dispose();
    _fertilizerController.dispose();
    _seedsController.dispose();
    _otherExpensesController.dispose();
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
        default:
          return 'A database error occurred. Please try again later.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _loadCycleData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .get();

      if (!cycleDoc.exists) {
        throw StateError('Completed cycle not found');
      }
      final data = cycleDoc.data()!;
      if (data['isCompleted'] != true) {
        throw StateError('Income analysis is only available for completed cycles');
      }
      _cropName = data['cropVariety'] ?? data['cropType'] ?? 'Unknown Crop';
      final totalGross = (data['grossIncome'] as num?)?.toDouble() ??
          (data['totalValue'] as num?)?.toDouble() ??
          (data['income'] as num?)?.toDouble() ??
          0;
      final totalPestLoss = (data['pestLoss'] as num?)?.toDouble() ?? 0;
      final totalOtherLoss = (data['otherLoss'] as num?)?.toDouble() ?? 0;
      final storedNet = (data['netIncome'] as num?)?.toDouble();

      setState(() {
        _grossIncome = totalGross;
        _damageCost = totalPestLoss;
        _totalCycleCost = totalOtherLoss;
        _netIncome = storedNet ?? totalGross - totalPestLoss - totalOtherLoss;
        _profitPercentage = totalGross > 0 ? ((_netIncome / totalGross) * 100) : 0;
        _cycleCount = 1;

        _harvestIncomeController.text = totalGross > 0 ? totalGross.toStringAsFixed(2) : '0.00';
        _damageCostController.text = totalPestLoss > 0 ? totalPestLoss.toStringAsFixed(2) : '0.00';
        _controlMethodController.text = '0.00';
        _fertilizerController.text = '0.00';
        _seedsController.text = '0.00';
        _otherExpensesController.text = totalOtherLoss > 0 ? totalOtherLoss.toStringAsFixed(2) : '0.00';

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cycle data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = _getUserFriendlyError(e);
      });
    }
  }

  String _formatCurrency(double value) {
    final formatted = value.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₱$intPart.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Crop Finance',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _isExportingPdf ? null : _exportPdf,
            icon: _isExportingPdf
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined, color: darkGreen),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: darkGreen))
          : _errorMessage != null
              ? _buildErrorView()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        'FINANCIAL ANALYTICS',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF4C7A1D),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_cropName Income Calculation',
                        style: GoogleFonts.epilogue(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: darkGreen,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Read-only financial analysis from this completed cycle.',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          color: textGray,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // TOTAL HARVEST INCOME
                      _buildSectionCard(
                        title: 'TOTAL HARVEST INCOME',
                        subtitle: 'Add seeds from planting to harvest',
                        children: [
                          _buildInputFieldWithIcon(
                            'Harvest Income (₱)',
                            _harvestIncomeController,
                            Icons.agriculture_outlined,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // TOTAL CYCLE COST
                      _buildSectionCard(
                        title: 'TOTAL CYCLE COST',
                        subtitle: 'Enter total amount spent from planting to harvest',
                        children: [
                          _buildInputFieldWithIcon(
                            'Total Control Method Cost (₱)',
                            _controlMethodController,
                            Icons.pest_control_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildInputFieldWithIcon(
                            'Total Fertilizer Cost (₱)',
                            _fertilizerController,
                            Icons.grass_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildInputFieldWithIcon(
                            'Total Seeds Cost (₱)',
                            _seedsController,
                            Icons.eco_outlined,
                          ),
                          const SizedBox(height: 12),
                          _buildInputFieldWithIcon(
                            'Other Expenses (₱)',
                            _otherExpensesController,
                            Icons.receipt_long_outlined,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // TOTAL DAMAGE COST
                      _buildSectionCard(
                        title: 'TOTAL DAMAGE COST',
                        subtitle: 'Estimated value of crops lost or damaged',
                        children: [
                          _buildInputFieldWithIcon(
                            'Damage Cost (₱)',
                            _damageCostController,
                            Icons.warning_amber_outlined,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      const SizedBox(height: 10),

                      // ESTIMATED NET INCOME RESULT
                      _buildResultCard(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: darkGreen,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: textGray.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInputFieldWithIcon(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textGray,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: bgSoftGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8EAE6)),
          ),
          child: TextField(
            controller: controller,
            readOnly: true,
            enableInteractiveSelection: false,
            keyboardType: TextInputType.number,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: darkGreen, size: 20),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: errorRed.withValues(alpha: 0.7)),
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
              style: GoogleFonts.manrope(fontSize: 14, color: textGray, height: 1.5),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _loadCycleData,
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

  Widget _buildResultCard() {
    final isPositive = _netIncome >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8EAE6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTIMATED NET INCOME',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textGray.withValues(alpha: 0.6),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _formatCurrency(_netIncome),
                style: GoogleFonts.manrope(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: darkGreen,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : errorRed,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF1F1F1)),
          const SizedBox(height: 16),
          _buildResultRow('Harvest Income', '+${_formatCurrency(_grossIncome)}', darkGreen),
          const SizedBox(height: 12),
          _buildResultRow('Total Damage Cost', '-${_formatCurrency(_damageCost)}', errorRed),
          if (_totalCycleCost > 0) ...[
            const SizedBox(height: 12),
            _buildResultRow('Total Cycle Cost', '-${_formatCurrency(_totalCycleCost)}', errorRed),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgSoftGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profit/Loss',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPositive ? const Color(0xFFD9E7CB) : const Color(0xFFFFDADA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPositive
                        ? '+${_profitPercentage.toStringAsFixed(1)}%'
                        : '${_profitPercentage.toStringAsFixed(1)}%',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isPositive ? Colors.green[800] : errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textGray,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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
              child: pw.Text('Crop Finance Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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
                  pw.Text('NET INCOME',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.SizedBox(height: 8),
                  pw.Text(_formatCurrency(_netIncome),
                      style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Based on $_cycleCount completed cycle(s)',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.green800)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellPadding: const pw.EdgeInsets.all(8),
              headers: ['Item', 'Amount'],
              data: [
                ['Crop Name', _cropName],
                ['Harvest Income', _formatCurrency(_grossIncome)],
                ['Total Cycle Cost', '-${_formatCurrency(_totalCycleCost)}'],
                ['Damage Cost', '-${_formatCurrency(_damageCost)}'],
                ['Net Income', _formatCurrency(_netIncome)],
                ['Profit/Loss', '${_profitPercentage.toStringAsFixed(1)}%'],
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text('This report was generated automatically from completed cycle data.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
          ],
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/crop_finance_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Crop Finance Report - $dateStr',
        ),
      );
    } catch (e) {
      debugPrint('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getUserFriendlyError(e)),
            backgroundColor: errorRed,
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
