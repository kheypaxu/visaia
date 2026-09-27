import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/spread_risk_sheet.dart';
import 'package:visaia/screens/report_history/report_details.dart';

class ThreatDetailsScreen extends StatelessWidget {
  final String alertId;

  const ThreatDetailsScreen({super.key, required this.alertId});

  // --- Brand Palette ---
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color forestGreen = Color(0xFF1B4332);
  static const Color background = Color(0xFFF6F8F5);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textGray = Color(0xFF64748B);

  // Status colors
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color successEmerald = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color rejectRose = Color(0xFFE11D48);
  static const Color rejectBg = Color(0xFFFFF1F2);

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
              icon: Icons.error_outline_rounded,
              color: dangerRed,
              title: 'Error loading alert',
              subtitle: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildFullScreenMessage(
              icon: Icons.notifications_off_rounded,
              color: textGray,
              title: 'Alert not found',
              subtitle: 'This alert may have been resolved or deleted.',
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final type = (data['type'] ?? '').toString().toLowerCase();
          final risk = (data['risk'] ?? 'Moderate').toString().toLowerCase();
          final double? distance = data['distanceKm'] is num ? (data['distanceKm'] as num).toDouble() : null;

          final Color themeColor = _resolveThemeColor(type, risk);
          final String categoryTitle = _resolveCategoryTitle(type, risk);
          final IconData categoryIcon = _resolveCategoryIcon(type, risk);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildHeroAppBar(context, data, themeColor, categoryTitle, categoryIcon),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 20, 20, distance != null ? 100 : 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Key Metrics Summary Grid
                          _buildMetricsGrid(data),
                          const SizedBox(height: 20),

                          // 2. Alert Message & Details
                          _buildSectionTitle('Alert Intelligence', Icons.campaign_outlined),
                          const SizedBox(height: 10),
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['message'] ?? 'No additional details provided.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    color: textDark,
                                    height: 1.55,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (data['farmName'] != null || data['fieldName'] != null) ...[
                                  const SizedBox(height: 14),
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 16, color: darkGreen),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Target: ${data['farmName'] ?? ''} ${data['fieldName'] != null ? '(${data['fieldName']})' : ''}'.trim(),
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: darkGreen,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 3. RCPC Validation Details (if validation alert)
                          if (type.contains('validation')) ...[
                            _buildSectionTitle('RCPC Validation Review', Icons.verified_outlined),
                            const SizedBox(height: 10),
                            _buildValidationCard(data, type),
                            const SizedBox(height: 20),
                          ],

                          // 4. Mitigation Strategy Card
                          _buildSectionTitle('Recommended Mitigation', Icons.shield_outlined),
                          const SizedBox(height: 10),
                          _buildMitigationCard(data),
                          const SizedBox(height: 20),

                          // 5. Linked Report Button (if available)
                          if (data['reportId'] != null) ...[
                            _buildReportJumpCard(context, data),
                            const SizedBox(height: 20),
                          ],

                          // 6. Timestamp Footer
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 14, color: textGray),
                                const SizedBox(width: 4),
                                Text(
                                  'Received ${_formatTimestamp(data['createdAt'])}',
                                  style: GoogleFonts.inter(fontSize: 12, color: textGray),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Sticky Map Button (if spread risk alert)
              if (distance != null)
                _buildStickyMapButton(context, data, themeColor),
            ],
          );
        },
      ),
    );
  }

  // --- HERO APP BAR ---
  Widget _buildHeroAppBar(
    BuildContext context,
    Map<String, dynamic> data,
    Color themeColor,
    String categoryTitle,
    IconData categoryIcon,
  ) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 210,
      backgroundColor: themeColor,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeColor,
                themeColor.withValues(alpha: 0.85),
                const Color(0xFF0F172A),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(categoryIcon, size: 13, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      categoryTitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Title
              Text(
                data['title'] ?? 'Threat Alert',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.epilogue(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- KEY METRICS GRID ---
  Widget _buildMetricsGrid(Map<String, dynamic> data) {
    final pest = data['detection'] ?? 'Not specified';
    final risk = (data['risk'] ?? 'Moderate').toString().toUpperCase();
    final crop = data['cropAffected'] ?? data['cropType'] ?? 'Corn';
    final stage = data['lifeStage'] ?? 'Active';
    final distance = data['distanceKm'] != null ? '${data['distanceKm']} km away' : 'Farm Zone';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Risk Level',
                  value: risk,
                  color: _riskTextColor(risk),
                ),
              ),
              Container(width: 1, height: 44, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.bug_report_rounded,
                  label: 'Threat / Pest',
                  value: pest,
                  color: darkGreen,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.eco_outlined,
                  label: 'Crop & Stage',
                  value: '$crop ($stage)',
                  color: const Color(0xFF2E7D32),
                ),
              ),
              Container(width: 1, height: 44, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.near_me_outlined,
                  label: 'Proximity',
                  value: distance,
                  color: warningAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: textGray),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- RCPC VALIDATION CARD ---
  Widget _buildValidationCard(Map<String, dynamic> data, String type) {
    final isRejected = type.contains('rejected');
    final String statusText = isRejected ? 'Validation Rejected' : 'Validation Confirmed';
    final String? notes = data['validationNotes'] ?? data['rejectionReason'] ?? data['advisoryMessage'];
    final String officer = data['validatedBy'] ?? 'RCPC Regional Officer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejected ? rejectBg : successBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRejected ? rejectRose.withValues(alpha: 0.3) : successEmerald.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected ? Icons.cancel_rounded : Icons.verified_rounded,
                color: isRejected ? rejectRose : successEmerald,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isRejected ? rejectRose : successEmerald,
                ),
              ),
              const Spacer(),
              Text(
                officer,
                style: GoogleFonts.inter(fontSize: 11.5, color: textGray, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              notes,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: textDark,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- MITIGATION STRATEGY CARD ---
  Widget _buildMitigationCard(Map<String, dynamic> data) {
    final hasCustom = data['mitigationStrategy'] != null && data['mitigationStrategy'].toString().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: hasCustom
          ? Text(
              data['mitigationStrategy'],
              style: GoogleFonts.inter(fontSize: 14, color: textDark, height: 1.55),
            )
          : _buildDefaultMitigation(data),
    );
  }

  Widget _buildDefaultMitigation(Map<String, dynamic> data) {
    final pest = (data['detection'] ?? '').toString().toLowerCase();

    if (pest.contains('armyworm') || pest.contains('faw')) {
      return _bulletList(const [
        'Apply Emamectin benzoate or Spinetoram within 24 hours of infestation detection.',
        'Scout fields in early morning or late afternoon for egg masses and young larvae.',
        'Install and maintain pheromone lure traps to monitor and trap adult male moths.',
        'Implement crop rotation with non-host legumes in the next planting cycle.',
        'Ensure field sanitation by properly clearing volunteer plants and crop residues.',
      ]);
    }
    if (pest.contains('rust') || pest.contains('puccinia')) {
      return _bulletList(const [
        'Apply registered protective fungicides (e.g. Azoxystrobin or Pyraclostrobin).',
        'Avoid overhead sprinkler irrigation to keep leaf surfaces dry.',
        'Prune or rogue severely infected lower leaves to restrict spore dispersal.',
        'Maintain proper row spacing to maximize canopy airflow and sun penetration.',
        'Select rust-tolerant hybrid corn seed varieties for the following cropping cycle.',
      ]);
    }
    if (pest.contains('borer')) {
      return _bulletList(const [
        'Release biological control agents (Trichogramma egg parasitoid wasps).',
        'Inspect whorls for "pin-hole" feeding marks and destroy dead hearts immediately.',
        'Deploy light and pheromone traps along field borders to suppress adult moths.',
        'Apply systemic botanical or targeted insecticide if damage exceeds 5% of plants.',
      ]);
    }
    return _bulletList(const [
      'Inspect your crop rows within 500m of the alert perimeter.',
      'Document and log pest pressure with the in-app Scouting Tool.',
      'Contact your local Municipal Agricultural Office or RCPC officer for on-site assistance.',
      'Adhere to the recommended Integrated Pest Management (IPM) guidelines.',
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
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: const Color(0xFF1E293B),
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- REPORT JUMP CARD ---
  Widget _buildReportJumpCard(BuildContext context, Map<String, dynamic> data) {
    final reportId = data['reportId'].toString();
    final reportType = data['reportType']?.toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 18, color: darkGreen),
              const SizedBox(width: 8),
              Text(
                'Linked Farm Inspection Report',
                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w700, color: textDark),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This alert is tied to an inspection report. You can review the photos, damage scores, and resolution status.',
            style: GoogleFonts.inter(fontSize: 12.5, color: textGray, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openLinkedReport(context, reportId, reportType),
              icon: const Icon(Icons.description_outlined, size: 16),
              label: const Text('View Full Report & Resolution'),
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLinkedReport(BuildContext context, String reportId, String? reportType) async {
    try {
      if (reportType == 'clustered') {
        final snap = await FirebaseFirestore.instance.collection('clustered_reports').doc(reportId).get();
        if (snap.exists && context.mounted) {
          final rData = snap.data()!;
          rData['reportType'] = 'clustered';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(reportId: reportId, reportData: rData, reportType: 'clustered'),
            ),
          );
          return;
        }
      }

      final regSnap = await FirebaseFirestore.instance.collection('reports').doc(reportId).get();
      if (regSnap.exists && context.mounted) {
        final rData = regSnap.data()!;
        rData['reportType'] = 'regular';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(reportId: reportId, reportData: rData, reportType: 'regular'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error opening report from threat details: $e');
    }
  }

  // --- STICKY MAP BUTTON ---
  Widget _buildStickyMapButton(BuildContext context, Map<String, dynamic> data, Color themeColor) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
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
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: const Icon(Icons.map_rounded, size: 20),
            label: Text(
              'View Interactive Spread Risk Map',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: darkGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.epilogue(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
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
              child: Icon(icon, size: 44, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: textDark)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.5, color: textGray, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveThemeColor(String type, String risk) {
    if (type.contains('validation_rejected')) return rejectRose;
    if (type.contains('validation_confirmed') || type.contains('validated')) return successEmerald;
    if (risk == 'high') return dangerRed;
    if (risk == 'moderate') return warningAmber;
    return darkGreen;
  }

  String _resolveCategoryTitle(String type, String risk) {
    if (type.contains('validation_rejected')) return 'VALIDATION REJECTED';
    if (type.contains('validation_confirmed') || type.contains('validated')) return 'RCPC VALIDATED';
    if (risk == 'high') return 'CRITICAL THREAT';
    if (risk == 'moderate') return 'NEARBY OUTBREAK';
    return 'AGRICULTURAL ADVISORY';
  }

  IconData _resolveCategoryIcon(String type, String risk) {
    if (type.contains('validation_rejected')) return Icons.cancel_rounded;
    if (type.contains('validation_confirmed') || type.contains('validated')) return Icons.verified_rounded;
    if (risk == 'high') return Icons.warning_amber_rounded;
    if (risk == 'moderate') return Icons.bug_report_rounded;
    return Icons.campaign_rounded;
  }

  Color _riskTextColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return dangerRed;
      case 'moderate':
        return warningAmber;
      default:
        return const Color(0xFF16A34A);
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'recently';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) return '${date.day}/${date.month}/${date.year}';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'just now';
    }
    return timestamp.toString();
  }
}