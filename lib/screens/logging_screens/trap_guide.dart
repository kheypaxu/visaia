import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Trap Guide Screen - Educational guide for pheromone trap installation and monitoring
/// 
/// This screen provides farmers with visual and textual guidance on:
/// - What pheromone traps are and how they work
/// - Why they are important for pest management
/// - When and where to install traps
/// - How to monitor and maintain traps
/// - How the app integrates trap data with other monitoring tools
class TrapGuideScreen extends StatelessWidget {
  const TrapGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F7),
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildTopNoticeCard(),
            const SizedBox(height: 24),
            _buildWhatItDoesSection(),
            const SizedBox(height: 24),
            _buildWhyImportantCard(),
            const SizedBox(height: 24),
            _buildWhenToInstallSection(),
            const SizedBox(height: 24),
            _buildProperPlacementSection(),
            const SizedBox(height: 24),
            _buildWeeklyCheckingSection(),
            const SizedBox(height: 24),
            _buildHowAppHelpsCard(),
            const SizedBox(height: 24),
            _buildImageCard(),
            const SizedBox(height: 24),
            _buildRememberCard(),
            const SizedBox(height: 32),
            _buildBottomButton(context),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ========================
  // APP BAR
  // ========================
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF0F5234),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pheromone Trap',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'Biological Control',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Colors.green.shade300,
            ),
          ),
        ],
      ),
      titleSpacing: 0,
    );
  }

  // ========================
  // 1. TOP NOTICE CARD
  // ========================
  Widget _buildTopNoticeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bug_report,
              color: const Color(0xFF0F5234),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Pheromone traps help detect adult Fall Armyworm early before serious crop damage happens.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // 2. WHAT IT DOES SECTION
  // ========================
  Widget _buildWhatItDoesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What it does',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F5234),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A pheromone trap attracts moths using a scent lure. This helps farmers detect pest activity in the field early.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF333333),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        _buildTrapDiagram(),
      ],
    );
  }

  // Trap Diagram Placeholder
  Widget _buildTrapDiagram() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Plant representation (right side)
          Positioned(
            right: 40,
            top: 20,
            child: Column(
              children: [
                Icon(
                  Icons.grass,
                  color: Colors.green.shade700,
                  size: 36,
                ),
                const SizedBox(height: 4),
                Text(
                  'Plant',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Trap representation (left side)
          Positioned(
            left: 40,
            top: 20,
            child: Column(
              children: [
                Icon(
                  Icons.track_changes,
                  color: const Color(0xFF0F5234),
                  size: 32,
                ),
                const SizedBox(height: 4),
                Text(
                  'Trap',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF0F5234),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Height indicator
          Positioned(
            left: 70,
            top: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '1.5 meters',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF0F5234),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // Dotted line between trap and plant
          Positioned(
            left: 70,
            top: 55,
            right: 60,
            child: CustomPaint(
              painter: DottedLinePainter(),
            ),
          ),
          // Arrow indicators
          Positioned(
            left: 100,
            bottom: 15,
            child: Row(
              children: [
                Icon(
                  Icons.arrow_upward,
                  color: Colors.grey.shade600,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Scent attractant',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // 3. WHY IT IS IMPORTANT CARD
  // ========================
  Widget _buildWhyImportantCard() {
    final benefits = [
      {'icon': Icons.search, 'text': 'Detects pests before damage increases'},
      {'icon': Icons.trending_up, 'text': 'Helps monitor pest movement'},
      {'icon': Icons.warning_amber_rounded, 'text': 'Supports early warning system'},
      {'icon': Icons.lightbulb_outline, 'text': 'Improves decision making'},
      {'icon': Icons.spa_outlined, 'text': 'Reduces unnecessary spraying'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why it is important',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F5234),
            ),
          ),
          const SizedBox(height: 12),
          ...benefits.map((benefit) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  benefit['icon'] as IconData,
                  color: const Color(0xFF0F5234),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    benefit['text'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF333333),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ========================
  // 4. WHEN TO INSTALL SECTION
  // ========================
  Widget _buildWhenToInstallSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When to install',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F5234),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Install traps at the beginning of the cropping cycle to monitor pest presence from early plant growth until harvest.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF333333),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _buildCropCycleTimeline(),
      ],
    );
  }

  // Crop Cycle Timeline
  Widget _buildCropCycleTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Track with dots
          Stack(
            children: [
              // Line
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.green.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Dots and labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTimelineDot('Planting', true),
                  _buildTimelineDot('Growth', false),
                  _buildTimelineDot('Harvest', false),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDot(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF0F5234) : Colors.white,
            border: Border.all(
              color: isActive ? const Color(0xFF0F5234) : Colors.green.shade300,
              width: 3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? const Color(0xFF0F5234) : const Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  // ========================
  // 5. PROPER PLACEMENT SECTION
  // ========================
  Widget _buildProperPlacementSection() {
    final placements = [
      {'icon': Icons.location_on, 'label': 'Inside or near field'},
      {'icon': Icons.height, 'label': '1–1.5m high'},
      {'icon': Icons.apartment, 'label': 'Away from buildings'},
      {'icon': Icons.hub, 'label': '4–5 per hectare'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proper placement',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F5234),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: placements.map((item) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    color: const Color(0xFF0F5234),
                    size: 28,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['label'] as String,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ========================
  // 6. WEEKLY CHECKING SECTION
  // ========================
  Widget _buildWeeklyCheckingSection() {
    final steps = [
      'Check weekly',
      'Count moths',
      'Upload image if unsure',
      'Record in app',
      'Dispose moths properly & Reuse trap',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly checking',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F5234),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F5F2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: List.generate(steps.length, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: index < steps.length - 1 ? 12 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F5234),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        steps[index],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ========================
  // 7. HOW THE APP HELPS CARD
  // ========================
  Widget _buildHowAppHelpsCard() {
    final workflow = ['TRAP', 'DATA', 'RISK MAP', 'ALERT'];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How the app helps',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F5234),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The app combines trap records with field scouting and pest detection to calculate infestation risk in nearby farms.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF333333),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Workflow pipeline
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(workflow.length, (index) {
                return Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F5234).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            workflow[index][0],
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F5234),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workflow[index],
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F5234),
                          ),
                        ),
                      ],
                    ),
                    if (index < workflow.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Colors.green.shade400,
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // 8. IMAGE CARD
  // ========================
  Widget _buildImageCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            height: 140,
            width: double.infinity,
            color: Colors.green.shade800,
            child: Center(
              child: Icon(
                Icons.photo_camera_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ),
          // Gradient overlay
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          // Text overlay
          Positioned(
            bottom: 16,
            left: 16,
            child: Text(
              'Example of trap monitoring',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // 9. REMEMBER WARNING CARD
  // ========================
  Widget _buildRememberCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0F5234).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0F5234),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Icon(
            Icons.info_outline,
            color: const Color(0xFF0F5234),
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Pheromone traps help monitor pests. They do not control infestation by themselves. Regular monitoring is still required.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF1A1A1A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // 10. BOTTOM ACTION BUTTON
  // ========================
  Widget _buildBottomButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          // TODO: Navigate to Install Traps screen
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F5234),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Text(
          'Install and Setup your Traps?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ========================
// CUSTOM PAINTER FOR DOTTED LINE
// ========================
class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6;
    const dashSpace = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}