import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/widgets/database_image.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;
  final String? reportType; // 'regular' or 'clustered'

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.reportData,
    this.reportType,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isResolving = false;
  late Map<String, dynamic> _currentData;

  // Design tokens
  static const _forestGreen = Color(0xFF1B3015);
  static const _gold = Color(0xFFC8A84B);
  static const _cream = Color(0xFFF8F5EF);
  static const _darkGreen = Color(0xFF0D4D33);

  bool get _isClustered {
    final type = widget.reportType ?? _currentData['reportType'];
    if (type == 'clustered') return true;
    if (type == 'regular') return false;
    return _currentData.containsKey('stationsData') ||
        _currentData.containsKey('totals') ||
        _currentData.containsKey('damageAssessment') ||
        _currentData.containsKey('growthStage');
  }

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.reportData);
  }

  @override
  Widget build(BuildContext context) {
    final collectionName = _isClustered ? 'clustered_reports' : 'reports';

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection(collectionName).doc(widget.reportId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final liveData = snapshot.data!.data() as Map<String, dynamic>?;
          if (liveData != null) {
            _currentData = {
              ..._currentData,
              ...liveData,
            };
          }
        }

        return _isClustered ? _buildClusteredView() : _buildRegularView();
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLUSTERED SCOUTING REPORT VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildClusteredView() {
    final data = _currentData;
    final status = (data['status'] ?? 'pending').toString();
    final growthStage = (data['growthStage'] ?? 'Corn Growth Stage').toString();
    final dap = data['dap'] != null ? 'DAP ${data['dap']}' : 'DAP N/A';
    final farmName = (data['farmName'] ?? 'Farm').toString();
    final fieldName = (data['fieldName'] ?? 'Field').toString();
    final timestamp = data['reportDate'] ?? data['timestamp'] ?? data['createdAt'];

    final totalInspected = data['totalInspected'] is num ? (data['totalInspected'] as num).toInt() : 100;
    final totalDamaged = data['totalDamaged'] is num ? (data['totalDamaged'] as num).toInt() : 0;
    final damagePercentage = data['damagePercentage'] is num
        ? (data['damagePercentage'] as num).toDouble()
        : (totalInspected > 0 ? (totalDamaged / totalInspected) * 100 : 0.0);
    final exceedsThreshold = data['exceedsThreshold'] == true || damagePercentage >= 10.0;

    final totals = (data['totals'] as Map<String, dynamic>?) ?? {};
    final eggs = totals['eggs'] is num ? (totals['eggs'] as num).toInt() : 0;
    final larvae = totals['larvae'] is num ? (totals['larvae'] as num).toInt() : 0;
    final pupae = totals['pupae'] is num ? (totals['pupae'] as num).toInt() : 0;
    final moths = totals['moths'] is num ? (totals['moths'] as num).toInt() : 0;

    final risk = (data['riskLevel'] ?? data['severityLevel'] ?? (exceedsThreshold ? 'High' : 'Moderate')).toString();
    final isResolved = status.toLowerCase() == 'resolved';
    final isRejected = status.toLowerCase() == 'rejected';
    final isValidated = status.toLowerCase() == 'validated';
    final statusColor = _statusColor(status);

    // Collect all images from capturedImages map
    final List<String> galleryImages = _extractAllImages(data);

    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          // ─── Sliver App Bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: galleryImages.isNotEmpty ? 280 : 200,
            pinned: true,
            backgroundColor: _forestGreen,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (!isResolved && !isRejected)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _isResolving
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _showResolveConfirmation,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                          label: Text(
                            'Resolve',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image Gallery or Forest Background
                  if (galleryImages.isNotEmpty)
                    _buildGalleryHeader(galleryImages)
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_forestGreen, Color(0xFF2D5523)],
                        ),
                      ),
                    ),
                  // Dark bottom gradient for text contrast
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.3, 1.0],
                        colors: [Colors.transparent, Color(0xDD1B3015)],
                      ),
                    ),
                  ),
                  // Bottom title & pills overlay
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: status, color: statusColor),
                            const SizedBox(width: 8),
                            _StatusChip(
                              status: '${risk.toUpperCase()} RISK',
                              color: _riskColor(risk),
                              icon: Icons.warning_amber_rounded,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                dap,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'FAW Clustered Scouting Report',
                          style: GoogleFonts.epilogue(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$growthStage · $farmName · $fieldName',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Body Content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status Banner
                  _StatusBanner(
                    status: status,
                    color: statusColor,
                    validatedAt: data['validatedAt'],
                    validatedBy: data['validatedBy'],
                    rejectionReason: data['rejectionReason'] ?? data['validationNotes'],
                    resolutionExplanation: data['resolutionExplanation'],
                    expertDiagnosis: data['expertDiagnosis'],
                    advisoryMessage: data['advisoryMessage'],
                  ),

                  const SizedBox(height: 16),

                  // 2. Key Metrics Grid
                  _buildScoutingMetricsGrid(
                    growthStage: growthStage,
                    dap: dap,
                    totalInspected: totalInspected,
                    totalDamaged: totalDamaged,
                    damagePercentage: damagePercentage,
                    exceedsThreshold: exceedsThreshold,
                    risk: risk,
                  ),

                  const SizedBox(height: 16),

                  // 3. Pest Stage Counts (Eggs, Larvae, Pupae, Moths)
                  _buildPestStageBreakdown(eggs: eggs, larvae: larvae, pupae: pupae, moths: moths, data: data),

                  const SizedBox(height: 16),

                  // 4. RCPC Expert Validation Details (if available)
                  if (isValidated || data['advisoryMessage'] != null || data['validationNotes'] != null)
                    _buildRcpcValidationCard(data),

                  const SizedBox(height: 16),

                  // 5. Stations Inspection Breakdown (Accordion)
                  _buildStationsBreakdown(data['stationsData']),

                  const SizedBox(height: 16),

                  // 6. Field & Cycle Context Card
                  _buildContextCard(data, timestamp),

                  const SizedBox(height: 20),

                  // 7. Resolve CTA (if unresolved)
                  if (!isResolved && !isRejected)
                    _ResolveCTA(
                      isResolving: _isResolving,
                      onNotYet: () => Navigator.pop(context),
                      onResolve: _showResolveConfirmation,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REGULAR AI SCAN REPORT VIEW
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildRegularView() {
    final data = _currentData;
    final detection = (data['detection'] ?? data['originalDetection'] ?? 'Unknown Pest').toString();
    final scientificName = (data['scientificName'] ?? '').toString();
    final risk = (data['risk'] ?? 'Unknown').toString();
    final status = (data['status'] ?? 'pending').toString();
    final confidence = (data['confidence'] ?? 0.0) as num;
    final lifeStage = (data['lifeStage'] ?? data['originalLifeStage'] ?? 'Unknown').toString();
    final cropAffected = (data['cropAffected'] ?? 'Corn').toString();
    final analysis = (data['analysis'] ?? '').toString();
    final treatment = (data['treatment'] ?? '').toString();
    final historicalContext = (data['historicalContext'] ?? '').toString();
    final imageBase64 = data['imageBase64'] as String?;
    final annotatedImageUrl = (data['annotatedImageUrl'] ?? data['annotated_url']) as String?;
    final timestamp = data['timestamp'] ?? data['createdAt'];
    final farmName = (data['farmName'] ?? 'Unknown Farm').toString();
    final fieldName = (data['fieldName'] ?? data['areaName'] ?? 'Unknown Field').toString();
    final location = data['location'] as Map<String, dynamic>?;

    final isResolved = status.toLowerCase() == 'resolved';
    final isRejected = status.toLowerCase() == 'rejected';
    final isValidated = status.toLowerCase() == 'validated';
    final statusColor = _statusColor(status);

    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          // ─── Sliver App Bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: _forestGreen,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (!isResolved && !isRejected)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _isResolving
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                      : TextButton.icon(
                          onPressed: _showResolveConfirmation,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                          label: Text(
                            'Resolve',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroImage(imageBase64, annotatedImageUrl),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.35, 1.0],
                        colors: [Colors.transparent, Color(0xDD1B3015)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: status, color: statusColor),
                            const SizedBox(width: 8),
                            _StatusChip(
                              status: risk.toUpperCase(),
                              color: _riskColor(risk),
                              icon: Icons.warning_amber_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detection,
                          style: GoogleFonts.epilogue(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        if (scientificName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            scientificName,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Body Content ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Status Banner
                  _StatusBanner(
                    status: status,
                    color: statusColor,
                    validatedAt: data['validatedAt'],
                    validatedBy: data['validatedBy'],
                    rejectionReason: data['rejectionReason'] ?? data['validationNotes'],
                    resolutionExplanation: data['resolutionExplanation'],
                    expertDiagnosis: data['expertDiagnosis'],
                    advisoryMessage: data['advisoryMessage'],
                  ),

                  const SizedBox(height: 16),

                  // 2. RCPC Official Verification Box (if validated or has officer notes)
                  if (isValidated || data['advisoryMessage'] != null || data['validationNotes'] != null)
                    _buildRcpcValidationCard(data),

                  if (isValidated || data['advisoryMessage'] != null || data['validationNotes'] != null)
                    const SizedBox(height: 16),

                  // 3. Quick stats row
                  _QuickStatsRow(
                    confidence: confidence.toDouble(),
                    lifeStage: data['correctedLifeStage'] ?? lifeStage,
                    cropAffected: cropAffected,
                    timestamp: timestamp,
                  ),

                  const SizedBox(height: 16),

                  // 4. Location card
                  _InfoCard(
                    icon: Icons.pin_drop_rounded,
                    title: 'Location & Farm',
                    accentColor: _gold,
                    children: [
                      _Row('Farm', farmName),
                      _Row('Field', fieldName),
                      if (location?['areaName'] != null)
                        _Row('Area', location!['areaName']),
                      if (location?['lat'] != null && location?['lng'] != null)
                        _Row(
                          'Coordinates',
                          '${location!['lat']?.toStringAsFixed(5)}, ${location['lng']?.toStringAsFixed(5)}',
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 5. AI Analysis
                  if (analysis.isNotEmpty) ...[
                    _ExpandableCard(
                      icon: Icons.analytics_outlined,
                      title: 'AI Analysis',
                      accentColor: Colors.blue,
                      child: MarkdownBody(
                        data: analysis,
                        styleSheet: _mdStyle(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 6. Treatment Plan
                  if (treatment.isNotEmpty) ...[
                    _ExpandableCard(
                      icon: Icons.healing_outlined,
                      title: 'Treatment & Management',
                      accentColor: Colors.green,
                      initiallyExpanded: true,
                      child: MarkdownBody(
                        data: treatment,
                        styleSheet: _mdStyle(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 7. Historical Context
                  if (historicalContext.isNotEmpty) ...[
                    _ExpandableCard(
                      icon: Icons.history_rounded,
                      title: 'Historical Context',
                      accentColor: _gold,
                      child: Text(
                        historicalContext,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.65,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 8. Resolve CTA
                  if (!isResolved && !isRejected) ...[
                    const SizedBox(height: 8),
                    _ResolveCTA(
                      isResolving: _isResolving,
                      onNotYet: () => Navigator.pop(context),
                      onResolve: _showResolveConfirmation,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER WIDGETS FOR CLUSTERED SCOUTING
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildGalleryHeader(List<String> images) {
    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (context, index) {
        final img = images[index];
        return GestureDetector(
          onTap: () => _openFullscreenImage(img),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DatabaseImage(source: img, fit: BoxFit.cover),
              Positioned(
                top: 50,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Photo ${index + 1}/${images.length}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScoutingMetricsGrid({
    required String growthStage,
    required String dap,
    required int totalInspected,
    required int totalDamaged,
    required double damagePercentage,
    required bool exceedsThreshold,
    required String risk,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Growth Stage',
                value: growthStage,
                subtext: dap,
                icon: Icons.eco_rounded,
                accentColor: _darkGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Damage Rate',
                value: '${damagePercentage.toStringAsFixed(1)}%',
                subtext: '$totalDamaged of $totalInspected plants',
                icon: Icons.coronavirus_outlined,
                accentColor: exceedsThreshold ? Colors.red : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Economic Threshold',
                value: exceedsThreshold ? 'EXCEEDED' : 'NORMAL',
                subtext: exceedsThreshold ? 'Action threshold ≥ 10%' : 'Below threshold',
                icon: exceedsThreshold ? Icons.warning_rounded : Icons.check_circle_rounded,
                accentColor: exceedsThreshold ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'Severity Assessment',
                value: risk.toUpperCase(),
                subtext: 'Scouting Level Risk',
                icon: Icons.shield_outlined,
                accentColor: _riskColor(risk),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPestStageBreakdown({
    required int eggs,
    required int larvae,
    required int pupae,
    required int moths,
    required Map<String, dynamic> data,
  }) {
    final larvaRisk = (data['larvaRisk'] as Map<String, dynamic>?)?['riskLevel']?.toString() ?? (larvae > 0 ? 'High' : 'None');
    final mothRisk = (data['mothRisk'] as Map<String, dynamic>?)?['riskLevel']?.toString() ?? (moths > 0 ? 'High' : 'None');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
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
                  color: _forestGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bug_report_rounded, color: _forestGreen, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pest Life-Stage Inventory',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _forestGreen,
                      ),
                    ),
                    Text(
                      'Summary of observed FAW developmental stages',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PestStageCard(
                  emoji: '🐛',
                  stage: 'Larvae',
                  count: larvae,
                  riskLabel: 'Risk: $larvaRisk',
                  riskColor: larvae > 0 ? Colors.amber[800]! : Colors.grey,
                  highlight: larvae > 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PestStageCard(
                  emoji: '🦋',
                  stage: 'Adult Moths',
                  count: moths,
                  riskLabel: 'Spread: $mothRisk',
                  riskColor: moths > 0 ? Colors.purple[700]! : Colors.grey,
                  highlight: moths > 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PestStageCard(
                  emoji: '🥚',
                  stage: 'Egg Masses',
                  count: eggs,
                  riskLabel: eggs > 0 ? 'Present' : 'None',
                  riskColor: eggs > 0 ? Colors.pink[600]! : Colors.grey,
                  highlight: eggs > 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PestStageCard(
                  emoji: '🟤',
                  stage: 'Pupae',
                  count: pupae,
                  riskLabel: pupae > 0 ? 'Present' : 'None',
                  riskColor: pupae > 0 ? Colors.brown : Colors.grey,
                  highlight: pupae > 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRcpcValidationCard(Map<String, dynamic> data) {
    final expertDiagnosis = (data['expertDiagnosis'] ?? '').toString();
    final mitigationAction = (data['mitigationAction'] ?? '').toString();
    final advisoryMessage = (data['advisoryMessage'] ?? '').toString();
    final validationNotes = (data['validationNotes'] ?? '').toString();
    final validatedBy = (data['validatedBy'] ?? 'RCPC Officer').toString();
    final validatedAt = data['validatedAt'];

    String formattedDate = '';
    if (validatedAt is Timestamp) {
      formattedDate = DateFormat('MMM d, yyyy · h:mm a').format(validatedAt.toDate());
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.05),
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
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF1D4ED8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RCPC Official Validation',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    if (formattedDate.isNotEmpty)
                      Text(
                        'Verified by $validatedBy on $formattedDate',
                        style: GoogleFonts.manrope(fontSize: 11.5, color: const Color(0xFF3B82F6)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (expertDiagnosis.isNotEmpty && expertDiagnosis != 'match') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Diagnosis: ${expertDiagnosis.toUpperCase()}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E40AF),
                ),
              ),
            ),
          ],
          if (mitigationAction.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  'Recommended Action Priority: $mitigationAction',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ],
          if (advisoryMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Advisory Message:',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              advisoryMessage,
              style: GoogleFonts.manrope(
                fontSize: 13.5,
                height: 1.55,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
          if (validationNotes.isNotEmpty && validationNotes != advisoryMessage) ...[
            const SizedBox(height: 10),
            Text(
              'Officer Notes: $validationNotes',
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStationsBreakdown(dynamic stationsData) {
    if (stationsData is! List || stationsData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _forestGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.grid_view_rounded, color: _forestGreen, size: 20),
          ),
          title: Text(
            'Station Scouting Records',
            style: GoogleFonts.epilogue(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _forestGreen,
            ),
          ),
          subtitle: Text(
            'Detailed breakdown for all ${stationsData.length} stations',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
          ),
          children: stationsData.asMap().entries.map((entry) {
            final idx = entry.key;
            final station = entry.value as Map<String, dynamic>;
            return _buildStationCard(idx + 1, station);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStationCard(int number, Map<String, dynamic> station) {
    final title = station['title'] ?? 'Station $number';
    final plantsInspected = station['plantsInspected'] ?? 20;
    final damaged = station['damaged'] ?? 0;
    final larvae = station['larvae'] ?? 0;
    final moths = station['moths'] ?? 0;
    final eggMasses = station['eggMasses'] ?? 0;
    final pupae = station['pupae'] ?? 0;
    final notes = station['notes']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: _forestGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _forestGreen,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: damaged > 0 ? Colors.red.withValues(alpha: 0.12) : Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$damaged/$plantsInspected Damaged',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: damaged > 0 ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (larvae > 0) _StationPill(label: '$larvae Larvae', color: Colors.amber[800]!),
              if (moths > 0) _StationPill(label: '$moths Moths', color: Colors.purple[700]!),
              if (eggMasses > 0) _StationPill(label: '$eggMasses Eggs', color: Colors.pink[600]!),
              if (pupae > 0) _StationPill(label: '$pupae Pupae', color: Colors.brown),
              if (larvae == 0 && moths == 0 && eggMasses == 0 && pupae == 0)
                _StationPill(label: 'No pests found', color: Colors.green[700]!),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Notes: $notes',
              style: GoogleFonts.manrope(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContextCard(Map<String, dynamic> data, dynamic timestamp) {
    final farmName = (data['farmName'] ?? 'Farm').toString();
    final fieldName = (data['fieldName'] ?? 'Field').toString();
    final cycleName = (data['cycleName'] ?? 'Corn Cycle').toString();
    final controlMethod = data['controlMethod']?.toString();
    final trapsInstalled = data['trapsInstalled'] == true;

    return _InfoCard(
      icon: Icons.agriculture_rounded,
      title: 'Field & Scouting Context',
      accentColor: _gold,
      children: [
        _Row('Farm', farmName),
        _Row('Field', fieldName),
        _Row('Crop Cycle', cycleName),
        _Row('Scouting Date', _fmtDate(timestamp)),
        if (controlMethod != null && controlMethod.isNotEmpty)
          _Row('Control Method', controlMethod),
        _Row('Traps Installed', trapsInstalled ? 'Yes' : 'No'),
      ],
    );
  }

  List<String> _extractAllImages(Map<String, dynamic> data) {
    final List<String> list = [];
    final capturedImages = data['capturedImages'] as Map<String, dynamic>?;
    if (capturedImages != null) {
      for (final stageKey in ['larvae', 'eggMasses', 'damage', 'pupae', 'moths']) {
        final stageList = capturedImages[stageKey] as List?;
        if (stageList != null) {
          for (final img in stageList) {
            if (img is String && img.isNotEmpty && !list.contains(img)) {
              list.add(img);
            }
          }
        }
      }
    }
    // Also check stationsData photos
    final stationsData = data['stationsData'] as List?;
    if (stationsData != null) {
      for (final s in stationsData) {
        if (s is Map<String, dynamic>) {
          final sImgs = s['capturedImages'] as Map<String, dynamic>?;
          if (sImgs != null) {
            for (final listEntry in sImgs.values) {
              if (listEntry is List) {
                for (final img in listEntry) {
                  if (img is String && img.isNotEmpty && !list.contains(img)) {
                    list.add(img);
                  }
                }
              }
            }
          }
        }
      }
    }
    return list;
  }

  void _openFullscreenImage(String imageSource) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: DatabaseImage(source: imageSource, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESOLUTION LOGIC
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _showResolveConfirmation() async {
    final explanationController = TextEditingController();
    String? validationError;
    final explanation = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.green,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mark as Resolved?',
                  style: GoogleFonts.epilogue(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _forestGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Describe the action you took and the result you observed. RCPC will see this explanation.',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: explanationController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Resolution explanation',
                    hintText:
                        'Example: Applied biological control / Trichogramma and observed zero larvae upon follow-up...',
                    alignLabelWithHint: true,
                    errorText: validationError,
                    filled: true,
                    fillColor: _cream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _forestGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final text = explanationController.text.trim();
                          if (text.isEmpty) {
                            setSheetState(() => validationError = 'Explanation is required');
                            return;
                          }
                          Navigator.pop(sheetContext, text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _forestGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Confirm Resolved',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    explanationController.dispose();
    if (explanation != null && mounted) {
      await _markAsResolved(explanation);
    }
  }

  Future<void> _markAsResolved(String explanation) async {
    setState(() => _isResolving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final isClusteredReport = _isClustered;
      final collectionName = isClusteredReport ? 'clustered_reports' : 'reports';
      final reportRef = _firestore.collection(collectionName).doc(widget.reportId);

      final userName = await _getUserName(user.uid);
      final resolution = {
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
        'resolvedByUserName': userName,
        'resolutionExplanation': explanation,
      };

      final batch = _firestore.batch();
      batch.update(reportRef, resolution);

      if (!isClusteredReport) {
        final validationsSnap = await _firestore
            .collection('validations')
            .where('reportId', isEqualTo: widget.reportId)
            .get();
        for (final doc in validationsSnap.docs) {
          batch.update(doc.reference, resolution);
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Report marked as resolved',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _currentData['status'] = 'resolved';
          _currentData['resolutionExplanation'] = explanation;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('farmers').doc(userId).get();
      return doc.data()?['fullName'] ?? doc.data()?['name'] ?? 'Farmer';
    } catch (_) {
      return 'Farmer';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMMON HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroImage(String? base64, String? networkUrl) {
    if (base64 != null && base64.isNotEmpty) {
      if (base64.startsWith('firestore-image://')) {
        return DatabaseImage(source: base64);
      }
      try {
        final bytes = base64Decode(
          base64.startsWith('data:image') ? base64.split(',').last : base64,
        );
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return Image.network(
        networkUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _heroPlaceholder(),
      );
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() {
    return Container(
      color: _forestGreen,
      child: Center(
        child: Icon(
          Icons.pest_control_rounded,
          size: 64,
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return 'N/A';
    try {
      if (ts is Timestamp) return DateFormat('MMM d, yyyy · h:mm a').format(ts.toDate());
      if (ts is DateTime) return DateFormat('MMM d, yyyy · h:mm a').format(ts);
    } catch (_) {}
    return 'N/A';
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'validated':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _riskColor(String r) {
    switch (r.toLowerCase()) {
      case 'high':
      case 'critical':
      case 'very high':
        return const Color(0xFFD94F3D);
      case 'medium':
      case 'moderate':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  MarkdownStyleSheet _mdStyle() => MarkdownStyleSheet(
    p: GoogleFonts.manrope(fontSize: 14, height: 1.65, color: Colors.grey[700]),
    h1: GoogleFonts.epilogue(fontSize: 19, fontWeight: FontWeight.w800, color: _forestGreen),
    h2: GoogleFonts.epilogue(fontSize: 17, fontWeight: FontWeight.w700, color: _forestGreen),
    h3: GoogleFonts.epilogue(fontSize: 15, fontWeight: FontWeight.w700, color: _forestGreen),
    strong: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: _forestGreen),
    listBullet: GoogleFonts.manrope(fontSize: 14, color: Colors.grey[700]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SUB-COMPONENTS
// ══════════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  final IconData? icon;

  const _StatusChip({required this.status, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            status.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final Color color;
  final dynamic validatedAt;
  final String? validatedBy;
  final String? rejectionReason;
  final String? resolutionExplanation;
  final String? expertDiagnosis;
  final String? advisoryMessage;

  const _StatusBanner({
    required this.status,
    required this.color,
    this.validatedAt,
    this.validatedBy,
    this.rejectionReason,
    this.resolutionExplanation,
    this.expertDiagnosis,
    this.advisoryMessage,
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();

    String title;
    String description;
    IconData icon;
    Color bg;

    if (s == 'validated') {
      title = 'Validated by RCPC';
      description = 'Official review complete. Follow recommendations below.';
      icon = Icons.verified_rounded;
      bg = Colors.blue.withValues(alpha: 0.1);
    } else if (s == 'resolved') {
      title = 'Issue Resolved';
      description = resolutionExplanation != null && resolutionExplanation!.isNotEmpty
          ? 'Resolution notes recorded.'
          : 'This report has been addressed and marked as resolved.';
      icon = Icons.check_circle_rounded;
      bg = Colors.green.withValues(alpha: 0.1);
    } else if (s == 'rejected') {
      title = 'Report Rejected';
      description = rejectionReason != null && rejectionReason!.isNotEmpty
          ? 'Reason: $rejectionReason'
          : 'Report was declined by RCPC officers.';
      icon = Icons.cancel_rounded;
      bg = Colors.red.withValues(alpha: 0.1);
    } else {
      title = 'Pending RCPC Review';
      description = 'Report submitted. Awaiting official validation from RCPC officers.';
      icon = Icons.schedule_rounded;
      bg = Colors.orange.withValues(alpha: 0.1);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color accentColor;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.epilogue(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1B3015),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Colors.grey[500],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PestStageCard extends StatelessWidget {
  final String emoji;
  final String stage;
  final int count;
  final String riskLabel;
  final Color riskColor;
  final bool highlight;

  const _PestStageCard({
    required this.emoji,
    required this.stage,
    required this.count,
    required this.riskLabel,
    required this.riskColor,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? riskColor.withValues(alpha: 0.06) : const Color(0xFFF8F5EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? riskColor.withValues(alpha: 0.25) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const Spacer(),
              Text(
                '$count',
                style: GoogleFonts.epilogue(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: highlight ? riskColor : Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stage,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B3015),
            ),
          ),
          Text(
            riskLabel,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: riskColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StationPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StationPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  final double confidence;
  final String lifeStage;
  final String cropAffected;
  final dynamic timestamp;

  const _QuickStatsRow({
    required this.confidence,
    required this.lifeStage,
    required this.cropAffected,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Confidence',
            value: '${(confidence * 100).toInt()}%',
            icon: Icons.auto_awesome_rounded,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Life Stage',
            value: lifeStage,
            icon: Icons.egg_rounded,
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'Crop',
            value: cropAffected,
            icon: Icons.grass_rounded,
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.epilogue(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1B3015),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.epilogue(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B3015),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ExpandableCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.accentColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.title,
                    style: GoogleFonts.epilogue(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1B3015),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: Colors.grey[500],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B3015),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolveCTA extends StatelessWidget {
  final bool isResolving;
  final VoidCallback onNotYet;
  final VoidCallback onResolve;

  const _ResolveCTA({
    required this.isResolving,
    required this.onNotYet,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Has this issue been addressed?',
            style: GoogleFonts.epilogue(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1B3015),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Marking this resolved notifies RCPC and updates your surveillance history.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onNotYet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Not Yet',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isResolving ? null : onResolve,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: isResolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    'Mark Resolved',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
