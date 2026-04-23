
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  // Brand Colors
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications & Alerts',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            Text(
              'Alerts & Intel',
              style: GoogleFonts.epilogue(
                fontSize: 35,
                fontWeight: FontWeight.w700,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Real-time agricultural intelligence and actionable\nnotifications for your managed zones.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: textGray,
                height: 1.9,
              ),
            ),
            const SizedBox(height: 32),

            // --- Alerts List ---
            const AlertCard(
              category: "NEARBY OUTBREAK",
              title: "Puccinia Graminis Detected",
              description: "Stem rust spore clusters detected in Sector 4 sensors. Immediate fungicide application recommended within 24 hours.",
              time: "10 mins ago",
              icon: Icons.warning_amber_rounded,
              accentColor: Color(0xFFBA1A1A), // Red
              isNew: true,
            ),
            const AlertCard(
              category: "IRRIGATION WARNING",
              title: "Soil Moisture Critical",
              description: "Moisture levels in Zone B have dropped below the 30% threshold. Automated irrigation system flagged for review.",
              time: "2 hours ago",
              icon: Icons.opacity,
              accentColor: Color(0xFFE2A000), // Orange/Yellow
              isNew: true,
            ),
            const AlertCard(
              category: "HARVEST REMINDER",
              title: "Optimal Window Approaching",
              description: "Based on current GDD accumulation, the optimal harvest window for the North Field soy will open in 5 days.",
              time: "Yesterday",
              icon: Icons.agriculture_rounded,
              accentColor: Color.fromARGB(255, 101, 160, 43), // Green
              isNew: false,
            ),
            const AlertCard(
              category: "WEATHER UPDATE",
              title: "Frost Risk Dissipated",
              description: "Overnight low temperatures remained above freezing. No crop damage reported across monitored zones.",
              time: "Yesterday",
              icon: Icons.cloud_outlined,
              accentColor: Color.fromARGB(255, 50, 138, 101), // Dark Green
              isNew: false,
            ),
          ],
        ),
      ),
    );
  }
}

// --- THE ALERT CARD COMPONENT ---
class AlertCard extends StatelessWidget {
  final String category;
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color accentColor;
  final bool isNew;

  const AlertCard({
    super.key,
    required this.category,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.accentColor,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4), // Subtle radius from image
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Left Accent Border ---
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            // --- Content Area ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Circular Icon background
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha:0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: accentColor, size: 24),
                        ),
                        const SizedBox(width: 16),
                        // Category and Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    category,
                                    style: GoogleFonts.manrope(
                                      color: accentColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    time,
                                    style: GoogleFonts.manrope(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Title with New Indicator
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: GoogleFonts.manrope(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A1C18),
                                      ),
                                    ),
                                  ),
                                  if (isNew)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Description Text
                    Padding(
                      padding: const EdgeInsets.only(left: 60), // Align text with title
                      child: Text(
                        description,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: const Color(0xFF43483E),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}