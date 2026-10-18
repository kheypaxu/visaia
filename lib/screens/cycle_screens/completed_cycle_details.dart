import 'package:visaia/core/models/cycle_metrics.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- CONSTANTS ---
const Color kPrimaryGreen = Color(0xFF134E39);
const Color kAccentGreen = Color(0xFF27AE60);
const Color kBackground = Color(0xFFF9FBFB);
const Color kWhite = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF1A1C1E);
const Color kTextGrey = Color(0xFF5E6266);
const Color kBorder = Color(0xFFE8ECEF);
const Color kCompletedBg = Color(0xFFE8F5E9);

class CompletedCycleScreen extends StatelessWidget {
  final String cycleId;
  final String userId;

  const CompletedCycleScreen({
    super.key,
    required this.cycleId,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cycles')
              .doc(cycleId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kPrimaryGreen),
              );
            }

            if (snapshot.hasError ||
                !snapshot.hasData ||
                !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: kTextGrey),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading cycle data',
                      style: TextStyle(color: kTextGrey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryGreen,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (cycleNumber(data['area']) != null || data['fieldId'] == null) {
              return _CompletedCycleContent(data: data);
            }
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .collection('fields')
                  .doc(data['fieldId'] as String)
                  .snapshots(),
              builder: (context, fieldSnapshot) {
                final acres = cycleNumber(fieldSnapshot.data?.data()?['acres']);
                return _CompletedCycleContent(
                  data: {
                    ...data,
                    if (acres != null) 'area': acres * 0.40468564224,
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CompletedCycleContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _CompletedCycleContent({required this.data});

  String get cycleName => data['cycleName'] ?? 'Unknown Cycle';
  String get fieldName => data['fieldName'] ?? 'Unknown Field';
  String get cropVariety => data['cropVariety'] ?? 'Unknown Variety';

  DateTime? get plantingDate {
    final timestamp = data['plantingDate'];
    if (timestamp != null && timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  DateTime? get harvestDate {
    final raw =
        data['expectedHarvestDate'] ??
        data['estimatedHarvestDate'] ??
        data['harvestDate'] ??
        data['actualHarvestDate'];
    if (raw != null) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
      if (raw is String) return DateTime.tryParse(raw);
    }
    return null;
  }

  DateTime? get archivedDate {
    final timestamp = data['createdAt'];
    if (timestamp != null && timestamp is Timestamp) {
      return timestamp.toDate();
    }
    return null;
  }

  double get totalYield => recordedYield(data) ?? 0;
  double get area => cycleNumber(data['area']) ?? 0;
  double get pestLoss => (data['pestLoss'] ?? 0.0).toDouble();
  double get otherLoss => (data['otherLoss'] ?? 0.0).toDouble();
  CycleFinance get finance => CycleFinance(data);
  double get grossIncome => finance.gross;
  double get damagedYield => (data['damagedYield'] ?? 0.0).toDouble();
  double get marketPrice => (data['marketPrice'] ?? 0.0).toDouble();
  double get lossRate => (data['lossRate'] ?? 0.0).toDouble();

  double get netIncome => finance.net;

  double? get efficiencyScore => cycleEfficiency(data);

  double get pestControlSuccess {
    if (pestLoss <= 0 && damagedYield <= 0) return 100.0;
    if (grossIncome <= 0) return 100.0;
    final totalLossValue = pestLoss + otherLoss + (damagedYield * marketPrice);
    final lossPercentage = (totalLossValue / grossIncome) * 100;
    return (100.0 - lossPercentage).clamp(0.0, 100.0);
  }

  double get irrigationAccuracy {
    return 94.5;
  }

  bool get isHarvestRecording => data['totalValue'] != null;
  bool get isPreviousCycle => data['isPreviousCycle'] == true;

  String get formattedArchivedDate {
    if (archivedDate == null) return 'Not archived';
    return DateFormat('MMM d, yyyy').format(archivedDate!);
  }

  String get formattedPlantingDate {
    if (plantingDate == null) return 'Not set';
    return DateFormat('MMM d, yyyy').format(plantingDate!);
  }

  String get formattedHarvestDate {
    if (harvestDate == null) return 'Not set';
    return DateFormat('MMM d, yyyy').format(harvestDate!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: Column(
          children: [
            // --- APP BAR ---
            _buildAppBar(context),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeaderSection(),
                    const SizedBox(height: 24),
                    _buildHarvestSummary(),
                    const SizedBox(height: 24),
                    _buildEfficiencyScore(),
                    const SizedBox(height: 24),
                    _buildFinancialResults(),
                    const SizedBox(height: 32),
                    const Text(
                      'Closing Activities',
                      style: TextStyle(
                        color: kPrimaryGreen,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTimeline(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        children: [
          // Back button - positioned left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: kPrimaryGreen),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Centered title
          const Center(
            child: Text(
              'Cycle Details',
              style: TextStyle(
                color: kPrimaryGreen,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: kCompletedBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'COMPLETED',
            style: TextStyle(
              color: kPrimaryGreen,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cycleName,
          style: const TextStyle(
            color: kPrimaryGreen,
            fontSize: 32,
            fontWeight: FontWeight.w800,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: kTextGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  fieldName,
                  style: const TextStyle(
                    color: kTextGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'ARCHIVED DATE',
                  style: TextStyle(
                    color: kTextGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  formattedArchivedDate,
                  style: const TextStyle(
                    color: kPrimaryGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: kBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Text(
            'Variety: $cropVariety',
            style: const TextStyle(
              color: kTextGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestSummary() {
    final actualYield = cycleNumber(data['actualYield']);
    final goodYield = (data['goodYield'] as num?)?.toDouble();
    final displayYield = actualYield ?? totalYield;
    const yieldUnit = 'kg';

    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HARVEST SUMMARY',
            style: TextStyle(
              color: kTextGrey,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat(
                displayYield.toStringAsFixed(1),
                yieldUnit,
                'Final Yield',
              ),
              const SizedBox(width: 40),
              _buildStat(area.toStringAsFixed(2), 'Ha', 'Harvested Area'),
            ],
          ),
          if (isHarvestRecording && damagedYield > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStat(damagedYield.toStringAsFixed(1), 'kg', 'Damaged'),
                const SizedBox(width: 40),
                _buildStat(
                  marketPrice.toStringAsFixed(0),
                  '₱/kg',
                  'Market Price',
                ),
              ],
            ),
          ],
          if (goodYield != null && goodYield > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kCompletedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Good Yield:',
                    style: TextStyle(color: kTextGrey, fontSize: 12),
                  ),
                  Text(
                    '${goodYield.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: kPrimaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Planting Date:',
                  style: TextStyle(color: kTextGrey, fontSize: 12),
                ),
                Text(
                  formattedPlantingDate,
                  style: const TextStyle(
                    color: kPrimaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Harvest Date:',
                  style: TextStyle(color: kTextGrey, fontSize: 12),
                ),
                Text(
                  formattedHarvestDate,
                  style: const TextStyle(
                    color: kPrimaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (lossRate > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Loss Rate:',
                    style: TextStyle(color: kTextGrey, fontSize: 12),
                  ),
                  Text(
                    '${lossRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String value, String unit, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: kPrimaryGreen,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                color: kPrimaryGreen,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            color: kTextGrey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEfficiencyScore() {
    final score = efficiencyScore;
    final color = score == null
        ? kTextGrey
        : score >= 70
        ? kAccentGreen
        : Colors.orange;
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EFFICIENCY SCORE',
            style: TextStyle(
              color: kTextGrey,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                score == null ? 'N/A' : '${score.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: kPrimaryGreen,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                score == null ? Icons.info_outline : Icons.speed,
                color: color,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: ((score ?? 0) / 100).clamp(0.0, 1.0),
            backgroundColor: kBorder,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            score == null
                ? 'Not enough data: recorded yield and a positive area in hectares are required.'
                : '${totalYield.toStringAsFixed(1)} kg / (${area.toStringAsFixed(2)} ha x 8,000 kg/ha) x 100. Fixed yield benchmark.',
            style: TextStyle(color: kTextGrey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialResults() {
    final values = finance;
    final currency = NumberFormat.currency(symbol: '\u20B1', decimalDigits: 2);
    final deductions = <String, double>{
      'Damage costs': -values.damage,
      'Control methods': -values.control,
      'Fertilizer': -values.fertilizer,
      'Seeds': -values.seeds,
      'Other expenses': -values.other,
      if (values.costAdjustment.abs() >= 0.005)
        'Saved cycle cost adjustment': -values.costAdjustment,
    };
    final totalDeductions = values.damage + values.costs;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kPrimaryGreen,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FINANCIAL RESULTS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          _buildFinanceRow('Gross Income', currency.format(values.gross)),
          for (final entry in deductions.entries)
            _buildFinanceRow(entry.key, currency.format(entry.value)),
          const SizedBox(height: 8),
          _buildFinanceRow(
            'Total deductions',
            currency.format(totalDeductions),
          ),
          if (values.netAdjustment.abs() >= 0.005)
            _buildFinanceRow(
              'Saved net income adjustment',
              currency.format(values.netAdjustment),
            ),
          const Divider(color: Colors.white24, height: 32),
          const Center(
            child: Text(
              'NET INCOME',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '₱${netIncome.toStringAsFixed(2)}',
              style: const TextStyle(
                color: kWhite,
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Net income = gross income - damage costs - cycle expenses '
              '+ saved net adjustment (if any). Damaged harvest value is not deducted again. '
              'Saved adjustments reconcile stored totals with itemized amounts.',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: [
        _buildTimelineItem(
          'Cycle Archived',
          formattedArchivedDate,
          'Final records moved to long-term storage.',
          true,
        ),
        _buildTimelineItem(
          'Record Finalized',
          formattedHarvestDate,
          'Harvest metrics validated by regional supervisor.',
          true,
        ),
        _buildTimelineItem(
          'Harvest Completed',
          formattedHarvestDate,
          'All designated plots fully cleared.',
          false,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String title,
    String date,
    String sub,
    bool showLine,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.check_circle, color: kPrimaryGreen, size: 24),
            if (showLine)
              Container(
                width: 2,
                height: 50,
                color: kPrimaryGreen.withValues(alpha: 0.2),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: kPrimaryGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    date,
                    style: const TextStyle(color: kTextGrey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: kTextGrey, fontSize: 13)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}
