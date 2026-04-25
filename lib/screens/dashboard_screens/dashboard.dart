import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key});

  // Strict Brand Colors from Figma/Images
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color forestGreen = Color(0xFF173408);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Main Metrics Grid ---
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: "NET INCOME",
                    value: "\$12,450",
                    icon: Icons.payments_outlined,
                    bgColor: darkGreen,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: "TOTAL YIELD",
                    value: "2,840",
                    unit: "kg",
                    icon: Icons.agriculture_rounded,
                    bgColor: const Color(0xFFC5E1A5),
                    textColor: darkGreen,
                  ),
                ),
              ],
            ),
   const SizedBox(height: 15), // Matching Figma layout spacing
Row(
  children: [
    Expanded(
      child: _buildSmallMetricCard(
        "ACTIVE CYCLE",
        "14",
        "days",
        const Color(0xFF7BC72E).withValues(alpha:0.6), // Matching Figma Fill: 7BC72E @ 60%
      ),
    ),
    const SizedBox(width: 15), // Spacing: 15 from Figma
    Expanded(
      child: _buildSmallMetricCard(
        "FIELD COUNT",
        "42",
        "",
        const Color(0xFFF7E594),
      ),
    ),
  ],
),
            const SizedBox(height: 40),

            // --- Active Pests Section ---
            Text(
              "Active Pests",
              style: GoogleFonts.epilogue(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: headingBlack),
            ),
            Text(
              "Critical monitoring required",
              style: GoogleFonts.manrope(
                  fontSize: 16,
                  color: textGray,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),

            _buildPestPill(
                "Fall Armyworm",
                "Detected in Sector 7B • High Severity",
                const Color.fromARGB(255, 247, 206, 206),
                const Color(0xFFBA1A1A)),
            _buildPestPill(
                "Corn Borer",
                "North Plot • Moderate Severity",
                const Color.fromARGB(166, 255, 221, 221),
                const Color(0xFFBA1A1A)),
            _buildPestPill(
                "Aphids",
                "South Greenhouse • Low Severity",
                const Color(0xFF7E5800),
                const Color.fromARGB(255, 255, 235, 200)),
            _buildPestPill(
                "Spider Mites",
                "East Field • Monitoring",
                const Color.fromARGB(197, 144, 118, 56),
                const Color.fromARGB(249, 255, 225, 168)),
            _buildPestPill(
                "Locusts",
                "Regional Warning • Alert Only",
                const Color.fromARGB(255, 240, 240, 240),
                const Color.fromARGB(216, 64, 73, 67)),

            const SizedBox(height: 40),

            // --- Recent Activity Section ---
            Text(
              'Recent Activity',
              style: GoogleFonts.epilogue(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: headingBlack,
              ),
            ),
            const SizedBox(height: 20),

            _buildActivityCard(
                "Irrigation Cycle Completed",
                "Sector 7B • Optimal Soil Health",
                "2H AGO",
                Icons.water_drop,
                const Color.fromARGB(255, 228, 248, 229)),
            _buildActivityCard(
                "Fertilizer Applied",
                "North Plot • Nitrogen Mix",
                "5H AGO",
                Icons.center_focus_strong,
                const Color.fromARGB(223, 235, 216, 179)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 24),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: GoogleFonts.manrope(
                  color: textColor.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: GoogleFonts.manrope(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit,
                    style: GoogleFonts.manrope(
                        color: textColor.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ]
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "VIEW DETAILS",
            style: GoogleFonts.manrope(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard(String title, String value, String unit, Color color) {
  // Maintaining icons from your requested images
  IconData displayIcon = title.contains("CYCLE") 
      ? Icons.stacked_line_chart_rounded 
      : Icons.grid_view_rounded;

  return Container(
    width: 167, // Fixed Width from Figma
    height: 131, // Fixed Height from Figma
    padding: const EdgeInsets.all(16), 
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24), // Corner Radius: 24
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.5), // 50% White Stroke
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween, 
      children: [
        // Top Icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            shape: BoxShape.circle,
          ),
          child: Icon(displayIcon, size: 18, color: Colors.black.withValues(alpha: 0.7)),
        ),
        
        // Bottom Content
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.manrope(
                color: Colors.black.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    color: const Color(0xFF1A1C18),
                    fontSize: 28, // Scaled to fit H:131 perfectly
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: GoogleFonts.manrope(
                      color: Colors.black.withValues(alpha: 0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildPestPill(String title, String subtitle, Color circleBg, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bug_report, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: headingBlack)),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        color: textGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String title, String subtitle, String time, IconData icon, Color iconBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: darkGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: headingBlack)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        color: textGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(time,
              style: GoogleFonts.manrope(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}