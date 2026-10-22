import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/detection_weather_service.dart';
import 'package:visaia/services/report_map_location_resolver.dart';

/// The five level risk gradient shared by the web dashboard risk map and
/// this mobile risk map.
///
///   Very High > High > Moderate > Low > Very Low
enum RiskLevel {
  veryLow('Very Low', 1, Color(0xFF22C55E)),
  low('Low', 2, Color(0xFF3B82F6)),
  moderate('Moderate', 3, Color(0xFFEAB308)),
  high('High', 4, Color(0xFFEF4444)),
  veryHigh('Very High', 5, Color(0xFFB91C1C));

  const RiskLevel(this.label, this.weight, this.color);

  final String label;
  final int weight;
  final Color color;

  /// Normalizes any risk spelling used across the app / dashboard
  /// (`High`, `high`, `critical`, `very high`, `medium`, ...) into the
  /// five level gradient.
  static RiskLevel normalize(dynamic raw) {
    if (raw is! String) return RiskLevel.low;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return RiskLevel.low;
    if (s.contains('very high') ||
        s.contains('veryhigh') ||
        s.contains('critical') ||
        s.contains('severe')) {
      return RiskLevel.veryHigh;
    }
    if (s.contains('high')) return RiskLevel.high;
    if (s.contains('moderate') || s.contains('medium')) {
      return RiskLevel.moderate;
    }
    if (s.contains('very low') || s.contains('verylow')) {
      return RiskLevel.veryLow;
    }
    if (s.contains('low')) return RiskLevel.low;
    return RiskLevel.low;
  }

  /// The higher of the two levels.
  static RiskLevel maxOf(RiskLevel a, RiskLevel b) =>
      a.weight >= b.weight ? a : b;
}

/// The corn growth stage columns used by Table 1 of the FAW guidelines.
enum MatrixGrowthStage {
  seedling('Seedling'),
  earlyWhorl('Early Whorl'),
  lateWhorl('Late Whorl'),
  tasselingSilking('Tasseling-Silking'),
  grainFilling('Grain Filling'),
  maturity('Maturity');

  const MatrixGrowthStage(this.label);

  final String label;

  static MatrixGrowthStage fromDap(int dap) {
    if (dap <= 14) return MatrixGrowthStage.seedling;
    if (dap <= 30) return MatrixGrowthStage.earlyWhorl;
    if (dap <= 45) return MatrixGrowthStage.lateWhorl;
    if (dap <= 55) return MatrixGrowthStage.tasselingSilking;
    if (dap <= 75) return MatrixGrowthStage.grainFilling;
    return MatrixGrowthStage.maturity;
  }
}

/// The life stage keys used by Table 1.
enum FawStageKey {
  egg('Egg Masses'),
  larva('Larvae'),
  pupa('Pupae'),
  moth('Adult Moths'),
  none('Unidentified');

  const FawStageKey(this.label);

  final String label;

  static FawStageKey fromText(dynamic raw) {
    if (raw is! String) return FawStageKey.none;
    final s = raw.toLowerCase().trim();
    if (s.isEmpty) return FawStageKey.none;
    if (s.contains('egg')) return FawStageKey.egg;
    if (s.contains('larva') || s.contains('caterpillar')) {
      return FawStageKey.larva;
    }
    if (s.contains('pupa')) return FawStageKey.pupa;
    if (s.contains('moth') || s.contains('adult')) return FawStageKey.moth;
    return FawStageKey.none;
  }
}

