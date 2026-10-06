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
    _loadPlantingDateIfMissing();
  }

  Future<void> _loadPlantingDateIfMissing() async {
    if (_currentData['plantingDate'] != null) return;
    final cycleId = _currentData['cycleId']?.toString();
    final userId = (_currentData['userId'] ?? _currentData['farmerId'] ?? _auth.currentUser?.uid)?.toString();
    if (cycleId == null || cycleId.isEmpty) return;

    try {
      if (userId != null && userId.isNotEmpty) {
        final cycleDoc = await _firestore.collection('users').doc(userId).collection('cycles').doc(cycleId).get();
        if (cycleDoc.exists && cycleDoc.data()?['plantingDate'] != null) {
          if (mounted) {
            setState(() {
              _currentData['plantingDate'] = cycleDoc.data()!['plantingDate'];
            });
          }
          return;
        }
      }
      final rootCycleDoc = await _firestore.collection('cycles').doc(cycleId).get();
      if (rootCycleDoc.exists && rootCycleDoc.data()?['plantingDate'] != null) {
        if (mounted) {
          setState(() {
            _currentData['plantingDate'] = rootCycleDoc.data()!['plantingDate'];
          });
        }
      }
    } catch (_) {}
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
            if (_currentData['plantingDate'] == null) {
              _loadPlantingDateIfMissing();
            }
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
    final timestamp = _resolveScoutingDate(data);

    final totalInspected = data['correctedInspected'] is num
        ? (data['correctedInspected'] as num).toInt()
        : (data['totalInspected'] is num ? (data['totalInspected'] as num).toInt() : 100);
    final totalDamaged = data['correctedDamaged'] is num
        ? (data['correctedDamaged'] as num).toInt()
        : (data['totalDamaged'] is num ? (data['totalDamaged'] as num).toInt() : 0);
    final damagePercentage = data['damagePercentage'] is num
        ? (data['damagePercentage'] as num).toDouble()
        : (totalInspected > 0 ? (totalDamaged / totalInspected) * 100 : 0.0);
    final exceedsThreshold = data['exceedsThreshold'] == true || damagePercentage >= 10.0;

    final totals = (data['correctedTotals'] as Map<String, dynamic>?) ?? (data['totals'] as Map<String, dynamic>?) ?? {};
    final eggs = totals['eggs'] is num ? (totals['eggs'] as num).toInt() : 0;
    final larvae = totals['larvae'] is num ? (totals['larvae'] as num).toInt() : 0;
    final pupae = totals['pupae'] is num ? (totals['pupae'] as num).toInt() : 0;
    final moths = totals['moths'] is num ? (totals['moths'] as num).toInt() : 0;

    final risk = (data['correctedRisk'] ?? data['riskLevel'] ?? data['severityLevel'] ?? (exceedsThreshold ? 'High' : 'Moderate')).toString();
    final isResolved = status.toLowerCase() == 'resolved';
    final isRejected = status.toLowerCase() == 'rejected';
    final isValidated = status.toLowerCase() == 'validated';
    final statusColor = _statusColor(status);

    // Collect all structured evidence images (both pest sightings and damage plants)
    final List<_ScoutingEvidenceImage> allEvidence = _extractAllEvidence(data);
    final List<_ScoutingEvidenceImage> damageImages =
        allEvidence.where((e) => e.category == 'damage').toList();
    final List<_ScoutingEvidenceImage> pestImages =
        allEvidence.where((e) => e.category != 'damage').toList();

    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          // ─── Sliver App Bar ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: allEvidence.isNotEmpty ? 290 : 200,
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
              if (isValidated && !isResolved)
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
                  if (allEvidence.isNotEmpty)
                    _buildGalleryHeader(allEvidence)
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

                  // 1b. Resolution Summary Record (if resolved)
                  if (isResolved) ...[
                    const SizedBox(height: 16),
                    _buildResolutionSummaryCard(data),
                  ],

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

                  // 3. Plant Damage Assessment Card (Detailed Damage, Symptoms & Photos)
                  _buildPlantDamageAssessmentCard(
                    data: data,
                    damageImages: damageImages,
                    totalInspected: totalInspected,
                    totalDamaged: totalDamaged,
                    damagePercentage: damagePercentage,
                    exceedsThreshold: exceedsThreshold,
                  ),

                  const SizedBox(height: 16),

                  // 4. Pest Stage Counts & Observed Pest Sightings Photos
                  _buildPestStageBreakdown(
                    eggs: eggs,
                    larvae: larvae,
                    pupae: pupae,
                    moths: moths,
                    data: data,
                    pestImages: pestImages,
                  ),

                  const SizedBox(height: 16),

                  // 5. Unified Verification Photo Evidence Gallery (if photos exist)
                  if (allEvidence.isNotEmpty) ...[
                    _ScoutingEvidenceGalleryCard(
                      images: allEvidence,
                      onOpenFullscreen: (list, idx) => _openFullscreenGallery(images: list, initialIndex: idx),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. RCPC Expert Validation Details (if available)
                  if (isValidated || data['advisoryMessage'] != null || data['validationNotes'] != null) ...[
                    _buildRcpcValidationCard(data),
                    const SizedBox(height: 16),
                  ],

                  // 6b. Diagnostic Traceability Card
                  _buildTraceabilityCard(data),
                  const SizedBox(height: 16),

                  // 7. Stations Inspection Breakdown (Accordion with Station Photos & Damage Scores)
                  _buildStationsBreakdown(data['stationsData'], allEvidence),

                  const SizedBox(height: 16),

                  // 8. Field & Cycle Context Card
                  _buildContextCard(data, timestamp),

                  const SizedBox(height: 20),

                  // 9. Resolve CTA (only for validated reports)
                  if (isValidated && !isResolved)
                    _ResolveCTA(
                      isResolving: _isResolving,
                      onNotYet: () => Navigator.pop(context),
                      onResolve: _showResolveConfirmation,
                    )
                  else if (!isResolved && !isRejected)
                    _UnvalidatedInfoCard(
                      reportType: 'clustered',
                      isHighLevel: exceedsThreshold,
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
    final timestamp = data['dateConducted'] ??
        data['scoutingDate'] ??
        data['submittedAt'] ??
        data['timestamp'] ??
        data['createdAt'];
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
              if (isValidated && !isResolved)
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

                  // 1b. Resolution Summary Record (if resolved)
                  if (isResolved) ...[
                    const SizedBox(height: 16),
                    _buildResolutionSummaryCard(data),
                  ],

                  const SizedBox(height: 16),

                  // 2. RCPC Official Verification Box (if validated or has officer notes)
                  if (isValidated || data['advisoryMessage'] != null || data['validationNotes'] != null) ...[
                    _buildRcpcValidationCard(data),
                    const SizedBox(height: 16),
                  ],

                  // 2b. Diagnostic Traceability Card
                  _buildTraceabilityCard(data),
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

                  // 8. Resolve CTA (only for validated reports)
                  if (isValidated && !isResolved) ...[
                    const SizedBox(height: 8),
                    _ResolveCTA(
                      isResolving: _isResolving,
                      onNotYet: () => Navigator.pop(context),
                      onResolve: _showResolveConfirmation,
                    ),
                  ] else if (!isResolved && !isRejected) ...[
                    const SizedBox(height: 8),
                    _UnvalidatedInfoCard(
                      reportType: 'regular',
                      isHighLevel: false,
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

  Widget _buildGalleryHeader(List<_ScoutingEvidenceImage> images) {
    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (context, index) {
        final img = images[index];
        return GestureDetector(
          onTap: () => _openFullscreenGallery(images: images, initialIndex: index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DatabaseImage(source: img.source, fit: BoxFit.cover),
              Positioned(
                top: 50,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(img.icon, size: 12, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'Photo ${index + 1}/${images.length} · ${img.displayTag}',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
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

  // ─── Plant Damage Assessment Card ──────────────────────────────────────────
  Widget _buildPlantDamageAssessmentCard({
    required Map<String, dynamic> data,
    required List<_ScoutingEvidenceImage> damageImages,
    required int totalInspected,
    required int totalDamaged,
    required double damagePercentage,
    required bool exceedsThreshold,
  }) {
    final damageAssessment = (data['damageAssessment'] as Map<String, dynamic>?) ?? {};
    final avgWhorl = damageAssessment['averageWhorlLeafScore'] ?? data['averageWhorlScore'];
    final avgCob = damageAssessment['averageCobScore'] ?? data['averageCobScore'];
    final stationsData = data['stationsData'] as List?;

    // Collect per-plant scores
    final plantScores = <Map<String, dynamic>>[];
    if (damageAssessment['plantScores'] is List) {
      for (final s in damageAssessment['plantScores']) {
        if (s is Map<String, dynamic>) plantScores.add(s);
      }
    } else if (stationsData != null) {
      for (int sIdx = 0; sIdx < stationsData.length; sIdx++) {
        final st = stationsData[sIdx];
        if (st is Map<String, dynamic>) {
          final sScores = st['plantDamageScores'] as List?;
          if (sScores != null) {
            for (final sc in sScores) {
              if (sc is Map<String, dynamic>) {
                plantScores.add({
                  'station': st['title'] ?? 'Station ${sIdx + 1}',
                  'plantNumber': sc['plantNumber'],
                  'whorlScore': sc['whorlScore'],
                  'cobScore': sc['cobScore'],
                });
              }
            }
          }
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco_rounded, color: Color(0xFF7B1FA2), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plant Damage Assessment',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _forestGreen,
                      ),
                    ),
                    Text(
                      'Visual evaluation of crop leaf & whorl damage ($totalDamaged/$totalInspected plants)',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: exceedsThreshold ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: exceedsThreshold ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${damagePercentage.toStringAsFixed(1)}% Damaged',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: exceedsThreshold ? Colors.red[700] : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Threshold Alert Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: exceedsThreshold ? const Color(0xFFFFF1F0) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: exceedsThreshold ? const Color(0xFFFECDD3) : const Color(0xFFBBF7D0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  exceedsThreshold ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                  color: exceedsThreshold ? Colors.red[700] : Colors.green[700],
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exceedsThreshold
                            ? 'ACTION THRESHOLD EXCEEDED (≥ 10%)'
                            : 'BELOW ECONOMIC THRESHOLD (< 10%)',
                        style: GoogleFonts.manrope(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: exceedsThreshold ? Colors.red[800] : Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exceedsThreshold
                            ? '$totalDamaged out of $totalInspected corn plants (${damagePercentage.toStringAsFixed(1)}%) exhibit active FAW damage. Immediate pest management (biocontrol, botanical, or targeted application) is recommended to prevent yield loss.'
                            : '$totalDamaged out of $totalInspected plants (${damagePercentage.toStringAsFixed(1)}%) show damage symptoms. Infestation is within acceptable threshold. Continue regular surveillance.',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: exceedsThreshold ? Colors.red[900] : Colors.green[900],
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scoring Metrics (Davis / CIMMYT scale) if scores exist
          if (avgWhorl != null || avgCob != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (avgWhorl != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.grading_rounded, size: 14, color: Color(0xFF7B1FA2)),
                              const SizedBox(width: 4),
                              Text(
                                'Avg Whorl Score',
                                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            avgWhorl is num ? '${avgWhorl.toStringAsFixed(1)} / 9' : '$avgWhorl / 9',
                            style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF7B1FA2)),
                          ),
                          Text(
                            'Davis Scale (1-9)',
                            style: GoogleFonts.manrope(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (avgWhorl != null && avgCob != null) const SizedBox(width: 10),
                if (avgCob != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.grain_rounded, size: 14, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                'Avg Cob Score',
                                style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            avgCob is num ? '${avgCob.toStringAsFixed(1)} / 9' : '$avgCob / 9',
                            style: GoogleFonts.epilogue(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFFD97706)),
                          ),
                          Text(
                            'CIMMYT Scale (1-9)',
                            style: GoogleFonts.manrope(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Damaged Plants Photo Evidence Carousel
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Damaged Plants Photo Evidence',
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _forestGreen,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${damageImages.length} photo${damageImages.length == 1 ? '' : 's'}',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7B1FA2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (damageImages.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: damageImages.length,
                itemBuilder: (context, idx) {
                  final img = damageImages[idx];
                  return GestureDetector(
                    onTap: () => _openFullscreenGallery(images: damageImages, initialIndex: idx),
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: DatabaseImage(source: img.source, fit: BoxFit.cover),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.4, 1.0],
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fullscreen_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            right: 6,
                            child: Text(
                              img.displayTag,
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5EF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      totalDamaged > 0
                          ? '$totalDamaged damaged plants were recorded without photo uploads.'
                          : 'No plant damage was recorded during this scouting session.',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),

          // Per-station damage distribution summary
          if (stationsData != null && stationsData.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Station Damage Distribution',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: stationsData.asMap().entries.map((entry) {
                final idx = entry.key;
                final s = entry.value as Map<String, dynamic>;
                final sTitle = s['title'] ?? 'Station ${idx + 1}';
                final sDamaged = s['damaged'] as int? ?? 0;
                final sInspected = s['plantsInspected'] as int? ?? 20;
                final hasDamage = sDamaged > 0;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasDamage ? Colors.red.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasDamage ? Colors.red.withValues(alpha: 0.25) : Colors.green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    '$sTitle: $sDamaged/$sInspected',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: hasDamage ? Colors.red[800] : Colors.green[800],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Per-plant individual score details (if recorded)
          if (plantScores.isNotEmpty && plantScores.any((e) => e['whorlScore'] != null || e['cobScore'] != null)) ...[
            const SizedBox(height: 14),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                title: Text(
                  'Individual Damaged Plant Scores (${plantScores.length})',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _forestGreen,
                  ),
                ),
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: plantScores.map((ps) {
                      final station = ps['station'] ?? 'Station';
                      final pNum = ps['plantNumber'] ?? 1;
                      final whorl = ps['whorlScore'];
                      final cob = ps['cobScore'];

                      String scoreText = '';
                      if (whorl != null && cob != null) {
                        scoreText = 'Whorl: $whorl · Cob: $cob';
                      } else if (whorl != null) {
                        scoreText = 'Whorl: $whorl/9';
                      } else if (cob != null) {
                        scoreText = 'Cob: $cob/9';
                      } else {
                        scoreText = 'Damaged';
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F5EF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          '$station - Plant #$pNum ($scoreText)',
                          style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1B3015)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Pest Life-Stage Inventory & Observed Sighting Photos ──────────────────
  Widget _buildPestStageBreakdown({
    required int eggs,
    required int larvae,
    required int pupae,
    required int moths,
    required Map<String, dynamic> data,
    required List<_ScoutingEvidenceImage> pestImages,
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

          // Pest Sightings Photo Evidence Showcase
          if (pestImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Observed Pest Sightings Photo Evidence',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _forestGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${pestImages.length} photo${pestImages.length == 1 ? '' : 's'}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: pestImages.length,
                itemBuilder: (context, idx) {
                  final img = pestImages[idx];
                  return GestureDetector(
                    onTap: () => _openFullscreenGallery(images: pestImages, initialIndex: idx),
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: DatabaseImage(source: img.source, fit: BoxFit.cover),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.4, 1.0],
                                colors: [Colors.transparent, Colors.black87],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: img.color.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                img.categoryLabel,
                                style: GoogleFonts.manrope(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 6,
                            right: 6,
                            child: Text(
                              img.displayTag,
                              style: GoogleFonts.manrope(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRcpcValidationCard(Map<String, dynamic> data) {
    final expertDiagnosis = (data['expertDiagnosis'] ?? '').toString();
    final mitigationAction = (data['mitigationAction'] ?? '').toString();
    final advisoryMessage = (data['advisoryMessage'] ?? '').toString();
    final validationNotes = (data['validationNotes'] ?? '').toString();
    final validatedBy = (data['validatedBy'] ?? 'DA-RCPC Officer').toString();
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
                      'DA-RCPC Official Validation',
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
                'Expert Diagnosis: ${expertDiagnosis.toUpperCase()}',
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
              'Technical Advisory Message:',
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
              'Expert Notes: $validationNotes',
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

  Widget _buildTraceabilityCard(Map<String, dynamic> data) {
    final originalDetection = (data['originalDetection'] ?? data['detection'] ?? 'Pest Detection').toString();
    final originalLifeStage = (data['originalLifeStage'] ?? data['lifeStage'] ?? 'Unknown').toString();
    final originalRisk = (data['originalRisk'] ?? data['risk'] ?? data['riskLevel'] ?? 'Moderate').toString();
    final confidence = data['confidence'] is num ? (data['confidence'] as num).toDouble() : null;

    final expertDiagnosis = (data['expertDiagnosis'] ?? '').toString();
    final correctedLifeStage = (data['correctedLifeStage'] ?? '').toString();
    final validatedBy = (data['validatedBy'] ?? 'DA-RCPC Expert').toString();
    final validatedAt = data['validatedAt'];
    final validationNotes = (data['validationNotes'] ?? data['rejectionReason'] ?? '').toString();

    String formattedDate = '';
    if (validatedAt is Timestamp) {
      formattedDate = DateFormat('MMM d, yyyy · h:mm a').format(validatedAt.toDate());
    }

    final hasExpertReview = expertDiagnosis.isNotEmpty || correctedLifeStage.isNotEmpty || validatedAt != null || validationNotes.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.history_edu_rounded, color: Color(0xFF0D4D33), size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Diagnostic Traceability',
                style: GoogleFonts.epilogue(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B3015),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Original AI Result
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'ORIGINAL AI RESULT (Preliminary)',
                      style: GoogleFonts.manrope(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Classification: $originalDetection · Stage: $originalLifeStage · Risk: $originalRisk${confidence != null ? ' (${(confidence * 100).round()}% match)' : ''}',
                  style: GoogleFonts.manrope(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),

          if (hasExpertReview) ...[
            const SizedBox(height: 10),
            // 2. Expert Correction / Review
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Text(
                        'DA-RCPC EXPERT VALIDATION',
                        style: GoogleFonts.manrope(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1D4ED8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reviewed by $validatedBy${formattedDate.isNotEmpty ? ' on $formattedDate' : ''}',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E3A8A),
                    ),
                  ),
                  if (expertDiagnosis.isNotEmpty && expertDiagnosis != 'match') ...[
                    const SizedBox(height: 4),
                    Text(
                      'Corrected Diagnosis: ${expertDiagnosis.toUpperCase()}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                  if (correctedLifeStage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Corrected Life Stage: $correctedLifeStage',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                  if (validationNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Expert Notes: $validationNotes',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Station Scouting Records Breakdown ───────────────────────────────────
  Widget _buildStationsBreakdown(dynamic stationsData, List<_ScoutingEvidenceImage> allEvidence) {
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
            'Detailed records and evidence for all ${stationsData.length} stations',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
          ),
          children: stationsData.asMap().entries.map((entry) {
            final idx = entry.key;
            final station = entry.value as Map<String, dynamic>;
            final stationTitle = station['title'] ?? 'Station ${idx + 1}';

            // Find all evidence photos specific to this station
            final stationEvidence = allEvidence.where((e) {
              if (e.stationTitle != null && e.stationTitle!.toLowerCase() == stationTitle.toString().toLowerCase()) {
                return true;
              }
              if (e.stationIndex != null && e.stationIndex == idx + 1) {
                return true;
              }
              return false;
            }).toList();

            return _buildStationCard(idx + 1, station, stationEvidence);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStationCard(int number, Map<String, dynamic> station, List<_ScoutingEvidenceImage> stationEvidence) {
    final title = station['title'] ?? 'Station $number';
    final plantsInspected = station['plantsInspected'] ?? 20;
    final damaged = station['damaged'] ?? 0;
    final larvae = station['larvae'] ?? 0;
    final moths = station['moths'] ?? 0;
    final eggMasses = station['eggMasses'] ?? 0;
    final pupae = station['pupae'] ?? 0;
    final notes = station['notes']?.toString() ?? '';
    final plantDamageScores = (station['plantDamageScores'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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

          // Station-specific Photo Evidence (Pests & Damaged Plants)
          if (stationEvidence.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Station Evidence Photos (${stationEvidence.length}):',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: stationEvidence.length,
                itemBuilder: (context, sIdx) {
                  final sImg = stationEvidence[sIdx];
                  return GestureDetector(
                    onTap: () => _openFullscreenGallery(images: stationEvidence, initialIndex: sIdx),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: DatabaseImage(source: sImg.source, fit: BoxFit.cover),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: sImg.color.withValues(alpha: 0.85),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
                              ),
                              child: Text(
                                sImg.category == 'damage'
                                    ? (sImg.plantNumber != null ? 'P#${sImg.plantNumber}' : 'Damage')
                                    : sImg.categoryLabel,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Plant damage score pills
          if (plantDamageScores.isNotEmpty &&
              plantDamageScores.any((e) => e['whorlScore'] != null || e['cobScore'] != null)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: plantDamageScores.map((ps) {
                final pNum = ps['plantNumber'] ?? 1;
                final whorl = ps['whorlScore'];
                final cob = ps['cobScore'];
                if (whorl == null && cob == null) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF7B1FA2).withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'Plant #$pNum: ${whorl != null ? 'Whorl $whorl/9' : ''}${cob != null ? ' Cob $cob/9' : ''}',
                    style: GoogleFonts.manrope(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF7B1FA2)),
                  ),
                );
              }).toList(),
            ),
          ],

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

  // ─── Evidence Extraction Logic ────────────────────────────────────────────
  List<_ScoutingEvidenceImage> _extractAllEvidence(Map<String, dynamic> data) {
    final List<_ScoutingEvidenceImage> results = [];
    final Set<String> seenSources = {};

    void addImage({
      required String source,
      required String category,
      String? stationTitle,
      int? stationIndex,
      int? plantNumber,
    }) {
      if (source.isEmpty || seenSources.contains(source)) return;
      seenSources.add(source);

      String label;
      Color color;
      IconData icon;

      switch (category.toLowerCase()) {
        case 'larvae':
          label = 'Larvae';
          color = const Color(0xFFFF9800);
          icon = Icons.bug_report;
          break;
        case 'moths':
        case 'moth':
          label = 'Adult Moth';
          color = const Color(0xFF2196F3);
          icon = Icons.bug_report_outlined;
          break;
        case 'eggmasses':
        case 'eggs':
        case 'egg':
          label = 'Egg Mass';
          color = const Color(0xFFE91E63);
          icon = Icons.circle;
          break;
        case 'pupae':
        case 'pupa':
          label = 'Pupae';
          color = const Color(0xFF9C27B0);
          icon = Icons.coffee;
          break;
        case 'damage':
        case 'damagephotos':
        case 'plantdamage':
        default:
          label = 'Damaged Plant';
          color = const Color(0xFF7B1FA2);
          icon = Icons.eco_rounded;
          break;
      }

      results.add(_ScoutingEvidenceImage(
        source: source,
        category: category.toLowerCase().contains('damage') ? 'damage' : category,
        categoryLabel: label,
        stationTitle: stationTitle,
        stationIndex: stationIndex,
        plantNumber: plantNumber,
        color: color,
        icon: icon,
      ));
    }

    // 1. From data['stationsData']
    final stationsData = data['stationsData'] as List?;
    if (stationsData != null) {
      for (int i = 0; i < stationsData.length; i++) {
        final s = stationsData[i];
        if (s is Map<String, dynamic>) {
          final title = s['title'] as String? ?? 'Station ${i + 1}';

          // Check direct damagePhotos in station
          final sDamagePhotos = s['damagePhotos'] as List?;
          if (sDamagePhotos != null) {
            for (int pIdx = 0; pIdx < sDamagePhotos.length; pIdx++) {
              final img = sDamagePhotos[pIdx];
              if (img is String && img.isNotEmpty) {
                addImage(
                  source: img,
                  category: 'damage',
                  stationTitle: title,
                  stationIndex: i + 1,
                  plantNumber: pIdx + 1,
                );
              }
            }
          }

          // Check capturedImages map in station
          final sImgs = s['capturedImages'] as Map<String, dynamic>?;
          if (sImgs != null) {
            for (final entry in sImgs.entries) {
              final key = entry.key;
              final val = entry.value;
              if (val is List) {
                for (int itemIdx = 0; itemIdx < val.length; itemIdx++) {
                  final img = val[itemIdx];
                  if (img is String && img.isNotEmpty) {
                    addImage(
                      source: img,
                      category: key,
                      stationTitle: title,
                      stationIndex: i + 1,
                      plantNumber: key == 'damage' ? itemIdx + 1 : null,
                    );
                  }
                }
              }
            }
          }

          // Check damageImages list in station
          final sDamageImages = s['damageImages'] as List?;
          if (sDamageImages != null) {
            for (int pIdx = 0; pIdx < sDamageImages.length; pIdx++) {
              final img = sDamageImages[pIdx];
              if (img is String && img.isNotEmpty) {
                addImage(
                  source: img,
                  category: 'damage',
                  stationTitle: title,
                  stationIndex: i + 1,
                  plantNumber: pIdx + 1,
                );
              }
            }
          }
        }
      }
    }

    // 2. From data['capturedImages'] at root
    final capturedImages = data['capturedImages'] as Map<String, dynamic>?;
    if (capturedImages != null) {
      for (final entry in capturedImages.entries) {
        final key = entry.key;
        final val = entry.value;
        if (val is List) {
          String parsedCategory = key;
          String? parsedStation;
          if (key.contains('_')) {
            final parts = key.split('_');
            parsedStation = parts.first;
            parsedCategory = parts.sublist(1).join('_');
          }

          for (int itemIdx = 0; itemIdx < val.length; itemIdx++) {
            final img = val[itemIdx];
            if (img is String && img.isNotEmpty) {
              addImage(
                source: img,
                category: parsedCategory,
                stationTitle: parsedStation,
                plantNumber: parsedCategory.toLowerCase().contains('damage') ? itemIdx + 1 : null,
              );
            }
          }
        }
      }
    }

    // 3. From data['allDamagePhotos'] or data['damagePhotos'] at root
    for (final field in ['allDamagePhotos', 'damagePhotos']) {
      final directPhotos = data[field] as List?;
      if (directPhotos != null) {
        for (int itemIdx = 0; itemIdx < directPhotos.length; itemIdx++) {
          final img = directPhotos[itemIdx];
          if (img is String && img.isNotEmpty) {
            addImage(
              source: img,
              category: 'damage',
              plantNumber: itemIdx + 1,
            );
          }
        }
      }
    }

    return results;
  }

  // ─── Interactive Fullscreen Gallery Dialog ────────────────────────────────
  void _openFullscreenGallery({
    required List<_ScoutingEvidenceImage> images,
    int initialIndex = 0,
  }) {
    if (images.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) {
        int currentIndex = initialIndex.clamp(0, images.length - 1);
        final pageController = PageController(initialPage: currentIndex);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentImg = images[currentIndex];

            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: images.length,
                    onPageChanged: (idx) {
                      setDialogState(() => currentIndex = idx);
                    },
                    itemBuilder: (context, idx) {
                      final item = images[idx];
                      return Center(
                        child: InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: DatabaseImage(source: item.source, fit: BoxFit.contain),
                        ),
                      );
                    },
                  ),

                  // Top Header Bar
                  Positioned(
                    top: 40,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: currentImg.color.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(currentImg.icon, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                currentImg.displayTag,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${currentIndex + 1} / ${images.length}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Left Navigation Button
                  if (images.length > 1 && currentIndex > 0)
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                            onPressed: () {
                              pageController.previousPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  // Right Navigation Button
                  if (images.length > 1 && currentIndex < images.length - 1)
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                          child: IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                            onPressed: () {
                              pageController.nextPage(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESOLUTION LOGIC (FAW Report Resolution Guidelines)
  // ══════════════════════════════════════════════════════════════════════════

  String _getReportCategoryName() {
    if (!_isClustered) {
      return 'Regular FAW Report';
    }
    final totalInspected = _currentData['correctedInspected'] is num
        ? (_currentData['correctedInspected'] as num).toInt()
        : (_currentData['totalInspected'] is num
            ? (_currentData['totalInspected'] as num).toInt()
            : 100);
    final totalDamaged = _currentData['correctedDamaged'] is num
        ? (_currentData['correctedDamaged'] as num).toInt()
        : (_currentData['totalDamaged'] is num
            ? (_currentData['totalDamaged'] as num).toInt()
            : 0);
    final damagePercentage = _currentData['damagePercentage'] is num
        ? (_currentData['damagePercentage'] as num).toDouble()
        : (totalInspected > 0 ? (totalDamaged / totalInspected) * 100 : 0.0);
    final bool isHigh = _currentData['exceedsThreshold'] == true ||
        _currentData['isHighLevel'] == true ||
        damagePercentage >= 10.0 ||
        (_currentData['riskLevel'] ?? _currentData['severityLevel'] ?? '')
            .toString()
            .toLowerCase()
            .contains('high');
    return isHigh
        ? 'High-Level Scouting-Based Report'
        : 'Low-Level Scouting-Based Report';
  }

  List<String> _getResolutionReasonsForCategory(String category) {
    switch (category) {
      case 'Regular FAW Report':
        return const [
          'No further FAW-associated damage observed',
          'RCPC-recommended management completed',
          'Biological control applied and condition improved',
          'Chemical control applied and condition improved',
          'Combined IPM/management actions completed',
          'No further occurrence after continued monitoring',
          'Crop harvested / cropping cycle completed',
        ];
      case 'Low-Level Scouting-Based Report':
        return const [
          'No increase in FAW-associated damage during monitoring',
          'No further FAW-associated damage observed',
          'Condition improved after routine/cultural management',
          'Biological control applied and condition improved',
          'Crop harvested / cropping cycle completed',
        ];
      case 'High-Level Scouting-Based Report':
      default:
        return const [
          'RCPC-recommended management completed',
          'Biological control applied and condition improved',
          'Chemical control applied and condition improved',
          'Combined IPM/management actions completed',
          'No further FAW-associated damage observed after intervention',
          'Condition improved and remained below concern during follow-up',
          'Crop harvested / cropping cycle completed',
        ];
    }
  }

  Future<void> _showResolveConfirmation() async {
    final category = _getReportCategoryName();
    final reasons = _getResolutionReasonsForCategory(category);

    final explanationController = TextEditingController();

    String? selectedReason;
    String? reasonError;
    String? explanationError;

    final advisoryMessage = (_currentData['advisoryMessage'] ?? '').toString();
    final bool isHighLevel = category == 'High-Level Scouting-Based Report';

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: Colors.green,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mark Report as Resolved',
                              style: GoogleFonts.epilogue(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _forestGreen,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                category,
                                style: GoogleFonts.manrope(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // DA-RCPC Advisory Box (Section 6 & 12 of Guidelines)
                  if (advisoryMessage.isNotEmpty || isHighLevel) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE), width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.campaign_rounded,
                                  color: Color(0xFF1D4ED8), size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'DA-RCPC Official Advisory',
                                style: GoogleFonts.manrope(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                          if (advisoryMessage.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              advisoryMessage,
                              style: GoogleFonts.manrope(
                                fontSize: 12.5,
                                height: 1.4,
                                color: const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            'Review the DA-RCPC advisory before resolving this report. If the recommended action has not yet been completed or monitoring is still required, keep the report under monitoring.',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF3B82F6),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 1. Resolution Reason Dropdown
                  Text(
                    'Resolution Reason *',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _forestGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    decoration: InputDecoration(
                      hintText: 'Select resolution outcome...',
                      hintStyle: GoogleFonts.manrope(
                          fontSize: 13, color: Colors.grey[500]),
                      errorText: reasonError,
                      filled: true,
                      fillColor: _cream,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                    items: reasons.map((r) {
                      return DropdownMenuItem<String>(
                        value: r,
                        child: Text(
                          r,
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        selectedReason = val;
                        reasonError = null;
                      });
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select the reason that best explains why the FAW concern is considered addressed. Your message will be retained in Report History.',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: Colors.grey[600],
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Resolution Message (Required)
                  Text(
                    'Resolution Message *',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _forestGreen,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: explanationController,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText:
                          'Describe field condition, actions taken, and current crop observations...',
                      hintStyle: GoogleFonts.manrope(
                          fontSize: 12.5, color: Colors.grey[500]),
                      errorText: explanationError,
                      filled: true,
                      fillColor: _cream,
                      contentPadding: const EdgeInsets.all(14),
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

                  // Actions
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
                            'Keep Active',
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
                            bool hasError = false;
                            if (selectedReason == null ||
                                selectedReason!.isEmpty) {
                              setSheetState(() => reasonError =
                                  'Please select a resolution reason');
                              hasError = true;
                            }
                            final text = explanationController.text.trim();
                            if (text.isEmpty) {
                              setSheetState(() => explanationError =
                                  'Resolution message is required');
                              hasError = true;
                            } else if (text.length < 5) {
                              setSheetState(() => explanationError =
                                  'Please provide at least 5 characters');
                              hasError = true;
                            }
                            if (hasError) return;

                            Navigator.pop(sheetContext, {
                              'reason': selectedReason!,
                              'explanation': text,
                              'category': category,
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
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
          );
        },
      ),
    );

    explanationController.dispose();

    if (result != null && mounted) {
      await _markAsResolved(
        reason: result['reason'] as String,
        explanation: result['explanation'] as String,
        reportCategory: result['category'] as String,
      );
    }
  }

  Future<void> _markAsResolved({
    required String reason,
    required String explanation,
    required String reportCategory,
  }) async {
    setState(() => _isResolving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final isClusteredReport = _isClustered;
      final collectionName =
          isClusteredReport ? 'clustered_reports' : 'reports';
      final reportRef =
          _firestore.collection(collectionName).doc(widget.reportId);

      final userName = await _getUserName(user.uid);
      final dapResolvedDate = _resolveResolvedDate(_currentData);

      final resolution = {
        'status': 'resolved',
        'resolvedAt': Timestamp.fromDate(dapResolvedDate),
        'resolvedBy': user.uid,
        'resolvedByUserName': userName,
        'resolutionReason': reason,
        'resolutionExplanation': explanation,
        'reportCategory': reportCategory,
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
                Expanded(
                  child: Text(
                    'Report marked as resolved: $reason',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _currentData['status'] = 'resolved';
          _currentData['resolutionReason'] = reason;
          _currentData['resolutionExplanation'] = explanation;
          _currentData.remove('followUpMonitoringDate');
          _currentData['resolvedAt'] = dapResolvedDate;
          _currentData['resolvedByUserName'] = userName;
          _currentData['reportCategory'] = reportCategory;
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Widget _buildResolutionSummaryCard(Map<String, dynamic> data) {
    final reason = (data['resolutionReason'] ?? '').toString();
    final explanation = (data['resolutionExplanation'] ?? '').toString();
    final managementAction =
        (data['managementActionTaken'] ?? '').toString();
    final resolvedByUserName =
        (data['resolvedByUserName'] ?? 'Farmer').toString();
    final category =
        (data['reportCategory'] ?? _getReportCategoryName()).toString();
    final dapResolvedDate = _resolveResolvedDate(data);
    final formattedResolvedDate =
        DateFormat('MMM d, yyyy').format(dapResolvedDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.05),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.task_alt_rounded,
                    color: Color(0xFF16A34A), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Resolution Record',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF14532D),
                      ),
                    ),
                    Text(
                      'Resolved by $resolvedByUserName · $formattedResolvedDate',
                      style: GoogleFonts.manrope(
                        fontSize: 11.5,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFDCFCE7)),
          const SizedBox(height: 12),

          // Report Classification badge
          Row(
            children: [
              Text(
                'Report Classification:',
                style: GoogleFonts.manrope(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  category,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF14532D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Resolution Reason
          if (reason.isNotEmpty) ...[
            Text(
              'Selected Resolution Reason:',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: Color(0xFF16A34A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF14532D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Resolution Message
          if (explanation.isNotEmpty) ...[
            Text(
              'Farmer Resolution Message:',
              style: GoogleFonts.manrope(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                explanation,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  height: 1.45,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Management Action Taken if present
          if (managementAction.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.healing_rounded,
                    size: 15, color: Color(0xFF15803D)),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                          fontSize: 12, color: const Color(0xFF334155)),
                      children: [
                        const TextSpan(
                          text: 'Management Action Taken: ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: managementAction),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
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

  int? _extractInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) {
      final match = RegExp(r'\d+').firstMatch(val);
      if (match != null) return int.tryParse(match.group(0)!);
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  DateTime _resolveScoutingDate(Map<String, dynamic> data) {
    final dynamic rawPlanting = data['plantingDate'] ??
        _currentData['plantingDate'] ??
        (data['cycleInfo'] is Map ? data['cycleInfo']['plantingDate'] : null);
    final planting = _parseDateTime(rawPlanting);

    final int? weekNumber = _extractInt(data['weekNumber']);
    final int? dap = _extractInt(data['dap']);

    final fallback = _parseDateTime(
      data['reportDate'] ??
      data['timestamp'] ??
      data['createdAt'] ??
      data['submittedAt'] ??
      data['dateConducted'] ??
      data['scoutingDate']
    );

    DateTime? effectivePlanting = planting;
    if (effectivePlanting == null && dap != null && dap > 0 && fallback != null) {
      effectivePlanting = fallback.subtract(Duration(days: dap));
    }

    if (effectivePlanting != null) {
      int? weekIndex;
      if (weekNumber != null && weekNumber >= 1) {
        weekIndex = weekNumber - 1;
      } else if (dap != null && dap > 0) {
        weekIndex = (dap - 1) ~/ 7;
      } else if (dap == 0) {
        weekIndex = 0;
      }

      if (weekIndex != null) {
        // Last day of that DAP week (7-day period starting from planting date)
        final nextWeek = DateTime(
          effectivePlanting.year,
          effectivePlanting.month,
          effectivePlanting.day + (weekIndex + 1) * 7,
        );
        return nextWeek.subtract(const Duration(microseconds: 1));
      }
    }

    return fallback ?? DateTime.now();
  }

  DateTime _resolveResolvedDate(Map<String, dynamic> data) {
    final dapWeekEnd = _resolveScoutingDate(data);
    return DateTime(
      dapWeekEnd.year,
      dapWeekEnd.month,
      dapWeekEnd.day + 3,
      12,
      0,
    );
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return 'N/A';
    try {
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (ts is DateTime) dt = ts;
      if (ts is String) dt = DateTime.tryParse(ts);
      if (dt != null) {
        if (dt.hour == 23 && dt.minute == 59) {
          return DateFormat('MMM d, yyyy').format(dt);
        }
        return DateFormat('MMM d, yyyy · h:mm a').format(dt);
      }
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
      title = 'Validated by DA-RCPC';
      description = 'Official review complete. Validated by DA-RCPC expert.';
      icon = Icons.verified_rounded;
      bg = Colors.blue.withValues(alpha: 0.1);
    } else if (s.contains('control') || s == 'control_applied') {
      title = 'Control Applied';
      description = 'Intervention applied. Field is currently under monitoring & follow-up.';
      icon = Icons.healing_rounded;
      bg = Colors.teal.withValues(alpha: 0.1);
    } else if (s == 'resolved') {
      title = 'Issue Resolved';
      description = resolutionExplanation != null && resolutionExplanation!.isNotEmpty
          ? 'Resolution notes recorded.'
          : 'This report has been addressed and marked as resolved.';
      icon = Icons.check_circle_rounded;
      bg = Colors.green.withValues(alpha: 0.1);
    } else if (s == 'rejected') {
      title = 'Report Declined / Rejected';
      description = rejectionReason != null && rejectionReason!.isNotEmpty
          ? 'Reason: $rejectionReason'
          : 'Report was declined by DA-RCPC officers.';
      icon = Icons.cancel_rounded;
      bg = Colors.red.withValues(alpha: 0.1);
    } else {
      title = 'Pending Expert Validation';
      description = 'This is a preliminary AI result and is subject to DA-RCPC Expert validation.';
      icon = Icons.pending_actions_rounded;
      bg = const Color(0xFFFFF8E1);
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

class _UnvalidatedInfoCard extends StatelessWidget {
  final String reportType;
  final bool isHighLevel;

  const _UnvalidatedInfoCard({
    required this.reportType,
    this.isHighLevel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.05),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pending_actions_rounded,
                    color: Color(0xFFD97706), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Awaiting DA-RCPC Expert Validation',
                  style: GoogleFonts.epilogue(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'In accordance with FAW management protocols, reports can only be resolved after an official review and validation by DA-RCPC experts.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              height: 1.5,
              color: const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 16, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 8),
                Text(
                  'Resolution Available After Validation',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6B7280),
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

// ══════════════════════════════════════════════════════════════════════════════
// SCOUTING EVIDENCE DATA MODELS & GALLERY
// ══════════════════════════════════════════════════════════════════════════════

class _ScoutingEvidenceImage {
  final String source;
  final String category; // 'damage', 'larvae', 'moths', 'eggMasses', 'pupae'
  final String categoryLabel; // 'Damaged Plant', 'Larvae', 'Adult Moth', 'Egg Mass', 'Pupae'
  final String? stationTitle; // 'Station 1'
  final int? stationIndex; // 1
  final int? plantNumber; // 1
  final Color color;
  final IconData icon;

  const _ScoutingEvidenceImage({
    required this.source,
    required this.category,
    required this.categoryLabel,
    this.stationTitle,
    this.stationIndex,
    this.plantNumber,
    required this.color,
    required this.icon,
  });

  String get displayTag {
    if (category == 'damage') {
      final pStr = plantNumber != null ? 'Damaged Plant #$plantNumber' : 'Plant Damage';
      if (stationTitle != null) {
        return '$stationTitle · $pStr';
      }
      return pStr;
    }
    if (stationTitle != null) {
      return '$stationTitle · $categoryLabel';
    }
    return categoryLabel;
  }
}

class _ScoutingEvidenceGalleryCard extends StatefulWidget {
  final List<_ScoutingEvidenceImage> images;
  final Function(List<_ScoutingEvidenceImage> list, int index) onOpenFullscreen;

  const _ScoutingEvidenceGalleryCard({
    required this.images,
    required this.onOpenFullscreen,
  });

  @override
  State<_ScoutingEvidenceGalleryCard> createState() => _ScoutingEvidenceGalleryCardState();
}

class _ScoutingEvidenceGalleryCardState extends State<_ScoutingEvidenceGalleryCard> {
  String _selectedCategory = 'all';

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    final categories = <String, int>{'all': widget.images.length};
    for (final img in widget.images) {
      categories[img.category] = (categories[img.category] ?? 0) + 1;
    }

    final filtered = _selectedCategory == 'all'
        ? widget.images
        : widget.images.where((img) => img.category == _selectedCategory).toList();

    return Container(
      width: double.infinity,
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
                  color: const Color(0xFF1B3015).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF1B3015), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scouting Photo Evidence Gallery',
                      style: GoogleFonts.epilogue(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1B3015),
                      ),
                    ),
                    Text(
                      '${widget.images.length} verified evidence photo${widget.images.length > 1 ? 's' : ''} uploaded',
                      style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.entries.map((entry) {
                final cat = entry.key;
                final count = entry.value;
                final isSelected = _selectedCategory == cat;

                String label;
                Color chipColor;
                switch (cat) {
                  case 'larvae':
                    label = '🐛 Larvae ($count)';
                    chipColor = const Color(0xFFFF9800);
                    break;
                  case 'moths':
                    label = '🦋 Moths ($count)';
                    chipColor = const Color(0xFF2196F3);
                    break;
                  case 'eggMasses':
                    label = '🥚 Eggs ($count)';
                    chipColor = const Color(0xFFE91E63);
                    break;
                  case 'pupae':
                    label = '🟤 Pupae ($count)';
                    chipColor = const Color(0xFF9C27B0);
                    break;
                  case 'damage':
                    label = '🌿 Damaged Plants ($count)';
                    chipColor = const Color(0xFF7B1FA2);
                    break;
                  default:
                    label = 'All Photos ($count)';
                    chipColor = const Color(0xFF1B3015);
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: chipColor,
                    backgroundColor: const Color(0xFFF8F5EF),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? chipColor : Colors.grey.shade300,
                      ),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Photo Thumbnails
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filtered.length,
              itemBuilder: (context, idx) {
                final item = filtered[idx];
                return GestureDetector(
                  onTap: () => widget.onOpenFullscreen(filtered, idx),
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F5EF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: DatabaseImage(source: item.source, fit: BoxFit.cover),
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.4, 1.0],
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(item.icon, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  item.categoryLabel,
                                  style: GoogleFonts.manrope(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.fullscreen_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          left: 8,
                          right: 8,
                          child: Text(
                            item.displayTag,
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
