import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThreatDetailsScreen extends StatelessWidget {
  final String alertId;

  const ThreatDetailsScreen({super.key, required this.alertId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D4D33)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Threat Details',
          style: GoogleFonts.epilogue(
            color: const Color(0xFF0D4D33),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('alerts').doc(alertId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading alert',
                    style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Alert not found',
                    style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Risk Badge
                _buildRiskBadge(data['risk'] ?? 'Moderate'),
                const SizedBox(height: 16),

                // Title
                Text(
                  data['title'] ?? 'Pest Alert',
                  style: GoogleFonts.epilogue(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C18),
                  ),
                ),
                const SizedBox(height: 12),

                // Metadata Row (Crop, Life Stage)
                _buildMetadataRow(data),
                const SizedBox(height: 24),

                // Alert Message
                _buildSectionTitle('Alert Message'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E5DC)),
                  ),
                  child: Text(
                    data['message'] ?? 'No additional details provided.',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      color: const Color(0xFF43483E),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Mitigation Strategy
                _buildSectionTitle('Recommended Mitigation Strategy'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (data['mitigationStrategy'] != null &&
                          data['mitigationStrategy'].toString().isNotEmpty)
                        Text(
                          data['mitigationStrategy'],
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            color: const Color(0xFF1A1C18),
                            height: 1.6,
                          ),
                        )
                      else
                        _buildDefaultMitigation(data),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Detection Details
                if (data['detection'] != null || data['lifeStage'] != null)
                  _buildDetailsCard(data),
                const SizedBox(height: 24),

                // Timestamp
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _formatTimestamp(data['createdAt']),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRiskBadge(String risk) {
    Color bgColor;
    Color textColor;
    String label;

    switch (risk.toLowerCase()) {
      case 'high':
        bgColor = const Color(0xFFFFE5E5);
        textColor = const Color(0xFFBA1A1A);
        label = 'CRITICAL RISK';
        break;
      case 'moderate':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE2A000);
        label = 'MODERATE RISK';
        break;
      default:
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        label = 'LOW RISK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMetadataRow(Map<String, dynamic> data) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        if (data['cropAffected'] != null)
          _metadataChip(
            icon: Icons.eco,
            label: data['cropAffected'],
          ),
        if (data['lifeStage'] != null)
          _metadataChip(
            icon: Icons.bug_report,
            label: data['lifeStage'],
          ),
        if (data['distanceKm'] != null)
          _metadataChip(
            icon: Icons.straighten,
            label: '${data['distanceKm']} km away',
          ),
      ],
    );
  }

  Widget _metadataChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5DC)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0D4D33)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF43483E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.epilogue(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF1A1C18),
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detection Details',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A1C18),
            ),
          ),
          const SizedBox(height: 12),
          if (data['detection'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, size: 16, color: Color(0xFF0D4D33)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pest: ${data['detection']}',
                      style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF43483E)),
                    ),
                  ),
                ],
              ),
            ),
          if (data['risk'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 16, color: Color(0xFF0D4D33)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Risk Level: ${data['risk']}',
                      style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF43483E)),
                    ),
                  ),
                ],
              ),
            ),
          if (data['reportedBy'] != null)
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Color(0xFF0D4D33)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reported by: ${data['reportedBy']}',
                    style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF43483E)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultMitigation(Map<String, dynamic> data) {
    final pest = data['detection'] ?? '';
    
    if (pest.toLowerCase().contains('armyworm') || pest.toLowerCase().contains('faw')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBulletPoint('Apply Emamectin benzoate or Spinetoram within 24 hours'),
          _buildBulletPoint('Monitor fields daily for egg masses and young larvae'),
          _buildBulletPoint('Use pheromone traps to reduce male population'),
          _buildBulletPoint('Practice crop rotation in the next planting season'),
          _buildBulletPoint('Maintain field hygiene by removing crop residues'),
        ],
      );
    }
    
    if (pest.toLowerCase().contains('rust') || pest.toLowerCase().contains('puccinia')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBulletPoint('Apply azoxystrobin or pyraclostrobin immediately'),
          _buildBulletPoint('Remove and destroy infected leaves'),
          _buildBulletPoint('Ensure good air circulation by proper spacing'),
          _buildBulletPoint('Avoid overhead irrigation'),
          _buildBulletPoint('Use resistant varieties in the next season'),
        ],
      );
    }
    
    if (pest.toLowerCase().contains('borer')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBulletPoint('Apply Trichogramma egg parasitoids'),
          _buildBulletPoint('Use pheromone traps for monitoring'),
          _buildBulletPoint('Remove and destroy dead hearts'),
          _buildBulletPoint('Apply recommended insecticides if infestation exceeds threshold'),
        ],
      );
    }
    
    // Default general mitigation
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint('Inspect your farm within 500m of the reported location'),
        _buildBulletPoint('Apply recommended organic or chemical controls based on local guidelines'),
        _buildBulletPoint('Report any unusual sightings to your extension officer'),
        _buildBulletPoint('Keep a log of pest pressure for future reference'),
        _buildBulletPoint('Consult with local agricultural experts for specific recommendations'),
      ],
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: const Color(0xFF1A1C18),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final diff = now.difference(date);
      
      if (diff.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      }
      return 'Just now';
    }
    return timestamp.toString();
  }
}