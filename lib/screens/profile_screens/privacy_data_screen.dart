import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyDataScreen extends StatelessWidget {
  const PrivacyDataScreen({super.key});

  // UI Color Palette
  static const Color primaryDark = Color(0xFF173408);
  static const Color bgOffWhite = Color(0xFFF9FAF7);
  static const Color accentGreen = Color(0xFFD4EFB0);
  static const Color iconBgGreen = Color(0xFFD9F0C1);
  static const Color textMain = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF555555);
  static const Color dangerRed = Color(0xFFBD0000);
  static const Color dangerBg = Color(0xFFFFF5F5);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgOffWhite,
      appBar: AppBar(
        backgroundColor: bgOffWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy & Data',
          style: GoogleFonts.epilogue(
            color: primaryDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Data Sovereignty Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accentGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FIXED: Changed check_shield to verified_user
                  Icon(Icons.verified_user, size: 14, color: primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    'DATA SOVEREIGNTY',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Farm, Your Data',
              style: GoogleFonts.epilogue(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'At VISAIA, we believe in a simple principle: you own your agricultural information. Period.',
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Main Policy Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  _buildPolicyItem(
                    icon: Icons.agriculture_outlined,
                    title: 'Farmer Ownership',
                    description:
                        'Every data point generated on your fields—from soil health metrics to yield history—is exclusively owned by you. We serve as the stewards of your information, never the owners.',
                  ),
                  const SizedBox(height: 32),
                  _buildPolicyItem(
                    icon: Icons.security_outlined,
                    title: 'Uncompromising Security',
                    description:
                        'The VISAIA ecosystem utilizes industry-leading encryption and decentralized architecture to ensure your proprietary farm data remains protected against unauthorized access.',
                  ),
                  const SizedBox(height: 32),
                  _buildPolicyItem(
                    icon: Icons.handshake_outlined,
                    title: 'Transparent Partnership',
                    description:
                        'We do not sell your data to third parties. Any integration or sharing within the Verdant Harvest network only happens with your explicit, case-by-case authorization.',
                  ),
                  const SizedBox(height: 40),
                  Divider(color: Colors.grey.withOpacity(0.1)),
                  const SizedBox(height: 20),
                  Text(
                    '"Empowering farmers through data sovereignty is at the heart of our mission." — The VISAIA Team',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            // View Policy Link
            Center(
              child: TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.description_outlined, size: 18, color: primaryDark),
                label: Text(
                  'View Full Privacy Policy',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    color: primaryDark,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Danger Zone
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dangerBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: dangerRed, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Danger Zone',
                        style: GoogleFonts.epilogue(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: dangerRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dangerRed,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Delete Account',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Permanently delete your account and all historical data. This action is irreversible.',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconBgGreen,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: primaryDark, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.epilogue(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}