/// Table 1 - FAW life stage x corn growth stage risk gradient.
const Map<FawStageKey, Map<MatrixGrowthStage, RiskLevel>> kFawRiskMatrix = {
  FawStageKey.egg: {
    MatrixGrowthStage.seedling: RiskLevel.low,
    MatrixGrowthStage.earlyWhorl: RiskLevel.moderate,
    MatrixGrowthStage.lateWhorl: RiskLevel.moderate,
    MatrixGrowthStage.tasselingSilking: RiskLevel.low,
    MatrixGrowthStage.grainFilling: RiskLevel.low,
    MatrixGrowthStage.maturity: RiskLevel.veryLow,
  },
  FawStageKey.larva: {
    MatrixGrowthStage.seedling: RiskLevel.moderate,
    MatrixGrowthStage.earlyWhorl: RiskLevel.high,
    MatrixGrowthStage.lateWhorl: RiskLevel.veryHigh,
    MatrixGrowthStage.tasselingSilking: RiskLevel.veryHigh,
    MatrixGrowthStage.grainFilling: RiskLevel.high,
    MatrixGrowthStage.maturity: RiskLevel.low,
  },
  FawStageKey.pupa: {
    MatrixGrowthStage.seedling: RiskLevel.veryLow,
    MatrixGrowthStage.earlyWhorl: RiskLevel.veryLow,
    MatrixGrowthStage.lateWhorl: RiskLevel.veryLow,
    MatrixGrowthStage.tasselingSilking: RiskLevel.low,
    MatrixGrowthStage.grainFilling: RiskLevel.moderate,
    MatrixGrowthStage.maturity: RiskLevel.low,
  },
  FawStageKey.moth: {
    MatrixGrowthStage.seedling: RiskLevel.low,
    MatrixGrowthStage.earlyWhorl: RiskLevel.high,
    MatrixGrowthStage.lateWhorl: RiskLevel.high,
    MatrixGrowthStage.tasselingSilking: RiskLevel.moderate,
    MatrixGrowthStage.grainFilling: RiskLevel.low,
    MatrixGrowthStage.maturity: RiskLevel.veryLow,
  },
  FawStageKey.none: {
    MatrixGrowthStage.seedling: RiskLevel.veryLow,
    MatrixGrowthStage.earlyWhorl: RiskLevel.veryLow,
    MatrixGrowthStage.lateWhorl: RiskLevel.veryLow,
    MatrixGrowthStage.tasselingSilking: RiskLevel.veryLow,
    MatrixGrowthStage.grainFilling: RiskLevel.veryLow,
    MatrixGrowthStage.maturity: RiskLevel.veryLow,
  },
};

/// Risk for a single life stage at a given crop growth stage.
RiskLevel riskForStage(FawStageKey stage, MatrixGrowthStage growthStage) =>
    kFawRiskMatrix[stage]?[growthStage] ?? RiskLevel.low;

/// A pest detection that can threaten the user's farm.
class FawThreat {
  final String id;

  /// `true` for `clustered_reports` (weekly scouting), `false` for `reports`.
  final bool isClustered;

  final LatLng location;
  final String areaName;
  final String barangay;
  final String farmerName;
  final String farmName;
  final String fieldName;
  final String detection;
  final FawStageKey stage;
  final RiskLevel riskLevel;
  final int dap;
  final MatrixGrowthStage growthStage;

  final int eggs;
  final int larvae;
  final int pupae;
  final int moths;

  final double damagePercentage;
  final bool thresholdReached;

  final String? mitigationAction;
  final String? advisoryMessage;
  final String? controlMethod;
  final String? expertDiagnosis;
  final String? analysis;
  final String? treatment;

  final DateTime? timestamp;

  /// Owner of the report (uid).
  final String ownerId;

  /// Distance in kilometres from the user's nearest field.
  double distanceKm;

  /// The wind assisted monitoring radius in metres (5 km base, up to 10 km
  /// when the wind at the detection point was strong).
  double radiusM = FawRiskService.mothRadiusKm * 1000;

  /// km/h wind recorded at the detection point, when available.
  double? windSpeedKmh;

  FawThreat({
    required this.id,
    required this.isClustered,
    required this.location,
    required this.areaName,
    required this.barangay,
    required this.farmerName,
    required this.farmName,
    required this.fieldName,
    required this.detection,
    required this.stage,
    required this.riskLevel,
    required this.dap,
    required this.growthStage,
    required this.eggs,
    required this.larvae,
    required this.pupae,
    required this.moths,
    required this.damagePercentage,
    required this.thresholdReached,
    required this.mitigationAction,
    required this.advisoryMessage,
    required this.controlMethod,
    required this.expertDiagnosis,
    required this.analysis,
    required this.treatment,
    required this.timestamp,
    required this.ownerId,
    required this.distanceKm,
  });

  int get totalPests => eggs + larvae + pupae + moths;

  bool get hasMoths => moths > 0 || stage == FawStageKey.moth;

  /// The life stage pin to use for this threat.
  String get pinAsset {
    if (isClustered) return 'assets/images/map/clustered_report.png';
    switch (stage) {
      case FawStageKey.egg:
        return 'assets/images/map/egg.png';
      case FawStageKey.larva:
        return 'assets/images/map/larva.png';
      case FawStageKey.pupa:
        return 'assets/images/map/pupa.png';
      case FawStageKey.moth:
        return 'assets/images/map/moth.png';
      case FawStageKey.none:
        return 'assets/images/map/clustered_report.png';
    }
  }

