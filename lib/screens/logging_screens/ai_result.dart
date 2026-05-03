import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AIResultScreen extends StatelessWidget {
  // You can pass these parameters from the previous screen (e.g., UploadPestScreen)
  final String pestName;
  final String scientificName;
  final String severity; // "HIGH SEVERITY", "MEDIUM", "LOW"
  final int confidencePercent; // 0-100
  final String detectionStage; // "Larvae", "Eggs", "Pupae"
  final String cropAffected; // "Maize (Plot 4B)"
  final String treatmentPlan;
  final String historicalContext;

  const AIResultScreen({
    super.key,
    this.pestName = "Fall Armyworm",
    this.scientificName = "Spodoptera frugiperda",
    this.severity = "HIGH SEVERITY",
    this.confidencePercent = 98,
    this.detectionStage = "Larvae",
    this.cropAffected = "Maize (Plot 4B)",
    this.treatmentPlan = "Immediate action required. Handpicking and destroying larvae must be followed. You may opt to use parasites, parasitoids, predators and entomopathogens to control FAW population. And you may also opt to use botanical and Inorganic pesticides approved by FDA to manage infestation, only when needed based on economic threshold.",
    this.historicalContext = "Similar infestation detected in this sector 14 months ago. Previous treatment efficacy was 85%.",
  });

  @override
  Widget build(BuildContext context) {
    final bool isHighSeverity = severity.toUpperCase().contains("HIGH");
    final Color severityColor = isHighSeverity ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);
    final Color confidenceColor = isHighSeverity ? const Color(0xFFD32F2F) : const Color(0xFFF57C00);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0C503C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "AI Diagnostics",
          style: GoogleFonts.inter(
            color: const Color(0xFF0C503C),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Pest Detection",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A5C30),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Severity & Confidence Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: severityColor, width: 1),
                  ),
                  child: Text(
                    severity,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: severityColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: confidenceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: confidenceColor, width: 1),
                  ),
                  child: Text(
                    "$confidencePercent% CONFIDENCE",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: confidenceColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Main Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pestName,
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0C503C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scientificName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow("DETECTION STAGE", detectionStage),
                  const SizedBox(height: 16),
                  _buildInfoRow("CROP AFFECTED", cropAffected),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // AI Treatment Plan
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A5C30).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medical_services_outlined,
                            color: Color(0xFF1A5C30), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "AI Treatment Plan",
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0C503C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    treatmentPlan,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: const Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      // TODO: Navigate to full treatment protocol screen
                    },
                    child: Text(
                      "View Full Treatment Protocol →",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A5C30),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Historical Context
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDDEEE4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history, color: Color(0xFFFFA000), size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      historicalContext,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF5D4037),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1A5C30)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Retake Photo",
                      style: GoogleFonts.inter(
                        color: const Color(0xFF1A5C30),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to upload pest screen or proceed to assign
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A5C30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      "Assign to Cycle",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9E9E9E),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ),
      ],
    );
  }
}