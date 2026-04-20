import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/profile_screens/faqs_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  // UI Color Palette
  static const Color darkGreen = Color(0xFF173408);
  static const Color lightGreenBtn = Color(0xFFC5E1A5);
  static const Color bgGrey = Color(0xFFF9FAF9);
  static const Color searchBg = Color(0xFFF1F4F1);
  
  // Specific Icon Colors for "Get In Touch"
  static const Color iconGreenLight = Color(0xFFD4E9BE); // Email bg
  static const Color iconGreenDark = Color(0xFF2E4D21);  // Phone bg
  static const Color iconFacebook = Color(0xFF3F4E41);   // FB bg

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF2E4D21),
              child: const Icon(
                Icons.account_circle_outlined, 
                color: Color(0xFFC5E1A5), 
                size: 30
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Search Bar Section ---
            Container(
              height: 60,
              decoration: BoxDecoration(
                color: searchBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search for guides and solutions...',
                  hintStyle: GoogleFonts.manrope(
                    color: Colors.black45, 
                    fontSize: 16,
                    fontWeight: FontWeight.w500
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 15, right: 10),
                    child: Icon(Icons.search, color: Colors.black54, size: 28),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- FAQ Section ---
            _buildSectionTitle('GET YOUR QUESTIONS ANSWERED BY VISAIA'),
            const SizedBox(height: 12),
            _buildFaqItem(
              'How do I export my yield data?',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaqArticleScreen(),
                  ),
                );
              },
            ),
            _buildFaqItem('Connecting a new sensor node?',
              () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FaqArticleScreen(),
                    ),
                  );
                },
              ),
            _buildFaqItem('Troubleshooting satellite delays',
            () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FaqArticleScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // --- Help Card Section ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: darkGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Text(
                    'Still need help?',
                    style: GoogleFonts.epilogue(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our experts are available 24/7 for field assistance.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.support_agent, color: darkGreen),
                    label: const Text('Contact Support'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightGreenBtn,
                      foregroundColor: darkGreen,
                      minimumSize: const Size(double.infinity, 56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- Get In Touch Section ---
            _buildSectionTitle('GET IN TOUCH'),
            const SizedBox(height: 16),
            _buildContactTile(
              icon: Icons.email_outlined,
              title: 'Email Us',
              subtitle: 'support@visaia.com',
              iconBg: iconGreenLight,
              iconSize: 20, // Specific Email Icon Size
            ),
            _buildContactTile(
              icon: Icons.phone_outlined,
              title: 'Call Us',
              subtitle: '+1 234 567 890',
              iconBg: iconGreenDark,
              iconSize: 18, // Specific Call Icon Size
            ),
            _buildContactTile(
              icon: Icons.facebook,
              title: 'Facebook',
              subtitle: 'Follow us for updates',
              iconBg: iconFacebook,
              iconSize: 24, // Specific Facebook Icon Size
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: darkGreen,
      ),
    );
  }

  Widget _buildFaqItem(String text, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF212121),
              ),
            ),
          ),
          const Icon(Icons.north_east, size: 20, color: Colors.black87),
        ],
      ),
    ),
  );
}

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconBg,
    required double iconSize,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          // Background Container fixed to 40x40
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon, 
              color: iconBg == iconGreenLight ? const Color(0xFF4A633C) : Colors.white, 
              size: iconSize, // Custom sizes per your request
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black54, size: 24),
        ],
      ),
    );
  }
}