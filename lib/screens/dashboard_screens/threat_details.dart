import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/spread_risk_sheet.dart';

class ThreatDetailsScreen extends StatelessWidget {
  final String alertId;

  const ThreatDetailsScreen({super.key, required this.alertId});

  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);
  static const Color background = Color(0xFFF3F5EE);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('alerts').doc(alertId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: darkGreen));
          }

          if (snapshot.hasError) {
            return _buildFullScreenMessage(
              icon: Icons.error_outline,
              color: const Color(0xFFBA1A1A),
              title: 'Error loading alert',
              subtitle: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildFullScreenMessage(
              icon: Icons.notifications_off_rounded,
              color: Colors.grey,
              title: 'Alert not found',
              subtitle: 'This alert may have been removed.',
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final riskColor = _riskColor(data['risk']);
          final isSpreadRisk = data['distanceKm'] != null;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildHeroHeader(context, data, riskColor),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, isSpreadRisk ? 110 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetadataRow(data),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Alert Message', Icons.campaign_outlined),
                          const SizedBox(height: 10),
                          _buildCard(
                            child: Text(
                              data['message'] ?? 'No additional details provided.',
                              style: GoogleFonts.manrope(fontSize: 15, color: textGray, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Recommended Mitigation', Icons.shield_outlined),
                          const SizedBox(height: 10),
                          _buildMitigationCard(data),
                          if (data['detection'] != null || data['lifeStage'] != null || data['reportedBy'] != null) ...[
                            const SizedBox(height: 24),
                            _buildSectionTitle('Detection Details', Icons.fact_check_outlined),
                            const SizedBox(height: 10),
                            _buildDetailsCard(data),
                          ],
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _formatTimestamp(data['createdAt']),
                              style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (isSpreadRisk) _buildStickyMapButton(context, data, riskColor),
            ],
          );
        },
      ),
    );
  }

  // --- HERO HEADER ---
  Widget _buildHeroHeader(BuildContext context, Map<String, dynamic> data, Color riskColor) {
    final risk = (data['risk'] ?? 'Moderate').toString();
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      backgroundColor: riskColor,
      elevation: 0,
      leading: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [riskColor, riskColor.withValues(alpha: 0.75)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 70, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${risk.toUpperCase()} RISK',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data['title'] ?? 'Pest Alert',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.epilogue(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(Map<String, dynamic> data) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (data['cropAffected'] != null) _metadataChip(Icons.eco_rounded, data['cropAffected']),
        if (data['lifeStage'] != null) _metadataChip(Icons.bug_report_rounded, data['lifeStage']),
        if (data['distanceKm'] != null) _metadataChip(Icons.straighten_rounded, '${data['distanceKm']} km away'),
      ],
    );
  }

  Widget _metadataChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: darkGreen),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.manrope(fontSize: 12.5, fontWeight: FontWeight.w700, color: textGray)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: darkGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.epilogue(fontSize: 17, fontWeight: FontWeight.w800, color: headingBlack),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMitigationCard(Map<String, dynamic> data) {
    final hasCustom = data['mitigationStrategy'] != null && data['mitigationStrategy'].toString().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: hasCustom
          ? Text(
              data['mitigationStrategy'],
              style: GoogleFonts.manrope(fontSize: 15, color: headingBlack, height: 1.6),
            )
          : _buildDefaultMitigation(data),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['detection'] != null) _detailRow(Icons.bug_report_rounded, 'Pest', data['detection']),
          if (data['risk'] != null) _detailRow(Icons.warning_rounded, 'Risk Level', data['risk']),
          if (data['reportedBy'] != null) _detailRow(Icons.person_rounded, 'Reported by', data['reportedBy'], isLast: true),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: darkGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 15, color: darkGreen),
          ),
          const SizedBox(width: 10),
          Text('$label: ', style: GoogleFonts.manrope(fontSize: 13.5, fontWeight: FontWeight.w700, color: headingBlack)),
          Expanded(child: Text(value, style: GoogleFonts.manrope(fontSize: 13.5, color: textGray))),
        ],
      ),
    );
  }

  // --- STICKY MAP BUTTON (spread-risk alerts only) ---
  Widget _buildStickyMapButton(BuildContext context, Map<String, dynamic> data, Color riskColor) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        decoration: BoxDecoration(
          color: background,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final distance = data['distanceKm'] is num ? (data['distanceKm'] as num).toDouble() : null;
              showSpreadRiskSheet(
                context,
                pestName: data['detection'] ?? data['title'] ?? 'Unknown pest',
                riskLevel: (data['risk'] ?? 'Moderate').toString(),
                distanceKm: distance,
                cropAffected: data['cropAffected'],
                lifeStage: data['lifeStage'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: riskColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.map_rounded, size: 20),
            label: Text(
              'View Spread Risk Map',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: headingBlack)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultMitigation(Map<String, dynamic> data) {
    final pest = (data['detection'] ?? '').toString().toLowerCase();

    if (pest.contains('armyworm') || pest.contains('faw')) {
      return _bulletList(const [
        'Apply Emamectin benzoate or Spinetoram within 24 hours',
        'Monitor fields daily for egg masses and young larvae',
        'Use pheromone traps to reduce male population',
        'Practice crop rotation in the next planting season',
        'Maintain field hygiene by removing crop residues',
      ]);
    }
    if (pest.contains('rust') || pest.contains('puccinia')) {
      return _bulletList(const [
        'Apply azoxystrobin or pyraclostrobin immediately',
        'Remove and destroy infected leaves',
        'Ensure good air circulation by proper spacing',
        'Avoid overhead irrigation',
        'Use resistant varieties in the next season',
      ]);
    }
    if (pest.contains('borer')) {
      return _bulletList(const [
        'Apply Trichogramma egg parasitoids',
        'Use pheromone traps for monitoring',
        'Remove and destroy dead hearts',
        'Apply recommended insecticides if infestation exceeds threshold',
      ]);
    }
    return _bulletList(const [
      'Inspect your farm within 500m of the reported location',
      'Apply recommended organic or chemical controls based on local guidelines',
      'Report any unusual sightings to your extension officer',
      'Keep a log of pest pressure for future reference',
      'Consult with local agricultural experts for specific recommendations',
    ]);
  }

  Widget _bulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((text) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.manrope(fontSize: 14, color: headingBlack, height: 1.5),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _riskColor(dynamic risk) {
    switch ((risk ?? 'Moderate').toString().toLowerCase()) {
      case 'high':
        return const Color(0xFFBA1A1A);
      case 'moderate':
        return const Color(0xFFB8860B);
      default:
        return darkGreen;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
      if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
      if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
      return 'Just now';
    }
    return timestamp.toString();
  }
}