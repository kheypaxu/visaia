import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FaqArticleScreen extends StatelessWidget {
  const FaqArticleScreen({super.key});

  // Theme Colors
  static const Color darkGreen = Color(0xFF173408);
  static const Color lightGreenLabel = Color(0xFFD4E9BE);
  static const Color bgGrey = Color(0xFFF9FAF9);
  static const Color textGray = Color(0xFF4A4A4A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        backgroundColor: bgGrey,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help Center',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tutorial Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lightGreenLabel,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book_outlined, size: 14, color: darkGreen),
                  const SizedBox(width: 6),
                  Text(
                    'TUTORIAL',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: darkGreen,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'How do I export\nmy yield data?',
              style: GoogleFonts.epilogue(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: darkGreen,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 20),

            // Author Info
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFFC5E1A5),
                  child: Text('V', style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Text(
                  'By VISAIA Support • Updated 2 days ago',
                  style: GoogleFonts.manrope(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- FEATURED IMAGE SECTION ---
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/Visual.png', // PASTE YOUR IMAGE PATH HERE
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                // Fallback placeholder if the path is wrong or missing
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 220,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.grey, size: 40),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Article Body
            _buildParagraph(
                "Seamless data integration is at the core of VISAIA's stewardship model. Exporting your yield data allows you to share critical performance metrics with agronomists or maintain external backups for historical auditing."),
            
            _buildParagraph(
                "To begin the process, navigate to the Harvest dashboard from your main navigation menu. Within this view, locate the \"Field Selection\" drawer to specify which parcels of land you wish to include in your data set."),

            // Workflow Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F1),
                borderRadius: BorderRadius.circular(16),
                border: const Border(left: BorderSide(color: darkGreen, width: 4)),
              ),
              child: Column(
                children: [
                  Text(
                    'The Export Workflow',
                    style: GoogleFonts.epilogue(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStepText('Once on the Harvest screen, tap the Insights sub-menu.'),
                  _buildStepText('Select the Prepare Export Archive button at the top right of the data table.'),
                  _buildStepText('Choose your preferred format: CSV (best for spreadsheets) or ISOXML (best for hardware integration).'),
                  _buildStepText('Click Generate File. A secure download link will be prepared and sent to your registered email address.', isLast: true),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            _buildParagraph(
                "Please note that processing times may vary based on the size of your dataset and the resolution of the sensor nodes used during the harvest window. Most archives are ready within 60 seconds."),

            const SizedBox(height: 40),

            // "Was this helpful" Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E8E4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Was this helpful?',
                    style: GoogleFonts.epilogue(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your feedback helps us improve our support. We use these ratings to curate our most valuable insights.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(color: textGray, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildFeedbackBtn(Icons.thumb_up_alt_outlined, 'Yes'),
                      const SizedBox(width: 16),
                      _buildFeedbackBtn(Icons.thumb_down_alt_outlined, 'No'),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Related Questions Section
            Text(
              'Related Questions',
              style: GoogleFonts.epilogue(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 16),
            _buildRelatedItem(Icons.wifi_tethering, 'Connecting a new sensor node?', const Color(0xFFD4E9BE)),
            _buildRelatedItem(Icons.satellite_alt_outlined, 'Troubleshooting satellite delays', const Color(0xFFD4E9BE)),
            _buildRelatedItem(Icons.insert_chart_outlined_outlined, 'Viewing historical harvest reports', const Color(0xFFD4E9BE)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 16,
          height: 1.6,
          color: textGray,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStepText(String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.manrope(
          fontSize: 14,
          height: 1.5,
          color: textGray,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFeedbackBtn(IconData icon, String label) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18, color: darkGreen),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: darkGreen,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          textStyle: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildRelatedItem(IconData icon, String title, Color iconBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: darkGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}