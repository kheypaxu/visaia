import 'package:visaia/widgets/notification_proximity_map.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Call this to open the spread-risk visualization as a bottom sheet.
/// Works out of the box with just [distanceKm] — no map SDK required.
Future<void> showSpreadRiskSheet(
  BuildContext context, {
  required Map<String, dynamic> alertData,
  required String pestName,
  required String riskLevel,
  double? distanceKm,
  String? cropAffected,
  String? lifeStage,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SpreadRiskSheet(
      alertData: alertData,
      pestName: pestName,
      riskLevel: riskLevel,
      distanceKm: distanceKm,
      cropAffected: cropAffected,
      lifeStage: lifeStage,
    ),
  );
}

class SpreadRiskSheet extends StatelessWidget {
  final Map<String, dynamic> alertData;
  final String pestName;
  final String riskLevel;
  final double? distanceKm;
  final String? cropAffected;
  final String? lifeStage;

  const SpreadRiskSheet({
    super.key,
    required this.alertData,
    required this.pestName,
    required this.riskLevel,
    this.distanceKm,
    this.cropAffected,
    this.lifeStage,
  });

  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);
  static const Color dangerRed = Color(0xFFBA1A1A);
  static const Color amber = Color(0xFFB8860B);

  Color get _riskColor {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return dangerRed;
      case 'moderate':
        return amber;
      default:
        return darkGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? km = distanceKm;
    final String zoneLabel = km == null
        ? 'Distance unavailable'
        : km <= 2
        ? 'Immediate Risk Zone'
        : km <= 5
        ? 'Caution Zone'
        : 'Watch Zone';

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF3F5EE),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.radar_rounded, color: _riskColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Proximity / Monitoring Zone',
                      style: GoogleFonts.epilogue(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: headingBlack,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Report location and your saved farm boundaries. '
                'Represents a proximity monitoring zone for heightened surveillance, not guaranteed infestation or pest spread.',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: textGray,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // --- The radial visualization ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    NotificationProximityMap(alertData: alertData),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _riskColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        km == null
                            ? zoneLabel
                            : '${km.toStringAsFixed(1)} km away · $zoneLabel',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _riskColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- Legend ---
              _legendRow(
                dangerRed,
                'Immediate Monitoring Zone (0–2 km)',
                'Nearby detection: inspect fields and increase monitoring within 24 hours',
              ),
              _legendRow(
                amber,
                'Caution Monitoring Zone (2–5 km)',
                'Monitor closely, prepare preventative controls',
              ),
              _legendRow(
                darkGreen,
                'General Monitoring Zone (5 km+)',
                'Maintain routine scouting, log any sightings',
              ),
              const SizedBox(height: 20),

              // --- Quick facts ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reported Threat',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: headingBlack,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _factRow(Icons.bug_report_rounded, 'Pest', pestName),
                    if (cropAffected != null)
                      _factRow(Icons.eco_rounded, 'Crop', cropAffected!),
                    if (lifeStage != null)
                      _factRow(
                        Icons.timeline_rounded,
                        'Life stage',
                        lifeStage!,
                      ),
                    _factRow(
                      Icons.straighten_rounded,
                      'Distance',
                      km == null
                          ? 'Unavailable'
                          : '${km.toStringAsFixed(1)} km from your farm',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    'Got it',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendRow(Color color, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: headingBlack,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(fontSize: 12, color: textGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: darkGreen),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: headingBlack,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(fontSize: 13, color: textGray),
            ),
          ),
        ],
      ),
    );
  }
}
