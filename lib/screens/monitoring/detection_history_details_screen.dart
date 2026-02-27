import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/core/models/crop_type.dart';

class DetectionHistoryDetailsScreen extends StatelessWidget {
  final PestDetection detection;

  const DetectionHistoryDetailsScreen({
    Key? key,
    required this.detection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.all(28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildImageSection(),
                const SizedBox(height: 32),
                _buildIdentitySection(),
                const SizedBox(height: 24),
                _buildMetricsSection(),
                const SizedBox(height: 24),
                _buildInsightsSection(),
                const SizedBox(height: 60),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: const Color(0xFF102216),
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      expandedHeight: 80,
      centerTitle: true,
      title: Text('DETECTION LOG', 
        style: GoogleFonts.inter(fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w900, color: const Color(0xFF8DBA60))),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 20)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(detection.imageUrl), fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 24, left: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8DBA60),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.black, size: 14),
                    const SizedBox(width: 8),
                    Text('AI VERIFIED', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IDENTIFIED THREAT', 
                  style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white38)),
                Text(detection.label, 
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Row(
      children: [
        Expanded(child: _buildInfoCard('Confidence', '${(detection.confidence * 100).toInt()}%', Icons.analytics_outlined)),
        const SizedBox(width: 16),
        Expanded(child: _buildInfoCard('Captured', DateFormat('MMM dd').format(detection.timestamp), Icons.calendar_today_rounded)),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8DBA60), size: 20),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NEURAL SCAN INSIGHTS', 
          style: GoogleFonts.inter(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF8DBA60))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF8DBA60).withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFF8DBA60).withValues(alpha: 0.1)),
          ),
          child: Text(
            'The scan revealed high concentration of ${detection.label} activity. Immediate mitigation recommended using targeted biological control or pheromone traps to disrupt reproduction cycles.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.6, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