  /// Mitigation steps, ordered from the most actionable to the most detailed.
  List<({String title, String body})> get mitigationSteps {
    final steps = <({String title, String body})>[];
    void add(String title, String? body) {
      final text = (body ?? '').trim();
      if (text.isEmpty) return;
      steps.add((title: title, body: text));
    }

    add('Recommended action', mitigationAction);
    add('Advisory', advisoryMessage);
    add('Control method', controlMethod);
    add('Treatment plan', treatment);
    add('Field assessment', expertDiagnosis);
    add('Analysis', analysis);
    return steps;
  }
}

/// Loads nearby FAW threats (moth bearing reports and weekly scouting
/// records) that can reach the user's farm by adult moth flight.
class FawRiskService {
  final FirebaseFirestore _db;
  final DetectionWeatherService _weatherService;

  /// Adult moth flight radius used for the proximity monitoring zone.
  static const double mothRadiusKm = 5.0;

  /// Maximum number of documents read per collection.
  static const int _maxDocs = 250;

  FawRiskService({FirebaseFirestore? db, DetectionWeatherService? weatherService})
      : _db = db ?? FirebaseFirestore.instance,
        _weatherService = weatherService ?? DetectionWeatherService();

  /// Loads every moth bearing detection (own + neighbouring farms) and keeps
  /// the ones that fall inside the moth proximity zone of [anchors].
  Future<List<FawThreat>> loadMothThreats({
    required String currentUserId,
    required List<LatLng> anchors,
    double radiusKm = mothRadiusKm,
  }) async {
    final threats = <FawThreat>[];

    try {
      final clustered = await _db
          .collection('clustered_reports')
          .where('totals.moths', isGreaterThan: 0)
          .limit(_maxDocs)
          .get();
      for (final doc in clustered.docs) {
        final threat = _parseClustered(doc);
        if (threat != null) threats.add(threat);
      }
    } catch (e) {
      debugPrint('FawRiskService: clustered_reports query failed: $e');
      // Fall back to an unfiltered scan when the nested filter is not
      // available (missing index / field on legacy documents).
      try {
        final all = await _db
            .collection('clustered_reports')
            .limit(_maxDocs)
            .get();
        for (final doc in all.docs) {
          final threat = _parseClustered(doc);
          if (threat != null) threats.add(threat);
        }
      } catch (e2) {
        debugPrint('FawRiskService: clustered_reports fallback failed: $e2');
      }
    }

    final reportLocations = ReportMapLocationResolver(db: _db);
    try {
      final reports = await _db
          .collection('reports')
          .where('lifeStage', isEqualTo: 'moth')
          .limit(_maxDocs)
          .get();
      for (final doc in reports.docs) {
        final threat = await _parseReport(doc, reportLocations);
        if (threat != null) threats.add(threat);
      }
    } catch (e) {
      debugPrint('FawRiskService: reports query failed: $e');
      try {
        final all = await _db.collection('reports').limit(_maxDocs).get();
        for (final doc in all.docs) {
          final threat = await _parseReport(doc, reportLocations);
          if (threat != null) threats.add(threat);
        }
      } catch (e2) {
        debugPrint('FawRiskService: reports fallback failed: $e2');
      }
    }

    // Own regular reports are already drawn by the risk map report layer.
    threats.removeWhere(
        (t) => !t.isClustered && t.ownerId == currentUserId && t.ownerId.isNotEmpty);

    // Proximity filter against the user's own fields.
    final distance = const Distance();
    for (final threat in threats) {
      if (anchors.isEmpty) continue;
      var closest = double.infinity;
      for (final anchor in anchors) {
        final km = distance.as(LengthUnit.Kilometer, anchor, threat.location);
        if (km < closest) closest = km;
      }
      threat.distanceKm = closest;
    }

    if (anchors.isNotEmpty) {
      // Keep the candidates that could still reach the farm once the zone is
      // scaled by the wind (5 km base, up to 10 km in strong wind).
      final maxRadiusKm =
          radiusKm * DetectionWeatherService.mothMaxMultiplier;
      threats.removeWhere((t) => t.distanceKm > maxRadiusKm);

      // Resolve the wind recorded at each detection point so the monitoring
      // zone matches the dashboard.
      final withDate = threats
          .where((t) => t.timestamp != null)
          .map((t) => (
                lat: t.location.latitude,
                lng: t.location.longitude,
                date: t.timestamp!,
              ))
          .toList();

      if (withDate.isNotEmpty) {
        final weatherList = await _weatherService.fetchBatch(withDate);
        var cursor = 0;
        for (final threat in threats) {
          if (threat.timestamp == null) {
            threat.radiusM = radiusKm * 1000;
            continue;
          }
          final weather = weatherList[cursor++];
          threat.radiusM = DetectionWeatherService.mothRadiusMeters(weather);
          threat.windSpeedKmh = weather?.windSpeed;
        }
      }

      // Final filter: the detection must be inside its own monitoring zone.
      threats.removeWhere((t) => t.distanceKm * 1000 > t.radiusM);
    }

    threats.sort((a, b) {
      final byRisk = b.riskLevel.weight.compareTo(a.riskLevel.weight);
      if (byRisk != 0) return byRisk;
      return a.distanceKm.compareTo(b.distanceKm);
    });

    return threats;
  }

