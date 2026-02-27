import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/core/models/crop_type.dart';
import 'package:visaia/screens/monitoring/detection_history_details_screen.dart';

class DetectionHistoryListScreen extends StatelessWidget {
  final FarmArea farmArea;

  const DetectionHistoryListScreen({
    Key? key,
    required this.farmArea,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: Stack(
        children: [
          // Background Glows
          Positioned(top: -100, right: -100, child: _buildBlurCircle(300, const Color(0xFF8DBA60).withValues(alpha: 0.05))),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHeader(context),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final detection = farmArea.detectionHistory.reversed.toList()[index];
                        return _buildDetectionCard(context, detection);
                      },
                      childCount: farmArea.detectionHistory.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      expandedHeight: 80,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text('DETECTION HISTORY', 
          style: GoogleFonts.inter(
            fontSize: 12, 
            letterSpacing: 2, 
            fontWeight: FontWeight.w900, 
            color: const Color(0xFF8DBA60)
          )
        ),
      ),
    );
  }

  Widget _buildDetectionCard(BuildContext context, PestDetection detection) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionHistoryDetailsScreen(detection: detection),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.bug_report, color: Colors.redAccent, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detection.label, 
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: const Color(0xFF8DBA60), size: 12),
                      const SizedBox(width: 4),
                      Text('${(detection.confidence * 100).toInt()}% Confidence', 
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  Text(DateFormat('MMM dd, yyyy • hh:mm a').format(detection.timestamp), 
                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 16),
          ],
        ),
      ),
    );
  }
}
