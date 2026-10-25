import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/services/notification_content.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/spread_risk_sheet.dart';

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
        future: FirebaseFirestore.instance
            .collection('alerts')
            .doc(alertId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: darkGreen),
            );
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
          final content = NotificationContent(data);
          final risk = content.risk.toLowerCase();
          final double? distance =
              content.isPestAlert &&
                  content.risk.isNotEmpty &&
                  data['distanceKm'] is num
              ? (data['distanceKm'] as num).toDouble()
              : null;

          final Color themeColor = content.isMao
              ? darkGreen
              : _resolveThemeColor(type, risk);
          final String categoryTitle = content.label;
          final IconData categoryIcon = _resolveCategoryIcon(type, risk, data);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildHeroAppBar(
                    context,
                    data,
                    themeColor,
                    categoryTitle,
                    categoryIcon,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        distance != null ? 100 : 36,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 2. Alert Message & Details
                          _buildSectionTitle(
                            content.isMao
                                ? 'MAO Advisory'
                                : content.isPestAlert
                                ? 'Alert Message'
                                : 'Advisory Message',
                            Icons.campaign_outlined,
                          ),
                          const SizedBox(height: 10),
                          _buildCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  content.message.isEmpty
                                      ? 'No message provided.'
                                      : content.message,
                                  style: GoogleFonts.inter(
                                    fontSize: 14.5,
                                    color: textDark,
                                    height: 1.55,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (data['farmName'] != null ||
                                    data['fieldName'] != null) ...[
                                  const SizedBox(height: 14),
                                  const Divider(
                                    height: 1,
                                    color: Color(0xFFF1F5F9),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                        color: darkGreen,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Target: ${data['farmName'] ?? ''} ${data['fieldName'] != null ? '(${data['fieldName']})' : ''}'
                                              .trim(),
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

                          _buildMetricsGrid(data),
                          const SizedBox(height: 20),

                          // 3. RCPC Validation Details (if validation alert)
                          if (type.contains('validation')) ...[
                            _buildSectionTitle(
                              'RCPC Validation Review',
                              Icons.verified_outlined,
                            ),
                            const SizedBox(height: 10),
                            _buildValidationCard(data, type),
                            const SizedBox(height: 20),
                          ],

                          if (content.recommendations.isNotEmpty) ...[
                            _buildSectionTitle(
                              'Recommendations from issuing office',
                              Icons.shield_outlined,
                            ),
                            const SizedBox(height: 10),
                            _buildMitigationCard(data),
                            const SizedBox(height: 20),
                          ],

                          // 6. Timestamp Footer
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.schedule_rounded,
                                  size: 14,
                                  color: textGray,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Received ${_formatTimestamp(data['createdAt'])}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: textGray,
                                  ),
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
    final content = NotificationContent(data);
    return SliverToBoxAdapter(
      child: Container(
        color: themeColor,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  categoryTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  content.text('title').isEmpty
                      ? 'Notification'
                      : content.text('title'),
                  style: GoogleFonts.epilogue(
                    fontSize: 24,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- KEY METRICS GRID ---
  Widget _buildMetricsGrid(Map<String, dynamic> data) {
    final content = NotificationContent(data);
    final area =
        [
              data['municipality'] ?? data['targetMunicipality'],
              data['barangay'] ?? data['areaName'],
            ]
            .where((v) => v != null && v.toString().trim().isNotEmpty)
            .map((v) => v.toString())
            .toSet()
            .join(' · ');
    final fields = <String, String>{
      if (content.text('source').isNotEmpty)
        'Issued by': content.text('source'),
      if (area.isNotEmpty) 'Target area': area,
      if (content.priority.isNotEmpty) 'Priority': content.priority,
      if (content.risk.isNotEmpty) 'Risk level': content.risk,
      if (content.isPestAlert && content.text('detection').isNotEmpty)
        'Pest': content.text('detection'),
      if (content.isPestAlert && content.text('cropAffected').isNotEmpty)
        'Crop': content.text('cropAffected'),
      if (content.isPestAlert && content.text('lifeStage').isNotEmpty)
        'Life stage': content.text('lifeStage'),
    };
    if (fields.isEmpty) return const SizedBox.shrink();
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: fields.entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  '${entry.key}: ${entry.value}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: textDark,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // --- RCPC VALIDATION CARD ---
  Widget _buildValidationCard(Map<String, dynamic> data, String type) {
    final isRejected = type.contains('rejected');
    final String statusText = isRejected
        ? 'Validation Rejected'
        : 'Validation Confirmed';
    final String? notes =
        data['validationNotes'] ??
        data['rejectionReason'] ??
        data['advisoryMessage'];
    final String officer = data['validatedBy'] ?? 'RCPC Regional Officer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejected ? rejectBg : successBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRejected
              ? rejectRose.withValues(alpha: 0.3)
              : successEmerald.withValues(alpha: 0.3),
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
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: textGray,
                  fontWeight: FontWeight.w600,
                ),
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
    return _buildCard(
      child: SelectableText(
        NotificationContent(data).recommendations,
        style: GoogleFonts.inter(fontSize: 14, color: textDark, height: 1.55),
      ),
    );
  }

  // --- STICKY MAP BUTTON ---
  Widget _buildStickyMapButton(
    BuildContext context,
    Map<String, dynamic> data,
    Color themeColor,
  ) {
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
              final distance = data['distanceKm'] is num
                  ? (data['distanceKm'] as num).toDouble()
                  : null;
              showSpreadRiskSheet(
                context,
                alertData: data,
                pestName: data['detection'] ?? data['title'] ?? 'Unknown pest',
                riskLevel: NotificationContent(data).risk,
                distanceKm: distance,
                cropAffected: data['cropAffected'],
                lifeStage: data['lifeStage'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.radar_rounded, size: 20),
            label: Text(
              'View Proximity / Monitoring Zone',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
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
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: textGray,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveThemeColor(String type, String risk) {
    if (type.contains('validation_rejected')) return rejectRose;
    if (type.contains('validation_confirmed') || type.contains('validated'))
      return successEmerald;
    if (risk == 'high') return dangerRed;
    if (risk == 'moderate') return warningAmber;
    return darkGreen;
  }

  IconData _resolveCategoryIcon(
    String type,
    String risk, [
    Map<String, dynamic>? data,
  ]) {
    final sender = (data?['sender'] ?? data?['source'] ?? data?['issuer'] ?? '')
        .toString()
        .toLowerCase();
    final title = (data?['title'] ?? '').toString().toLowerCase();

    if (type.contains('validation_rejected')) return Icons.cancel_rounded;
    if (type.contains('validation_confirmed') || type.contains('validated'))
      return Icons.verified_rounded;
    if (type.contains('mao') || sender.contains('mao') || title.contains('mao'))
      return Icons.location_city_rounded;
    if (type.contains('rcpc') ||
        type.contains('technical') ||
        sender.contains('rcpc'))
      return Icons.biotech_rounded;
    if (risk == 'high') return Icons.warning_amber_rounded;
    if (risk == 'moderate') return Icons.radar_rounded;
    return Icons.campaign_rounded;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Date unavailable';
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