  // ------------------------------------------------------------------
  // Parsing
  // ------------------------------------------------------------------

  FawThreat? _parseClustered(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final location = _extractLocation(data);
    if (location == null) return null;

    final totals = _asMap(data['totals']);
    final moths = _asInt(totals?['moths']);
    if (moths <= 0) return null;

    final eggs = _asInt(totals?['eggs']);
    final larvae = _asInt(totals?['larvae']);
    final pupae = _asInt(totals?['pupae']);

    final dap = _asInt(data['dap']);
    final growthStage = MatrixGrowthStage.fromDap(dap);
    final damagePercentage = _asDouble(data['damagePercentage']);
    final thresholdReached = data['exceedsThreshold'] == true ||
        data['isHighLevel'] == true ||
        data['thresholdTriggered'] == true ||
        damagePercentage >= 10.0;

    final risk = _compositeRisk(
      eggs: eggs,
      larvae: larvae,
      pupae: pupae,
      moths: moths,
      dap: dap,
      growthStage: growthStage,
      damagePercentage: damagePercentage,
      thresholdReached: thresholdReached,
      storedRisk: data['riskLevel'] ?? data['risk'] ?? data['level'],
    );

    return FawThreat(
      id: doc.id,
      isClustered: true,
      location: location,
      areaName: (data['areaName'] ?? '').toString(),
      barangay: (data['barangay'] ?? '').toString(),
      farmerName: (data['farmerName'] ?? '').toString(),
      farmName: (data['farmName'] ?? '').toString(),
      fieldName: (data['fieldName'] ?? '').toString(),
      detection: (data['expertDiagnosis'] ?? 'Fall Army Worm').toString(),
      stage: FawStageKey.moth,
      riskLevel: risk,
      dap: dap,
      growthStage: growthStage,
      eggs: eggs,
      larvae: larvae,
      pupae: pupae,
      moths: moths,
      damagePercentage: damagePercentage,
      thresholdReached: thresholdReached,
      mitigationAction: _asString(data['mitigationAction']),
      advisoryMessage: _asString(data['advisoryMessage']),
      controlMethod: _asString(data['controlMethod']),
      expertDiagnosis: _asString(data['expertDiagnosis']),
      analysis: _asString(data['analysis']),
      treatment: _asString(data['treatment']),
      timestamp: _parseDateTime(data['timestamp']) ??
          _parseDateTime(data['createdAt']) ??
          _parseDateTime(data['submittedAt']),
      ownerId: (data['userId'] ?? data['farmerId'] ?? '').toString(),
      distanceKm: double.infinity,
    );
  }

