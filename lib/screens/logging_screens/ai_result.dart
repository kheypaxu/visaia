import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/logging_screens/assign_pest_detected.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';

class AIResultScreen extends StatelessWidget {
  final String pestName;
  final String scientificName;
  final String severity;
  final int confidencePercent;
  final String detectionStage;
  final String cropAffected;
  final String analysis;
  final String treatment;
  final String historicalContext;
  final File? imageFile;
  final String? annotatedImageUrl;
  final String userId;
  final double? latitude;
  final double? longitude;
  final String? areaName;

  const AIResultScreen({
    super.key,
    required this.pestName,
    required this.scientificName,
    required this.severity,
    required this.confidencePercent,
    required this.detectionStage,
    required this.cropAffected,
    required this.analysis,
    required this.treatment,
    required this.historicalContext,
    this.imageFile,
    this.annotatedImageUrl,
    required this.userId,
    this.latitude,
    this.longitude,
    this.areaName,
  });

  // ── Palette ──────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF2F6F3);
  static const _darkGreen = Color(0xFF0C3D28);
  static const _green = Color(0xFF1A5C30);
  static const _accentGreen = Color(0xFF4DBD74);
  static const _lightGreen = Color(0xFFEAF5EE);
  static const _border = Color(0xFFDDE9E2);
  static const _card = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF8FA99A);
  static const _bodyText = Color(0xFF3D5247);

  // ── Severity helpers ─────────────────────────────────────────────────────
  Color get _severityColor {
    final s = severity.toUpperCase();
    if (s.contains('HIGH') || s.contains('CRITICAL')) return const Color(0xFFD32F2F);
    if (s.contains('MEDIUM') || s.contains('MOD')) return const Color(0xFFF57C00);
    return const Color(0xFF2E7D32);
  }

  Color get _severityBg => _severityColor.withOpacity(0.09);

  IconData get _severityIcon {
    final s = severity.toUpperCase();
    if (s.contains('HIGH') || s.contains('CRITICAL')) return Icons.warning_amber_rounded;
    if (s.contains('MEDIUM') || s.contains('MOD')) return Icons.info_outline_rounded;
    return Icons.check_circle_outline_rounded;
  }

  // ── Save to Firestore ─────────────────────────────────────────────────────
  Future<void> _saveToReports(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A5C30)),
          ),
        ),
      );

      String? base64Image;
      
      // Convert image file to base64 if available
      if (imageFile != null) {
        final bytes = await imageFile!.readAsBytes();
        final base64String = base64Encode(bytes);  // ✅ correct encoding
        base64Image = 'data:image/jpeg;base64,$base64String';
      }

      // Prepare report data matching your Firestore structure
      final reportData = {
        'detection': pestName,
        'scientificName': scientificName,
        'lifeStage': detectionStage.toLowerCase(),
        'confidence': confidencePercent / 100, // Store as decimal (0-1)
        'risk': _getRiskLevel(),
        'cropAffected': cropAffected,
        'analysis': analysis,
        'treatment': treatment,
        'historicalContext': historicalContext,
        'imageBase64': base64Image,
        'annotatedImageUrl': annotatedImageUrl,
        'farmerId': userId,
        'farmerName': await _getFarmerName(),
        'status': 'pending', // Default status
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'lat': latitude ?? 0.0,
          'lng': longitude ?? 0.0,
          'areaName': areaName ?? 'Unknown Area',
        },
      };

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('reports')
          .add(reportData);

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Report saved successfully! ID: ${docRef.id.substring(0, 8)}...',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Failed to save report: ${e.toString()}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String _getRiskLevel() {
    final s = severity.toUpperCase();
    if (s.contains('HIGH') || s.contains('CRITICAL')) return 'High';
    if (s.contains('MEDIUM') || s.contains('MOD')) return 'Medium';
    return 'Low';
  }

  Future<String> _getFarmerName() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['name'] ?? data?['displayName'] ?? 'Unknown Farmer';
      }
      return 'Unknown Farmer';
    } catch (e) {
      return 'Unknown Farmer';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildIdentityCard(),
                const SizedBox(height: 14),
                _buildStatsRow(),
                const SizedBox(height: 14),
                _buildAnalysisCard(),
                const SizedBox(height: 14),
                _buildTreatmentCard(),
                const SizedBox(height: 14),
                _buildHistoricalCard(),
                const SizedBox(height: 28),
                _buildActionButtons(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sliver App Bar with hero image ───────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: _darkGreen,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
      ),
      title: Text(
        'AI Diagnostics',
        style: GoogleFonts.manrope(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        // Save button in app bar
        GestureDetector(
          onTap: () => _saveToReports(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Save',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero image
            if (annotatedImageUrl != null)
              Image.network(
                annotatedImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imageFallback(),
              )
            else if (imageFile != null)
              Image.file(imageFile!, fit: BoxFit.cover)
            else
              _imageFallback(),

            // Dark gradient overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black38,
                    Colors.black12,
                    Colors.black54,
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),

            // Bottom labels inside hero
            Positioned(
              bottom: 16,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  _heroPill(
                    icon: _severityIcon,
                    label: severity,
                    color: _severityColor,
                  ),
                  const SizedBox(width: 8),
                  _heroPill(
                    icon: Icons.verified_rounded,
                    label: '$confidencePercent% match',
                    color: _accentGreen,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    return Container(
      color: _darkGreen,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white30, size: 48),
      ),
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Identity Card ────────────────────────────────────────────────────────

  Widget _buildIdentityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETECTED PEST',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pestName,
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _darkGreen,
                        height: 1.1,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scientificName,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              // Confidence badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  children: [
                    Text(
                      '$confidencePercent%',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _green,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'match',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _infoCell(
                  icon: Icons.biotech_rounded,
                  label: 'LIFE STAGE',
                  value: detectionStage,
                ),
              ),
              Container(width: 1, height: 40, color: _border),
              Expanded(
                child: _infoCell(
                  icon: Icons.grass_rounded,
                  label: 'CROP',
                  value: cropAffected,
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCell({
    required IconData icon,
    required String label,
    required String value,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment: alignment == CrossAxisAlignment.end
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(icon, color: _accentGreen, size: 13),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _muted,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _darkGreen,
          ),
        ),
      ],
    );
  }

  // ── Stats Row ────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _severityBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _severityColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(_severityIcon, color: _severityColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Level: $severity',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _severityColor,
                  ),
                ),
                Text(
                  _severitySubtext,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: _severityColor.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _severityColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _severityColor.withOpacity(0.3)),
            ),
            child: Text(
              severity.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _severityColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _severitySubtext {
    final s = severity.toUpperCase();
    if (s.contains('HIGH') || s.contains('CRITICAL'))
      return 'Immediate action recommended';
    if (s.contains('MEDIUM') || s.contains('MOD'))
      return 'Monitor closely, treat within 48 hrs';
    return 'Low impact — continue monitoring';
  }

  // ── Analysis Card ─────────────────────────────────────────────────────────

  Widget _buildAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(
            icon: Icons.analytics_rounded,
            iconBg: _lightGreen,
            iconColor: _green,
            title: 'Analysis based on FAW Guidelines',
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: analysis,
            styleSheet: _markdownStyleSheet(isDark: false),
            selectable: true,
          )
        ],
      ),
    );
  }

  // ── Treatment Card ────────────────────────────────────────────────────────

  Widget _buildTreatmentCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C3D28),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
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
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.healing_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Treatment Plan',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: treatment,
            styleSheet: _markdownStyleSheet(isDark: true),
            selectable: true,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              // TODO: open full treatment protocol screen
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _accentGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Full Treatment Protocol',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _darkGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded,
                      color: _darkGreen, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Historical Card ───────────────────────────────────────────────────────

  Widget _buildHistoricalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDD9A3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_edu_rounded,
                color: Color(0xFFF59E0B), size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HISTORICAL CONTEXT',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF59E0B),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  historicalContext,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: const Color(0xFF6B4F12),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: _green, size: 16),
                      const SizedBox(width: 7),
                      Text(
                        'Retake',
                        style: GoogleFonts.manrope(
                          color: _green,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignPestScreen(
                        userId: userId,
                        pestName: pestName,
                        detectedStage: detectionStage.toLowerCase(),
                        imagePath: imageFile?.path,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _green.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_task_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 7),
                      Text(
                        'Assign to Cycle',
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Save Report Button
        GestureDetector(
          onTap: () => _saveToReports(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentGreen, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_upload_outlined,
                    color: Color(0xFF1A5C30), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Monitor Report for Risk Map',
                  style: GoogleFonts.manrope(
                    color: _green,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _cardHeader({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _darkGreen,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  MarkdownStyleSheet _markdownStyleSheet({required bool isDark}) {
    final baseTextStyle = GoogleFonts.manrope(fontSize: 13, height: 1.65);
    final bodyColor = isDark ? Colors.white.withOpacity(0.7) : _bodyText;
    final headingColor = isDark ? Colors.white : _darkGreen;

    return MarkdownStyleSheet(
      p: baseTextStyle.copyWith(color: bodyColor),
      h1: GoogleFonts.manrope(fontSize: 20, fontWeight: FontWeight.w800, color: headingColor, height: 1.3),
      h2: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: headingColor, height: 1.3),
      h3: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: headingColor, height: 1.35),
      h4: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700, color: headingColor, height: 1.4),
      strong: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? _accentGreen : _green),
      em: GoogleFonts.manrope(fontSize: 13, fontStyle: FontStyle.italic, color: bodyColor),
      listBullet: baseTextStyle.copyWith(color: bodyColor),
      blockquote: baseTextStyle.copyWith(  // ✅ fixed: blockquote (lowercase 'q')
        color: isDark ? Colors.white70 : const Color(0xFF6B4F12),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      blockquoteDecoration: BoxDecoration(  // ✅ fixed: blockquoteDecoration (lowercase 'q')
        border: Border(left: BorderSide(color: isDark ? _accentGreen : const Color(0xFFF59E0B), width: 4)),
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFFFBF0),
      ),
      code: GoogleFonts.manrope(fontSize: 12, color: Colors.blue.shade300, backgroundColor: Colors.black12),
    );
  }
}