import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/logging_screens/assign_pest_detected.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

class AIResultScreen extends StatefulWidget {
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

  @override
  State<AIResultScreen> createState() => _AIResultScreenState();
}

class _AIResultScreenState extends State<AIResultScreen>
    with SingleTickerProviderStateMixin {
  // ── State variable for assigned cycle ─────────────────────────────────────
  String? _assignedCycleId;
  int? _assignedDap;
  String? _assignedGrowthStage;
  
  // ── Tab Controller ──────────────────────────────────────────────────────
  late TabController _tabController;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─── Risk Level System (5 Levels based on Life Stage + DAP) ────────────
  
  /// Get growth stage from DAP (Days After Planting)
  String _getGrowthStageFromDAP(int dap) {
    if (dap <= 14) return 'SEEDLING';
    if (dap <= 30) return 'EARLY_WHORL';
    if (dap <= 45) return 'LATE_WHORL';
    if (dap <= 55) return 'TASSELING_SILKING';
    if (dap <= 75) return 'GRAIN_FILLING';
    return 'MATURITY';
  }

  /// Get display name for growth stage
  String _getGrowthStageDisplay(int dap) {
    if (dap <= 14) return 'Seedling (0-14 DAP)';
    if (dap <= 30) return 'Early Whorl (14-30 DAP)';
    if (dap <= 45) return 'Late Whorl (30-45 DAP)';
    if (dap <= 55) return 'Tasseling-Silking (45-55 DAP)';
    if (dap <= 75) return 'Grain Filling (55-75 DAP)';
    return 'Maturity (75+ DAP)';
  }

  /// Calculate risk level based on life stage and DAP
  String _calculateRiskLevel({
    required String lifeStage,
    required int dap,
  }) {
    // Map life stage to key
    String ls = lifeStage.toLowerCase();
    String lifeStageKey;
    if (ls.contains('egg')) lifeStageKey = 'egg';
    else if (ls.contains('larva') || ls.contains('caterpillar')) lifeStageKey = 'larva';
    else if (ls.contains('pupa')) lifeStageKey = 'pupa';
    else if (ls.contains('moth') || ls.contains('adult')) lifeStageKey = 'moth';
    else lifeStageKey = 'none';
    
    // Get growth stage from DAP
    String growthStageKey = _getGrowthStageFromDAP(dap);
    
    // Risk matrix based on FAW Life Stage + Crop Growth Stage
    // From the MitigationNew.pdf document
    final riskMatrix = {
      'egg': {
        'SEEDLING': 'Low',
        'EARLY_WHORL': 'Moderate',
        'LATE_WHORL': 'Moderate',
        'TASSELING_SILKING': 'Moderate',
        'GRAIN_FILLING': 'Low',
        'MATURITY': 'Very Low',
      },
      'larva': {
        'SEEDLING': 'Moderate',
        'EARLY_WHORL': 'Moderate',
        'LATE_WHORL': 'High',
        'TASSELING_SILKING': 'Very High',
        'GRAIN_FILLING': 'High',
        'MATURITY': 'Low',
      },
      'pupa': {
        'SEEDLING': 'Very Low',
        'EARLY_WHORL': 'Very Low',
        'LATE_WHORL': 'Low',
        'TASSELING_SILKING': 'Low',
        'GRAIN_FILLING': 'Low',
        'MATURITY': 'Low',
      },
      'moth': {
        'SEEDLING': 'Low',
        'EARLY_WHORL': 'Moderate',
        'LATE_WHORL': 'High',
        'TASSELING_SILKING': 'Moderate',
        'GRAIN_FILLING': 'Low',
        'MATURITY': 'Low',
      },
      'none': {
        'SEEDLING': 'Very Low',
        'EARLY_WHORL': 'Very Low',
        'LATE_WHORL': 'Very Low',
        'TASSELING_SILKING': 'Very Low',
        'GRAIN_FILLING': 'Very Low',
        'MATURITY': 'Very Low',
      },
    };
    
    return riskMatrix[lifeStageKey]?[growthStageKey] ?? 'Low';
  }

  /// Get risk level color based on 5 levels
  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Very High': return const Color(0xFFB71C1C); // Dark Red
      case 'High': return const Color(0xFFD32F2F); // Red
      case 'Moderate': return const Color(0xFFF57C00); // Orange
      case 'Low': return const Color(0xFFF9A825); // Yellow
      case 'Very Low': return const Color(0xFF2E7D32); // Green
      default: return const Color(0xFF2E7D32);
    }
  }

  /// Get risk level icon based on 5 levels
  IconData _getRiskIcon(String riskLevel) {
    switch (riskLevel) {
      case 'Very High': return Icons.crisis_alert_rounded;
      case 'High': return Icons.warning_amber_rounded;
      case 'Moderate': return Icons.info_outline_rounded;
      case 'Low': return Icons.check_circle_outline_rounded;
      case 'Very Low': return Icons.check_circle_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }

  /// Get risk level display text (ensuring proper casing)
  String _getRiskLevelDisplay(String riskLevel) {
    // Ensure proper capitalization
    final lower = riskLevel.toLowerCase();
    if (lower == 'very high') return 'Very High';
    if (lower == 'high') return 'High';
    if (lower == 'moderate') return 'Moderate';
    if (lower == 'low') return 'Low';
    if (lower == 'very low') return 'Very Low';
    return riskLevel;
  }

  // ── Severity helpers (updated for 5 levels) ────────────────────────────
  String get _riskLevel {
    // If we have DAP from assigned cycle, calculate properly
    if (_assignedDap != null) {
      return _calculateRiskLevel(
        lifeStage: widget.detectionStage,
        dap: _assignedDap!,
      );
    }
    // Fallback: use the severity from AI
    final s = widget.severity.toUpperCase();
    if (s.contains('CRITICAL') || s.contains('VERY HIGH')) return 'Very High';
    if (s.contains('HIGH')) return 'High';
    if (s.contains('MODERATE') || s.contains('MEDIUM')) return 'Moderate';
    if (s.contains('LOW')) return 'Low';
    if (s.contains('VERY LOW')) return 'Very Low';
    return 'Moderate';
  }

  Color get _severityColor => _getRiskColor(_riskLevel);
  IconData get _severityIcon => _getRiskIcon(_riskLevel);

  // ── Save to Firestore ─────────────────────────────────────────────────────
  Future<void> _saveToReports(BuildContext context) async {
    if (_assignedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please assign this detection to a farming cycle before saving.',
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
      return;
    }

    try {
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
      if (widget.imageFile != null) {
        final bytes = await widget.imageFile!.readAsBytes();
        final base64String = base64Encode(bytes);
        base64Image = 'data:image/jpeg;base64,$base64String';
      }

      // Get the calculated risk level
      final riskLevel = _riskLevel;
      final riskDisplay = _getRiskLevelDisplay(riskLevel);

      final reportData = {
        'detection': widget.pestName,
        'scientificName': widget.scientificName,
        'lifeStage': widget.detectionStage.toLowerCase(),
        'confidence': widget.confidencePercent / 100,
        'risk': riskDisplay,
        'cropAffected': widget.cropAffected,
        'analysis': widget.analysis,
        'treatment': widget.treatment,
        'historicalContext': widget.historicalContext,
        'imageBase64': base64Image,
        'annotatedImageUrl': widget.annotatedImageUrl,
        'farmerId': widget.userId,
        'farmerName': await _getFarmerName(),
        'cycleId': _assignedCycleId,
        'dap': _assignedDap,
        'growthStage': _assignedGrowthStage,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'location': {
          'lat': widget.latitude ?? 0.0,
          'lng': widget.longitude ?? 0.0,
          'areaName': widget.areaName ?? 'Unknown Area',
        },
      };

      final docRef = await FirebaseFirestore.instance
          .collection('reports')
          .add(reportData);

      Navigator.pop(context);

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
      if (context.mounted) Navigator.pop(context);
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

  Future<String> _getFarmerName() async {
    final cachedName = AuthCacheService().cachedName;
    if (cachedName != null && cachedName.isNotEmpty) {
      return cachedName;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.userId)
          .safeGet();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['name'] ?? data?['fullName'] ?? 'Unknown Farmer';
      }
      return 'Unknown Farmer';
    } catch (e) {
      return 'Unknown Farmer';
    }
  }

  // ── Tab Labels ──────────────────────────────────────────────────────────
  List<Tab> get _tabs => const [
    Tab(text: 'Overview', icon: Icon(Icons.info_outline_rounded, size: 18)),
    Tab(text: 'Analysis', icon: Icon(Icons.analytics_rounded, size: 18)),
    Tab(text: 'Treatment', icon: Icon(Icons.healing_rounded, size: 18)),
    Tab(text: 'Risk', icon: Icon(Icons.warning_rounded, size: 18)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Custom App Bar ──────────────────────────────────────────────────
          _buildAppBar(context),
          // ── Hero Image ─────────────────────────────────────────────────────
          _buildHeroImage(),
          // ── Quick Info Row ────────────────────────────────────────────────
          _buildQuickInfoRow(),
          // ── Tab Bar ──────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              tabs: _tabs,
              labelColor: _green,
              unselectedLabelColor: _muted,
              indicatorColor: _accentGreen,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          // ── Tab Content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAnalysisTab(),
                _buildTreatmentTab(),
                _buildRiskTab(),
              ],
            ),
          ),
          // ── Action Buttons ──────────────────────────────────────────────
          _buildActionButtons(context),
        ],
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      decoration: const BoxDecoration(
        color: _darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Diagnostics',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  widget.pestName,
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _saveToReports(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _accentGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.save_rounded, color: _darkGreen, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Save',
                    style: GoogleFonts.manrope(
                      color: _darkGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Image ──────────────────────────────────────────────────────────
  Widget _buildHeroImage() {
    return Container(
      height: 160,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.annotatedImageUrl != null)
              Image.network(
                widget.annotatedImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _imageFallback(),
              )
            else if (widget.imageFile != null)
              Image.file(widget.imageFile!, fit: BoxFit.cover)
            else
              _imageFallback(),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
            ),
            // Confidence badge
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentGreen.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: _accentGreen, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.confidencePercent}% match',
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Risk Level badge (updated for 5 levels)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _severityColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_severityIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _riskLevel.toUpperCase(),
                      style: GoogleFonts.manrope(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  Widget _imageFallback() {
    return Container(
      color: _darkGreen,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white30, size: 48),
      ),
    );
  }

  // ── Quick Info Row ──────────────────────────────────────────────────────
  Widget _buildQuickInfoRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _quickInfoItem(
            icon: Icons.biotech_rounded,
            label: 'Life Stage',
            value: widget.detectionStage,
          ),
          Container(width: 1, height: 30, color: _border),
          _quickInfoItem(
            icon: Icons.grass_rounded,
            label: 'Crop',
            value: widget.cropAffected,
          ),
          Container(width: 1, height: 30, color: _border),
          _quickInfoItem(
            icon: Icons.science_rounded,
            label: 'Scientific',
            value: widget.scientificName.split(' ').last,
          ),
        ],
      ),
    );
  }

  Widget _quickInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _muted, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _darkGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Overview Tab ────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
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
                  widget.pestName,
                  style: GoogleFonts.manrope(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _darkGreen,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.scientificName,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _overviewInfoCell(
                        icon: Icons.biotech_rounded,
                        label: 'Life Stage',
                        value: widget.detectionStage,
                      ),
                    ),
                    Expanded(
                      child: _overviewInfoCell(
                        icon: Icons.grass_rounded,
                        label: 'Crop Affected',
                        value: widget.cropAffected,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _overviewInfoCell(
                        icon: Icons.verified_rounded,
                        label: 'Confidence',
                        value: '${widget.confidencePercent}%',
                      ),
                    ),
                    Expanded(
                      child: _overviewInfoCell(
                        icon: Icons.warning_amber_rounded,
                        label: 'Risk Level',
                        value: _riskLevel,
                        valueColor: _severityColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // DAP and Growth Stage info if available
                if (_assignedDap != null) ...[
                  _overviewInfoCell(
                    icon: Icons.calendar_today_rounded,
                    label: 'Days After Planting (DAP)',
                    value: '${_assignedDap} days',
                    fullWidth: true,
                  ),
                  const SizedBox(height: 6),
                  _overviewInfoCell(
                    icon: Icons.grass_rounded,
                    label: 'Growth Stage',
                    value: _getGrowthStageDisplay(_assignedDap!),
                    fullWidth: true,
                  ),
                  const SizedBox(height: 6),
                ],
                // Location info
                if (widget.areaName != null)
                  _overviewInfoCell(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: widget.areaName!,
                    fullWidth: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUMMARY',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getSummaryText(),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: _bodyText,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSummaryText() {
    final riskLevel = _riskLevel;
    final stage = widget.detectionStage.toLowerCase();
    final isLarva = stage.contains('larva');
    final isMoth = stage.contains('moth');
    final isEgg = stage.contains('egg');
    final isPupa = stage.contains('pupa');
    
    switch (riskLevel) {
      case 'Very High':
        if (isLarva) {
          return '🚨 CRITICAL: Larvae detected at the most vulnerable crop stage (Tasseling-Silking). Immediate action required to prevent severe yield loss.';
        } else if (isMoth) {
          return '🚨 EXTREME: High moth population at critical crop stage. Immediate monitoring and control measures required.';
        }
        return '🚨 CRITICAL: Immediate action required to protect crop yield.';
      
      case 'High':
        if (isLarva) {
          return '⚠️ HIGH RISK: Larvae present at vulnerable crop stage. Urgent action needed within 24-48 hours.';
        } else if (isMoth) {
          return '⚠️ HIGH RISK: Moths detected at vulnerable crop stage. High spread potential requiring immediate monitoring.';
        }
        return '⚠️ HIGH RISK: Prompt action recommended to prevent yield loss.';
      
      case 'Moderate':
        if (isLarva) {
          return '⚠️ MODERATE RISK: Larvae present but crop can recover with prompt treatment. Monitor every 3-4 days.';
        } else if (isEgg) {
          return '⚠️ MODERATE RISK: Egg masses detected. They will hatch into larvae within days - prepare for action.';
        }
        return '⚠️ MODERATE RISK: Monitor closely and treat within 48-72 hours if population increases.';
      
      case 'Low':
        if (isLarva) {
          return '✅ LOW RISK: Low larvae population. Continue regular monitoring. Treatment may not be necessary.';
        } else if (isPupa) {
          return '✅ LOW RISK: Pupae detected. Monitor for adult emergence but no immediate action needed.';
        }
        return '✅ LOW RISK: Continue regular monitoring. No immediate treatment needed.';
      
      case 'Very Low':
        return '✅ VERY LOW RISK: No significant pest activity. Continue routine monitoring.';
      
      default:
        return 'Continue regular monitoring.';
    }
  }

  Widget _overviewInfoCell({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: _accentGreen, size: 14),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: _muted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? _darkGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Analysis Tab ────────────────────────────────────────────────────────
  Widget _buildAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_rounded,
                      color: _green, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'Detailed Analysis',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _darkGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: widget.analysis,
              styleSheet: _markdownStyleSheet(isDark: false),
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Treatment Tab ──────────────────────────────────────────────────────
  Widget _buildTreatmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _darkGreen,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentGreen.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _accentGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    _riskLevel.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _accentGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: widget.treatment,
              styleSheet: _markdownStyleSheet(isDark: true),
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Risk Tab ─────────────────────────────────────────────────────────────
  Widget _buildRiskTab() {
    final stage = widget.detectionStage.toLowerCase();
    final riskLevel = _riskLevel;
    final isLarva = stage.contains('larva');
    final isMoth = stage.contains('moth');
    final isEgg = stage.contains('egg');
    final isPupa = stage.contains('pupa');
    
    // Determine life stage details
    String lifeStageName;
    IconData lifeStageIcon;
    String lifeStageDescription;
    String riskType;
    Color riskColor = _severityColor;
    IconData riskIcon = _severityIcon;
    
    if (isMoth) {
      lifeStageName = 'Moth (Adult)';
      lifeStageIcon = Icons.flight_takeoff_rounded;
      lifeStageDescription = 'Adult moths are the reproductive and dispersal stage. They don\'t directly damage crops but lay eggs that become destructive larvae.';
      riskType = 'Spread Risk';
    } else if (isLarva) {
      lifeStageName = 'Larva (Caterpillar)';
      lifeStageIcon = Icons.bug_report_rounded;
      lifeStageDescription = 'Larvae cause DIRECT crop damage by feeding on leaves, stems, and reproductive structures. This is the most destructive stage.';
      riskType = 'Infestation/Destruction Risk';
    } else if (isEgg) {
      lifeStageName = 'Egg Mass';
      lifeStageIcon = Icons.circle_outlined;
      lifeStageDescription = 'Egg masses indicate active reproduction. While eggs don\'t damage crops, they will hatch into larvae that will begin feeding within 2-5 days.';
      riskType = 'Emerging Infestation Risk';
    } else if (isPupa) {
      lifeStageName = 'Pupa';
      lifeStageIcon = Icons.settings_overscan_rounded;
      lifeStageDescription = 'Pupae are the transitional stage before adults emerge. They are usually found in soil or debris and indicate a new generation is developing.';
      riskType = 'Future Generation Risk';
    } else {
      lifeStageName = 'Unknown';
      lifeStageIcon = Icons.help_outline_rounded;
      lifeStageDescription = 'The detected stage could not be clearly identified.';
      riskType = 'Unknown';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Risk Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: riskColor.withOpacity(0.2), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(riskIcon, color: riskColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(lifeStageIcon, color: riskColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                lifeStageName,
                                style: GoogleFonts.manrope(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _darkGreen,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            riskType,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: riskColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: riskColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: riskColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        riskLevel.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: riskColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Risk Details
          _buildRiskDetailCard(
            icon: Icons.info_outline_rounded,
            color: _muted,
            title: 'What does this mean?',
            content: lifeStageDescription,
          ),
          const SizedBox(height: 12),
          _buildRiskDetailCard(
            icon: Icons.eco_rounded,
            color: _green,
            title: 'Crop Vulnerability',
            content: _getCropVulnerabilityText(),
          ),
          const SizedBox(height: 12),
          _buildRiskDetailCard(
            icon: Icons.analytics_rounded,
            color: riskColor,
            title: 'Risk Assessment',
            content: _getRiskAssessmentText(),
          ),
          const SizedBox(height: 12),
          // Action Recommendation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: riskColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.priority_high_rounded,
                    color: riskColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RECOMMENDED ACTION',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: riskColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getActionRecommendation(),
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _darkGreen,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Risk Level Indicator with 5 levels
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.gpp_maybe_rounded, color: riskColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Risk Level: ${riskLevel.toUpperCase()}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 5-level risk indicator
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: Colors.grey.shade200,
                        ),
                        child: Row(
                          children: [
                            // Very Low (0-20%)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(3),
                                    bottomLeft: Radius.circular(3),
                                  ),
                                  color: const Color(0xFF2E7D32).withOpacity(
                                    riskLevel == 'Very Low' ? 1.0 : 0.3,
                                  ),
                                ),
                              ),
                            ),
                            // Low (20-40%)
                            Expanded(
                              child: Container(
                                color: const Color(0xFFF9A825).withOpacity(
                                  riskLevel == 'Low' ? 1.0 : 0.3,
                                ),
                              ),
                            ),
                            // Moderate (40-60%)
                            Expanded(
                              child: Container(
                                color: const Color(0xFFF57C00).withOpacity(
                                  riskLevel == 'Moderate' ? 1.0 : 0.3,
                                ),
                              ),
                            ),
                            // High (60-80%)
                            Expanded(
                              child: Container(
                                color: const Color(0xFFD32F2F).withOpacity(
                                  riskLevel == 'High' ? 1.0 : 0.3,
                                ),
                              ),
                            ),
                            // Very High (80-100%)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(3),
                                    bottomRight: Radius.circular(3),
                                  ),
                                  color: const Color(0xFFB71C1C).withOpacity(
                                    riskLevel == 'Very High' ? 1.0 : 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Very Low', style: GoogleFonts.manrope(fontSize: 7, color: Colors.grey.shade500)),
                    Text('Low', style: GoogleFonts.manrope(fontSize: 7, color: Colors.grey.shade500)),
                    Text('Moderate', style: GoogleFonts.manrope(fontSize: 7, color: Colors.grey.shade500)),
                    Text('High', style: GoogleFonts.manrope(fontSize: 7, color: Colors.grey.shade500)),
                    Text('Very High', style: GoogleFonts.manrope(fontSize: 7, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  riskType,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskDetailCard({
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _darkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: _bodyText,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCropVulnerabilityText() {
    final riskLevel = _riskLevel;
    
    switch (riskLevel) {
      case 'Very High':
        return 'CRITICAL: The crop is at Tasseling-Silking stage (45-55 DAP). This is when yield is most at risk. Even small pest populations can cause significant economic damage. IMMEDIATE ACTION REQUIRED.';
      
      case 'High':
        return 'HIGH VULNERABILITY: The crop is at Late Whorl (30-45 DAP) or Grain Filling (55-75 DAP) stage. Damage at these stages can significantly reduce yield.';
      
      case 'Moderate':
        return 'MODERATE VULNERABILITY: The crop is in early vegetative stage where it can recover from some damage. However, pest populations can quickly increase if not addressed.';
      
      case 'Low':
        return 'LOW VULNERABILITY: The crop is either in seedling stage (can recover) or early growth stage. Pest impact is limited.';
      
      case 'Very Low':
        return 'VERY LOW VULNERABILITY: No significant pest pressure. Continue routine monitoring.';
      
      default:
        return 'Crop vulnerability is moderate. Continue monitoring.';
    }
  }

  String _getRiskAssessmentText() {
    final stage = widget.detectionStage.toLowerCase();
    final riskLevel = _riskLevel;
    final isLarva = stage.contains('larva');
    final isMoth = stage.contains('moth');
    final isEgg = stage.contains('egg');
    final isPupa = stage.contains('pupa');

    // Use dap in the assessment text
    final growthStageDisplay = _getGrowthStageDisplay(_assignedDap ?? 0);

    if (isMoth) {
      if (riskLevel == 'Very High' || riskLevel == 'High') {
        return 'SPREAD RISK: High moth population at critical crop stage ($growthStageDisplay). Immediate action needed to prevent widespread infestation.';
      }
      return 'SPREAD RISK: Moths detected. Monitor for egg laying and prepare for larval emergence.';
    } else if (isLarva) {
      switch (riskLevel) {
        case 'Very High':
          return 'CRITICAL: Larvae at maximum vulnerability stage ($growthStageDisplay). Damage directly affects yield. Immediate chemical control recommended.';
        case 'High':
          return 'HIGH RISK: Significant larvae population at vulnerable stage. Urgent action needed within 24-48 hours.';
        case 'Moderate':
          return 'MODERATE RISK: Larvae present at $growthStageDisplay. Monitor daily and treat if population increases.';
        case 'Low':
          return 'LOW RISK: Low larvae population at $growthStageDisplay. Continue regular monitoring.';
        default:
          return 'Larvae detected. Assess damage level and crop stage to determine action.';
      }
    } else if (isEgg) {
      if (riskLevel == 'Moderate' || riskLevel == 'High') {
        return 'TIMELY WARNING: Egg masses detected at $growthStageDisplay. They will hatch within 2-5 days. This is the best time to apply preventive measures.';
      }
      return 'EGG MASSES DETECTED: Monitor for hatching. Prepare for larval management.';
    } else if (isPupa) {
      return 'FUTURE GENERATION WARNING: Pupae detected at $growthStageDisplay. A new generation of moths will emerge soon. This will increase spread risk in the coming weeks. Consider soil treatment.';
    } else {
      return 'DETECTION UNCLEAR: The pest stage could not be identified with certainty. Manual verification is recommended.';
    }
  }

  String _getActionRecommendation() {
    final stage = widget.detectionStage.toLowerCase();
    final riskLevel = _riskLevel;
    final isLarva = stage.contains('larva');
    final isMoth = stage.contains('moth');
    final isEgg = stage.contains('egg');
    final isPupa = stage.contains('pupa');

    switch (riskLevel) {
      case 'Very High':
        if (isLarva) {
          return 'URGENT: Apply insecticide immediately. Focus on ear zone and actively growing tissues. Do not wait. Re-scout within 3-5 days.';
        } else if (isMoth) {
          return 'URGENT: Deploy pheromone traps immediately. Consider perimeter spraying. Monitor daily for egg masses.';
        }
        return 'URGENT: Immediate action required. Contact agricultural extension officer.';
      
      case 'High':
        if (isLarva) {
          return 'TREAT WITHIN 24 HOURS: Apply recommended insecticide. Focus on affected areas. Monitor daily for spread.';
        } else if (isMoth) {
          return 'IMMEDIATE: Install pheromone traps to monitor and reduce moth population. Consider perimeter treatments to prevent spread.';
        } else if (isEgg) {
          return 'REMOVE/MONITOR: Remove visible egg masses manually. Apply biological control (Trichogramma wasps). Prepare for larval emergence.';
        }
        return 'IMMEDIATE ACTION: Implement control measures within 24 hours.';
      
      case 'Moderate':
        if (isLarva) {
          return 'TREAT WITHIN 48 HOURS: Apply recommended control to prevent population explosion. Monitor daily for signs of increasing damage.';
        } else if (isEgg) {
          return 'PREPARE: Apply biological control. Monitor for hatching. Prepare for larval management in 2-5 days.';
        } else if (isPupa) {
          return 'PREPARE: Strengthen biological control. Consider soil treatments. Prepare monitoring for emerging adults.';
        }
        return 'MONITOR CLOSELY: Scout every 3-4 days. Take action if population increases.';
      
      case 'Low':
        if (isLarva) {
          return 'CONTINUE SCOUTING: Monitor weekly. Treatment only needed if populations increase or crop enters a more vulnerable stage.';
        } else if (isPupa) {
          return 'CONTINUE MONITORING: Pupae indicate a new generation will emerge. Maintain regular scouting.';
        }
        return 'CONTINUE ROUTINE MONITORING: Weekly scouting is sufficient at this risk level.';
      
      case 'Very Low':
        return 'CONTINUE ROUTINE MONITORING: No action needed. Maintain regular scouting schedule.';
      
      default:
        return 'VERIFY: Conduct field scouting to confirm pest presence and stage. Assess damage level and crop status.';
    }
  }

  // ── Action Buttons ──────────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            color: _green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Retake',
                          style: GoogleFonts.manrope(
                            color: _green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () async {
                    final returnedData = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignPestScreen(
                          userId: widget.userId,
                          pestName: widget.pestName,
                          detectedStage: widget.detectionStage.toLowerCase(),
                          imagePath: widget.imageFile?.path,
                        ),
                      ),
                    );

                    if (returnedData != null && returnedData['cycleId'] != null) {
                      setState(() { 
                        _assignedCycleId = returnedData['cycleId'];
                        _assignedDap = returnedData['dap'];
                        _assignedGrowthStage = returnedData['growthStage'];
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [
                              const Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Cycle assigned! DAP: $_assignedDap days, Stage: $_assignedGrowthStage',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ]),
                            backgroundColor: _green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _assignedCycleId != null ? _green : _green.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_task_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _assignedCycleId != null
                              ? 'Cycle Assigned ✓'
                              : 'Assign to Cycle',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Save Report Button
          GestureDetector(
            onTap: _assignedCycleId == null
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Please assign this detection to a farming cycle first.',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.orange.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                : () => _saveToReports(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _assignedCycleId != null
                    ? const Color(0xFFEAF5EE)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _assignedCycleId != null
                      ? _accentGreen
                      : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: _assignedCycleId != null
                        ? _green
                        : Colors.grey.shade400,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _assignedCycleId != null
                        ? 'Save Report to Monitoring'
                        : 'Assign a Cycle to Save Report',
                    style: GoogleFonts.manrope(
                      color: _assignedCycleId != null
                          ? _green
                          : Colors.grey.shade400,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
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

  MarkdownStyleSheet _markdownStyleSheet({required bool isDark}) {
    final baseTextStyle = GoogleFonts.manrope(fontSize: 13, height: 1.65);
    final bodyColor = isDark ? Colors.white.withOpacity(0.7) : _bodyText;
    final headingColor = isDark ? Colors.white : _darkGreen;

    return MarkdownStyleSheet(
      p: baseTextStyle.copyWith(color: bodyColor),
      h1: GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: headingColor,
        height: 1.3,
      ),
      h2: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: headingColor,
        height: 1.3,
      ),
      h3: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: headingColor,
        height: 1.35,
      ),
      h4: GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: headingColor,
        height: 1.4,
      ),
      strong: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: isDark ? _accentGreen : _green,
      ),
      em: GoogleFonts.manrope(
        fontSize: 13,
        fontStyle: FontStyle.italic,
        color: bodyColor,
      ),
      listBullet: baseTextStyle.copyWith(color: bodyColor),
      blockquote: baseTextStyle.copyWith(
        color: isDark ? Colors.white70 : const Color(0xFF6B4F12),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? _accentGreen : const Color(0xFFF59E0B),
            width: 4,
          ),
        ),
        color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFFFFBF0),
      ),
      code: GoogleFonts.manrope(
        fontSize: 12,
        color: Colors.blue.shade300,
        backgroundColor: Colors.black12,
      ),
    );
  }
}