  Future<FawThreat?> _parseReport(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ReportMapLocationResolver locations) async {
    final data = doc.data();

    final stage = FawStageKey.fromText(
        data['lifeStage'] ?? data['stage'] ?? data['finalValidatedLifeStage']);
    if (stage != FawStageKey.moth) return null;

    final location = await locations.resolve(data);
    if (location == null) return null;

    final dap = _asInt(data['dap']);
    final growthStage = MatrixGrowthStage.fromDap(dap);
    final damagePercentage = _asDouble(data['damagePercentage']);
    final thresholdReached = data['exceedsThreshold'] == true ||
        data['isHighLevel'] == true ||
        damagePercentage >= 10.0;

    final risk = _compositeRisk(
      eggs: 0,
      larvae: 0,
      pupae: 0,
      moths: 1,
      dap: dap,
      growthStage: growthStage,
      damagePercentage: damagePercentage,
      thresholdReached: thresholdReached,
      storedRisk: data['risk'] ?? data['riskLevel'],
    );

    return FawThreat(
      id: doc.id,
      isClustered: false,
      location: location,
      areaName: (data['areaName'] ?? '').toString(),
      barangay: (data['barangay'] ?? '').toString(),
      farmerName: (data['farmerName'] ?? '').toString(),
      farmName: (data['farmName'] ?? '').toString(),
      fieldName: (data['fieldName'] ?? '').toString(),
      detection: (data['detection'] ?? data['pestName'] ?? 'Fall Army Worm')
          .toString(),
      stage: stage,
      riskLevel: risk,
      dap: dap,
      growthStage: growthStage,
      eggs: 0,
      larvae: 0,
      pupae: 0,
      moths: 1,
      damagePercentage: damagePercentage,
      thresholdReached: thresholdReached,
      mitigationAction: _asString(data['mitigationAction']),
      advisoryMessage: _asString(data['advisoryMessage']),
      controlMethod: _asString(data['controlMethod']),
      expertDiagnosis: _asString(data['expertDiagnosis']),
      analysis: _asString(data['analysis']),
      treatment: _asString(data['treatment']),
      timestamp: _parseDateTime(data['timestamp']) ??
          _parseDateTime(data['createdAt']),
      ownerId: (data['farmerId'] ?? data['userId'] ?? '').toString(),
      distanceKm: double.infinity,
    );
  }

  /// Composite risk for a detection, mirroring the dashboard risk engine:
  /// life stage x growth stage matrix, then the 10% damage threshold
  /// escalation, then any stored risk level.
  RiskLevel _compositeRisk({
    required int eggs,
    required int larvae,
    required int pupae,
    required int moths,
    required int dap,
    required MatrixGrowthStage growthStage,
    required double damagePercentage,
    required bool thresholdReached,
    required dynamic storedRisk,
  }) {
    var highest = RiskLevel.veryLow;

    void consider(FawStageKey stage) {
      highest = RiskLevel.maxOf(highest, riskForStage(stage, growthStage));
    }

    if (larvae > 0) consider(FawStageKey.larva);
    if (moths > 0) consider(FawStageKey.moth);
    if (eggs > 0) consider(FawStageKey.egg);
    if (pupae > 0) consider(FawStageKey.pupa);

    // Adult moths are winged dispersers: any moth detection is at least a
    // High risk for a neighbouring farm, 5+ moths is a Very High threat.
    if (moths > 0) {
      highest = RiskLevel.maxOf(highest, RiskLevel.high);
      if (moths >= 5) highest = RiskLevel.maxOf(highest, RiskLevel.veryHigh);
    }

    // 10% plant damage action threshold.
    if (thresholdReached) {
      final isCriticalStage = growthStage == MatrixGrowthStage.lateWhorl ||
          growthStage == MatrixGrowthStage.tasselingSilking;
      if (isCriticalStage || damagePercentage >= 20.0) {
        highest = RiskLevel.maxOf(highest, RiskLevel.veryHigh);
      } else {
        highest = RiskLevel.maxOf(highest, RiskLevel.high);
      }
    }

    // A stored risk level can raise (never lower) the computed risk.
    if (storedRisk != null && storedRisk.toString().trim().isNotEmpty) {
      highest = RiskLevel.maxOf(highest, RiskLevel.normalize(storedRisk));
    }

    return highest;
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  LatLng? _extractLocation(Map<String, dynamic> data) {
    final location = data['location'];
    if (location is Map) {
      final lat = _asDouble(location['lat']);
      final lng = _asDouble(location['lng']);
      if (lat != 0 || lng != 0) return LatLng(lat, lng);
    }
    final lat = _asDouble(data['lat']);
    final lng = _asDouble(data['lng']);
    if (lat != 0 || lng != 0) return LatLng(lat, lng);
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String? _asString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Formats a distance for display.
String formatKm(double km) {
  if (!km.isFinite) return '—';
  if (km < 1) return '${(km * 1000).round()} m';
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

/// Simple 2D point-in-polygon test used to check whether a report falls
/// inside one of the user's own fields.
bool isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
  if (polygon.length < 3) return false;
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].latitude;
    final yi = polygon[i].longitude;
    final xj = polygon[j].latitude;
    final yj = polygon[j].longitude;
    final intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
        (point.latitude <
            (xj - xi) * (point.longitude - yi) / (yj - yi) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

/// Approximate centre of a polygon.
LatLng polygonCenter(List<LatLng> points) {
  if (points.isEmpty) return const LatLng(0, 0);
  var lat = 0.0;
  var lng = 0.0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}
