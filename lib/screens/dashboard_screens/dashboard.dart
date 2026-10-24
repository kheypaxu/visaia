import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:visaia/services/dashboard_widget_service.dart';
import 'package:visaia/core/models/cycle_audit_policy.dart';
import 'package:visaia/core/models/cycle_metrics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/screens/dashboard_screens/all_farms_data_screen.dart';
import 'package:visaia/services/faw_activity_service.dart';
import 'package:visaia/utils/location_constants.dart';

export 'package:visaia/screens/dashboard_screens/all_farms_data_screen.dart';

// ======================= MODELS =======================

class CycleModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String farmId;
  final String cycleName;
  final String cropVariety;
  final DateTime? plantingDate;
  final DateTime? harvestDate;
  final double seedDensity;
  final bool isCompleted;
  final String? status;
  final String? statusText;
  final double? income;
  final DateTime? createdAt;

  CycleModel({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.farmId,
    required this.cycleName,
    required this.cropVariety,
    this.plantingDate,
    this.harvestDate,
    required this.seedDensity,
    this.isCompleted = false,
    this.status,
    this.statusText,
    this.income,
    this.createdAt,
  });

  factory CycleModel.fromMap(String id, Map<String, dynamic> map) {
    return CycleModel(
      id: id,
      fieldId: map['fieldId'] ?? '',
      fieldName: map['fieldName'] ?? 'No Field',
      farmId: map['farmId'] ?? '',
      cycleName: map['cycleName'] ?? 'Untitled Cycle',
      cropVariety: map['cropVariety'] ?? '',
      plantingDate: _parseTimestamp(map['plantingDate']),
      harvestDate: _parseTimestamp(
        map['expectedHarvestDate'] ??
            map['estimatedHarvestDate'] ??
            map['harvestDate'] ??
            map['actualHarvestDate'],
      ),
      seedDensity: (map['seedDensity'] as num?)?.toDouble() ?? 0.0,
      isCompleted: map['isCompleted'] ?? false,
      status: map['status'],
      statusText: map['statusText'],
      income: (map['income'] as num?)?.toDouble(),
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  factory CycleModel.fromDoc(QueryDocumentSnapshot doc) {
    return CycleModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int? get daysSincePlanting {
    if (plantingDate == null) return null;
    return DateTime.now().difference(plantingDate!).inDays;
  }
}

class FieldModel {
  final String id;
  final String name;
  final double acres;
  final String? crop;
  final List<LatLng> boundaries;

  FieldModel({
    required this.id,
    required this.name,
    required this.acres,
    required this.boundaries,
    this.crop,
  });

  factory FieldModel.fromMap(String id, Map<String, dynamic> data) {
    return FieldModel(
      id: id,
      name: data['name'] ?? '',
      acres: (data['acres'] ?? 0).toDouble(),
      crop: data['crop'],
      boundaries: (data['boundaries'] as List)
          .map(
            (p) => LatLng(
              (p['latitude'] ?? p['lat']).toDouble(),
              (p['longitude'] ?? p['lng']).toDouble(),
            ),
          )
          .toList(),
    );
  }
}

class PestModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String name;
  final String severity; // "high", "moderate", "low", "monitoring"
  final DateTime detectedAt;
  final bool isActive;

  PestModel({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.name,
    required this.severity,
    required this.detectedAt,
    required this.isActive,
  });

  factory PestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PestModel(
      id: doc.id,
      fieldId: data['fieldId'] ?? '',
      fieldName: data['fieldName'] ?? 'Unknown Field',
      name: data['name'] ?? 'Unknown Pest',
      severity: data['severity'] ?? 'low',
      detectedAt: (data['detectedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}

// ======================= FIRESTORE SERVICE =======================

class MonitoringFirestoreService {
  final FirebaseFirestore _db;
  final String _userId;
  final String? _farmId;

  MonitoringFirestoreService({
    FirebaseFirestore? db,
    required String userId,
    String? farmId,
  }) : _db = db ?? FirebaseFirestore.instance,
       _userId = userId,
       _farmId = farmId;

  // ----- Fields (from user document) -----
  Future<List<FieldModel>> getFields() async {
    if (_userId.isEmpty) return [];
    Query<Map<String, dynamic>> ref = _db
        .collection('users')
        .doc(_userId)
        .collection('fields');

    if (_farmId != null && _farmId.isNotEmpty) {
      ref = ref.where('farmId', isEqualTo: _farmId);
    }

    try {
      final snapshot = await ref.get();
      return snapshot.docs
          .map((doc) => FieldModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('getFields error: $e');
      return [];
    }
  }

  // ----- Active Cycles (isCompleted == false) -----
  Stream<List<CycleModel>> getActiveCycles() {
    if (_userId.isEmpty) return Stream.value([]);
    Query<Map<String, dynamic>> ref = _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .where('isCompleted', isEqualTo: false);

    if (_farmId != null && _farmId.isNotEmpty) {
      ref = ref.where('farmId', isEqualTo: _farmId);
    }

    return ref
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => CycleModel.fromMap(doc.id, doc.data()))
              .toList(),
        )
        .handleError((e) {
          debugPrint('getActiveCycles error: $e');
          return <CycleModel>[];
        });
  }

  // ----- Active Pests (isActive == true) -----
  Stream<List<PestModel>> getActivePests() {
    if (_userId.isEmpty) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_userId)
        .collection('pests')
        .where('isActive', isEqualTo: true)
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
          List<PestModel> pests = snap.docs
              .map((doc) => PestModel.fromFirestore(doc))
              .toList();

          if (_farmId != null && _farmId.isNotEmpty && pests.isNotEmpty) {
            final fieldIds = await _getFieldIdsForFarm();
            pests = pests.where((p) => fieldIds.contains(p.fieldId)).toList();
          }

          return pests;
        })
        .handleError((e) {
          debugPrint('getActivePests error: $e');
          return <PestModel>[];
        });
  }

  Future<Set<String>> _getFieldIdsForFarm() async {
    if (_userId.isEmpty || _farmId == null || _farmId.isEmpty) return {};
    try {
      final snapshot = await _db
          .collection('users')
          .doc(_userId)
          .collection('fields')
          .where('farmId', isEqualTo: _farmId)
          .get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('_getFieldIdsForFarm error: $e');
      return {};
    }
  }

  // ----- Recent Activity (daily logs, weekly scouting, pest uploads) -----
  Stream<List<ActivityFeedItem>> getRecentActivityLogs({int limit = 6}) {
    if (_userId.isEmpty) return Stream.value([]);
    return ActivityFeedService(
      userId: _userId,
      db: _db,
    ).watchUserActivity(limit: limit).handleError((e) {
      debugPrint('getRecentActivityLogs error: $e');
      return <ActivityFeedItem>[];
    });
  }

  // ----- Total Yield (kilograms harvested from completed cycles) -----
  Stream<double> getTotalYield() {
    if (_userId.isEmpty) return Stream.value(0.0);
    Query<Map<String, dynamic>> ref = _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .where('isCompleted', isEqualTo: true);

    if (_farmId != null && _farmId.isNotEmpty) {
      ref = ref.where('farmId', isEqualTo: _farmId);
    }

    return ref
        .snapshots()
        .map(
          (snap) => snap.docs.fold<double>(0.0, (sum, doc) {
            final data = doc.data();
            final yield = recordedYield(data) ?? 0.0;
            return sum + yield;
          }),
        )
        .handleError((e) {
          debugPrint('getTotalYield error: $e');
          return 0.0;
        });
  }

  // Use the same finalized audits and financial calculation as Full Analysis.
  Stream<double> getNetIncome() {
    if (_userId.isEmpty) return Stream.value(0.0);
    Query<Map<String, dynamic>> ref = _db
        .collection('users')
        .doc(_userId)
        .collection('cycles');

    if (_farmId != null && _farmId.isNotEmpty) {
      ref = ref.where('farmId', isEqualTo: _farmId);
    }

    return ref
        .snapshots()
        .map(
          (snap) => snap.docs.fold<double>(0.0, (sum, doc) {
            final data = doc.data();
            if (!hasCompletedHarvestAudit(data)) return sum;
            return sum + CycleFinance(data).net;
          }),
        )
        .handleError((e) {
          debugPrint('getNetIncome error: $e');
          return 0.0;
        });
  }
}

// ======================= HOMEDASHBOARD WIDGET =======================

class HomeDashboard extends StatefulWidget {
  final String userId;
  final String? activeFarmId;

  const HomeDashboard({super.key, required this.userId, this.activeFarmId});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final _kpiCaptureKey = GlobalKey();
  Timer? _widgetUpdateTimer;
  late final int _widgetGeneration;
  bool _incomeReady = false;
  bool _yieldReady = false;
  bool _fieldsReady = false;
  bool _cyclesReady = false;

  void _scheduleWidgetUpdate() {
    if (!DashboardWidgetService.supported ||
        !_incomeReady ||
        !_yieldReady ||
        !_fieldsReady ||
        !_cyclesReady) {
      return;
    }
    _widgetUpdateTimer?.cancel();
    _widgetUpdateTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        try {
          await GoogleFonts.pendingFonts();
        } catch (_) {
          // Offline, capture the same fallback font currently shown in the app.
        }
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final boundary = _kpiCaptureKey.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary || boundary.debugNeedsPaint) {
          return;
        }
        final image = await boundary.toImage(pixelRatio: 1.5);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          if (mounted && bytes != null) {
            await DashboardWidgetService.update(
              bytes.buffer.asUint8List(),
              _widgetGeneration,
            );
          }
        } finally {
          image.dispose();
        }
      } catch (error) {
        debugPrint('Could not render dashboard widget: $error');
      }
    });
  }

  @override
  void dispose() {
    _widgetUpdateTimer?.cancel();
    super.dispose();
  }

  // Brand colors
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);

  late final MonitoringFirestoreService _service;
  late final MunicipalFawService _fawService;

  late final Stream<double> _netIncomeStream;
  late final Stream<double> _totalYieldStream;
  late final Stream<List<CycleModel>> _activeCyclesStream;
  late final Future<List<FieldModel>> _fieldsFuture;
  late Stream<List<FawLifeStageReport>> _fawStream;
  late final Stream<List<ActivityFeedItem>> _activityStream;

  @override
  void initState() {
    super.initState();
    unawaited(DashboardWidgetService.clear());
    // clear invalidates old captures; begin a fresh generation for this farm.
    _widgetGeneration = DashboardWidgetService.beginSession();

    _service = MonitoringFirestoreService(
      userId: widget.userId,
      farmId: widget.activeFarmId,
    );
    _fawService = MunicipalFawService(
      municipality: LocationConstants.defaultMunicipality,
    );

    _netIncomeStream = _service.getNetIncome();
    _totalYieldStream = _service.getTotalYield();
    _activeCyclesStream = _service.getActiveCycles();
    _fieldsFuture = _service.getFields();
    _fawStream = _fawService.watchFawAssessment();
    _activityStream = _service.getRecentActivityLogs(limit: 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              key: _kpiCaptureKey,
              child: Column(
                children: [
                  // ----- Top Metrics: NET INCOME & TOTAL YIELD -----
                  Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<double>(
                          stream: _netIncomeStream,
                          builder: (ctx, snapshot) {
                            final total = snapshot.data ?? 0.0;
                            _incomeReady =
                                snapshot.hasData && !snapshot.hasError;
                            _scheduleWidgetUpdate();

                            return _buildMetricCard(
                              title: "NET INCOME",
                              prefix: '\u20b1',
                              value: _formatNetIncome(total),
                              icon: Icons.payments_outlined,
                              bgColor: darkGreen,
                              textColor: Colors.white,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<double>(
                          stream: _totalYieldStream,
                          builder: (ctx, snapshot) {
                            final totalYield = snapshot.data ?? 0.0;
                            _yieldReady =
                                snapshot.hasData && !snapshot.hasError;
                            _scheduleWidgetUpdate();

                            return _buildMetricCard(
                              title: "TOTAL YIELD",
                              value: totalYield.toStringAsFixed(1),
                              unit: "kg",
                              icon: Icons.agriculture_rounded,
                              bgColor: const Color(0xFFC5E1A5),
                              textColor: darkGreen,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // ----- Active Cycle & Field Count -----
                  FutureBuilder<List<FieldModel>>(
                    future: _fieldsFuture,
                    builder: (ctx, fieldSnapshot) {
                      _fieldsReady =
                          fieldSnapshot.hasData && !fieldSnapshot.hasError;
                      final fieldCount = fieldSnapshot.data?.length ?? 0;
                      return StreamBuilder<List<CycleModel>>(
                        stream: _activeCyclesStream,
                        builder: (ctx, cycleSnapshot) {
                          _cyclesReady =
                              cycleSnapshot.hasData && !cycleSnapshot.hasError;
                          _scheduleWidgetUpdate();
                          final cycles = cycleSnapshot.data ?? [];
                          final activeCycleCount = cycles.length;
                          return Row(
                            children: [
                              Expanded(
                                child: _buildSmallMetricCard(
                                  "ACTIVE CYCLES",
                                  activeCycleCount.toString(),
                                  "",
                                  const Color(0xFF7BC72E).withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildSmallMetricCard(
                                  "FIELD COUNT",
                                  fieldCount.toString(),
                                  "",
                                  const Color(0xFFF7E594),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AllFarmsDataScreen(userId: widget.userId),
                    ),
                  );
                },
                icon: const Icon(Icons.dashboard_customize_outlined),
                label: const Text('VIEW ALL FARM DATA'),
                style: FilledButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // ----- FAW Assessment Section -----
            Text(
              "FAW Assessment",
              style: GoogleFonts.epilogue(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: headingBlack,
              ),
            ),
            Text(
              "Validated FAW life stages in ${LocationConstants.defaultMunicipality}",
              style: GoogleFonts.manrope(
                fontSize: 16,
                color: textGray,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<FawLifeStageReport>>(
              stream: _fawStream,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: darkGreen,
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Regional information is unavailable. This does not mean there are no pest reports.'),
                      TextButton.icon(
                        onPressed: () => setState(() => _fawStream = _fawService.watchFawAssessment()),
                        style: TextButton.styleFrom(foregroundColor: darkGreen),
                        icon: const Icon(Icons.refresh), label: const Text('Try again'),
                      ),
                    ]),
                  );
                }
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      "No validated FAW life stages recorded yet in this municipality",
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(padding: EdgeInsets.only(bottom: 12),
                      child: Text('Regional overview updates about every 5 minutes.')),
                    ...reports
                      .map((report) => _buildFawStageCard(report)),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),

            // ----- Recent Activity Section -----
            Text(
              'Recent Activity',
              style: GoogleFonts.epilogue(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: headingBlack,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<ActivityFeedItem>>(
              stream: _activityStream,
              builder: (ctx, snapshot) {
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No recent activity"),
                  );
                }
                return Column(
                  children: items
                      .map((item) => _buildActivityCardFromFeedItem(item))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ----- FAW Life Stage Card (life stage -> barangay -> count) -----
  Widget _buildFawStageCard(FawLifeStageReport report) {
    final accent = _fawStageColor(report.stage);
    final barangayCount = report.findings.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _fawStageIcon(report.stage),
                  color: accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.stage.label.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: headingBlack,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.total} found across $barangayCount barangay${barangayCount == 1 ? '' : 's'}',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: textGray,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${report.total}',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (report.findings.isNotEmpty) ...[
            const SizedBox(height: 4),
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                key: PageStorageKey('faw-barangays-${report.stage.name}'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: const EdgeInsets.only(top: 4),
                shape: const Border(),
                collapsedShape: const Border(),
                iconColor: darkGreen,
                collapsedIconColor: darkGreen,
                expansionAnimationStyle:
                    MediaQuery.of(context).disableAnimations
                    ? AnimationStyle.noAnimation
                    : null,
                title: Text(
                  'Barangays ($barangayCount)',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: darkGreen,
                  ),
                ),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final minColumnWidth = MediaQuery.textScalerOf(
                        context,
                      ).scale(140);
                      final columns =
                          constraints.maxWidth >= minColumnWidth * 2 + 8
                          ? 2
                          : 1;
                      final itemWidth =
                          (constraints.maxWidth - (columns - 1) * 8) / columns;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: report.findings
                            .map(
                              (finding) => SizedBox(
                                width: itemWidth,
                                child: _buildFawFindingRow(finding, accent),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFawFindingRow(FawBarangayFinding finding, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  finding.barangay,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: headingBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${finding.count}',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: headingBlack,
                  ),
                ),
                TextSpan(
                  text: ' found',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _fawStageIcon(FawLifeStage stage) {
    switch (stage) {
      case FawLifeStage.egg:
        return Icons.circle;
      case FawLifeStage.larva:
        return Icons.bug_report;
      case FawLifeStage.pupa:
        return Icons.coffee;
      case FawLifeStage.moth:
        return Icons.flutter_dash;
    }
  }

  Color _fawStageColor(FawLifeStage stage) {
    switch (stage) {
      case FawLifeStage.egg:
        return const Color(0xFFE91E63);
      case FawLifeStage.larva:
        return const Color(0xFFF57C00);
      case FawLifeStage.pupa:
        return const Color(0xFF7E57C2);
      case FawLifeStage.moth:
        return const Color(0xFF1B5E37);
    }
  }

  // ----- Activity Card from the unified activity feed -----
  Widget _buildActivityCardFromFeedItem(ActivityFeedItem item) {
    final icon = _activityIcon(item);
    final iconBg = _activityIconBg(item);
    final tag = item.cycleName ?? item.fieldName;

    return _buildActivityCard(
      item.title,
      item.subtitle,
      _relativeTime(item.timestamp),
      icon,
      iconBg,
      tag: tag,
    );
  }

  IconData _activityIcon(ActivityFeedItem item) {
    switch (item.kind) {
      case ActivityFeedKind.scouting:
        return Icons.pest_control_outlined;
      case ActivityFeedKind.pestReport:
        return Icons.bug_report;
      case ActivityFeedKind.dailyLog:
        break;
    }

    final title = item.title.toLowerCase();
    if (title.contains('water')) return Icons.water_drop;
    if (title.contains('fertiliz')) return Icons.center_focus_strong;
    if (title.contains('scout')) return Icons.pest_control_outlined;
    if (title.contains('harvest')) return Icons.agriculture_outlined;
    if (title.contains('chemical')) return Icons.science_outlined;
    return Icons.assignment_outlined;
  }

  Color _activityIconBg(ActivityFeedItem item) {
    switch (item.kind) {
      case ActivityFeedKind.scouting:
        return const Color(0xFFEDE7F6);
      case ActivityFeedKind.pestReport:
        return const Color(0xFFFDE7E7);
      case ActivityFeedKind.dailyLog:
        break;
    }

    final title = item.title.toLowerCase();
    if (title.contains('water')) return const Color(0xFFE4F8E5);
    if (title.contains('fertiliz')) return const Color(0xFFEBE8B3);
    if (title.contains('scout')) return const Color(0xFFEDE7F6);
    if (title.contains('harvest')) return const Color(0xFFFFF3E0);
    if (title.contains('chemical')) return const Color(0xFFEBE8B3);
    return Colors.grey.shade200;
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}D AGO';
    if (diff.inHours > 0) return '${diff.inHours}H AGO';
    if (diff.inMinutes > 0) return '${diff.inMinutes}M AGO';
    return 'NOW';
  }

  // ----- Your existing UI components (unchanged, just pasted) -----

  String _formatNetIncome(double amount) {
    const suffixes = ['', 'k', 'm', 'b', 't'];
    var scaled = amount;
    var suffixIndex = 0;
    while (scaled.abs() >= 1000 && suffixIndex < suffixes.length - 1) {
      scaled /= 1000;
      suffixIndex++;
    }
    // Promote values that round to the next unit, e.g. 999.999k -> 1m.
    if (double.parse(scaled.toStringAsFixed(2)).abs() >= 1000 &&
        suffixIndex < suffixes.length - 1) {
      scaled /= 1000;
      suffixIndex++;
    }
    final number = scaled
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'\.?0+$'), '');
    return '$number${suffixes[suffixIndex]}';
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String prefix = '',
    String? unit,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 24),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.manrope(
              color: textColor.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$prefix$value',
                    style: GoogleFonts.manrope(
                      color: textColor,
                      fontSize: prefix.isEmpty ? 32 : 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.manrope(
                    color: textColor.withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard(
    String title,
    String value,
    String unit,
    Color color,
  ) {
    IconData displayIcon = title.contains("CYCLE")
        ? Icons.stacked_line_chart_rounded
        : Icons.grid_view_rounded;

    return Container(
      width: 167,
      height: 131,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              displayIcon,
              size: 18,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF1A1C18),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: GoogleFonts.manrope(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color iconBg, {
    String? tag,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: darkGreen, size: 24),
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
                    fontSize: 16,
                    color: headingBlack,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: textGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (tag != null && tag.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.manrope(
                        color: Colors.grey.shade600,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: GoogleFonts.manrope(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
