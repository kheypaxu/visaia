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
        child: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('cycles')
              .doc(cycleId)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: kPrimaryGreen),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
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
            return _CompletedCycleContent(data: data);
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
    final timestamp = data['harvestDate'];
    if (timestamp != null && timestamp is Timestamp) {
      return timestamp.toDate();
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
  
  double get totalYield => (data['totalYield'] ?? 0.0).toDouble();
  double get area => (data['area'] ?? 0.0).toDouble();
  double get pestLoss => (data['pestLoss'] ?? 0.0).toDouble();
  double get otherLoss => (data['otherLoss'] ?? 0.0).toDouble();
  double get grossIncome => (data['grossIncome'] ?? 0.0).toDouble();
  double get netIncome => (data['netIncome'] ?? 0.0).toDouble();
  
  double get efficiencyScore {
    // Calculate efficiency based on yield vs expected (simplified)
    // You can adjust this formula based on your business logic
    final expectedYield = area * 8.0; // Assuming 8 tons per hectare as baseline
    if (expectedYield <= 0) return 0.0;
    final efficiency = (totalYield / expectedYield) * 100;
    return efficiency.clamp(0.0, 100.0);
  }
  
  double get pestControlSuccess {
    if (pestLoss <= 0) return 100.0;
    // Calculate success rate based on pest loss percentage
    return (100.0 - pestLoss).clamp(0.0, 100.0);
  }
  
  double get irrigationAccuracy {
    // This could be fetched from a separate collection
    // For now, return a default or calculate based on other metrics
    return 94.5; // Placeholder - you can modify this
  }
  
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
                    const SizedBox(height: 24),
                    _buildGeographicalArchive(),
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
            style: TextStyle(color: kPrimaryGreen, fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cycleName,
          style: const TextStyle(color: kPrimaryGreen, fontSize: 32, fontWeight: FontWeight.w800),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: kTextGrey),
                const SizedBox(width: 4),
                Text(fieldName, style: const TextStyle(color: kTextGrey, fontWeight: FontWeight.w600)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('ARCHIVED DATE', style: TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.w800)),
                Text(formattedArchivedDate, style: const TextStyle(color: kPrimaryGreen, fontSize: 16, fontWeight: FontWeight.w700)),
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
            style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestSummary() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HARVEST SUMMARY', style: TextStyle(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStat(totalYield.toStringAsFixed(1), 'Tons', 'Final Yield'),
              const SizedBox(width: 40),
              _buildStat(area.toStringAsFixed(2), 'Ha', 'Harvested Area'),
            ],
          ),
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
                const Text('Planting Date:', style: TextStyle(color: kTextGrey, fontSize: 12)),
                Text(formattedPlantingDate, style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w600)),
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
                const Text('Harvest Date:', style: TextStyle(color: kTextGrey, fontSize: 12)),
                Text(formattedHarvestDate, style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
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
            Text(value, style: const TextStyle(color: kPrimaryGreen, fontSize: 32, fontWeight: FontWeight.w900)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(color: kPrimaryGreen, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        Text(label, style: const TextStyle(color: kTextGrey, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildEfficiencyScore() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('EFFICIENCY SCORE', style: TextStyle(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${efficiencyScore.toStringAsFixed(1)}%', style: const TextStyle(color: kPrimaryGreen, fontSize: 36, fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              Icon(
                efficiencyScore >= 70 ? Icons.trending_up : Icons.trending_down,
                color: efficiencyScore >= 70 ? kAccentGreen : Colors.orange,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: efficiencyScore / 100,
            backgroundColor: kBorder,
            color: efficiencyScore >= 70 ? kAccentGreen : Colors.orange,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on expected yield of 8 tons/Ha',
            style: TextStyle(color: kTextGrey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialResults() {
    final pestLossAmount = (totalYield * (pestLoss / 100)).toDouble();
    final otherLossAmount = otherLoss;
    final totalDeductions = pestLossAmount + otherLossAmount;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kPrimaryGreen,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FINANCIAL RESULTS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          _buildFinanceRow('Gross Income', '₱${grossIncome.toStringAsFixed(2)}'),
          if (pestLoss > 0)
            _buildFinanceRow('Pest Loss (${pestLoss.toStringAsFixed(1)}%)', '- ₱${pestLossAmount.toStringAsFixed(2)}'),
          if (otherLoss > 0)
            _buildFinanceRow('Other Losses', '- ₱${otherLoss.toStringAsFixed(2)}'),
          const Divider(color: Colors.white24, height: 32),
          const Center(child: Text('NET INCOME', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800))),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '₱${netIncome.toStringAsFixed(2)}',
              style: const TextStyle(color: kWhite, fontSize: 40, fontWeight: FontWeight.w900),
            ),
          ),
          if (pestLoss > 0 || otherLoss > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Total deductions: ₱${totalDeductions.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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

  Widget _buildTimelineItem(String title, String date, String sub, bool showLine) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.check_circle, color: kPrimaryGreen, size: 24),
            if (showLine) Container(width: 2, height: 50, color: kPrimaryGreen.withOpacity(0.2)),
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
                  Text(title, style: const TextStyle(color: kPrimaryGreen, fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(date, style: const TextStyle(color: kTextGrey, fontSize: 12)),
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

  Widget _buildGeographicalArchive() {
    final lat = data['latitude'];
    final lng = data['longitude'];
    final location = data['location'] ?? fieldName;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: kPrimaryGreen.withOpacity(0.1),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1500382017468-9049fed747ef?q=80&w=1000'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, kPrimaryGreen.withOpacity(0.8)],
            ),
          ),
          padding: const EdgeInsets.all(24),
          alignment: Alignment.bottomLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('GEOGRAPHICAL ARCHIVE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(color: kWhite, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (lat != null && lng != null)
                Text(
                  'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder.withOpacity(0.5)),
      ),
      child: child,
    );
  }
}