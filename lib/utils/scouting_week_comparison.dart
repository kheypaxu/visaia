import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/utils/growth_stage.dart';

Map<String, dynamic> scoutingMap(dynamic value) => value is Map
    ? {
        for (final entry in value.entries)
          if (entry.key is String) entry.key as String: entry.value,
      }
    : {};

double? scoutingNumber(dynamic value) =>
    value is num && value.isFinite && value >= 0 ? value.toDouble() : null;

int? scoutingInt(dynamic value) {
  final number = scoutingNumber(value);
  return number != null && number == number.truncateToDouble()
      ? number.toInt()
      : null;
}

DateTime? scoutingDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String? scoutingId(dynamic value) =>
    value is String && value.trim().isNotEmpty && !value.contains('/')
    ? value.trim()
    : null;

class ScoutingWeekReport {
  final String id;
  final Map<String, dynamic> data;
  ScoutingWeekReport(this.id, Map<String, dynamic> data)
    : data = Map.unmodifiable(data);

  String? get ownerId =>
      scoutingId(data['userId']) ?? scoutingId(data['farmerId']);
  String? get cycleId => scoutingId(data['cycleId']);
  int? get dap => scoutingInt(data['dap']);
  int? get week {
    final explicit = scoutingInt(data['weekNumber']);
    if (explicit != null && explicit >= 1) return explicit;
    return dap == null ? null : dap! ~/ 7 + 1;
  }

  bool get isResolved =>
      data['status']?.toString().trim().toLowerCase() == 'resolved';
  int? get inspected =>
      scoutingInt(data['correctedInspected']) ??
      scoutingInt(data['totalInspected']) ??
      _stationSum('plantsInspected');
  int? get damaged =>
      scoutingInt(data['correctedDamaged']) ??
      scoutingInt(data['totalDamaged']) ??
      _stationSum('damaged');
  double? get damagePercentage {
    final corrected = scoutingNumber(data['correctedDamagePercentage']);
    if (corrected != null) return corrected;
    final hasCorrectedCounts =
        scoutingInt(data['correctedInspected']) != null ||
        scoutingInt(data['correctedDamaged']) != null;
    if (hasCorrectedCounts &&
        inspected != null &&
        inspected! > 0 &&
        damaged != null) {
      return damaged! / inspected! * 100;
    }
    return scoutingNumber(data['damagePercentage']) ??
        (inspected != null && inspected! > 0 && damaged != null
            ? damaged! / inspected! * 100
            : null);
  }

  List<Map<String, dynamic>> get stations => data['stationsData'] is List
      ? (data['stationsData'] as List)
            .whereType<Map>()
            .map(scoutingMap)
            .toList()
      : [];
  int? _stationSum(String key) {
    if (stations.isEmpty) return null;
    final values = stations.map((s) => scoutingInt(s[key])).toList();
    if (values.any((v) => v == null)) return null;
    return values.fold<int>(0, (total, v) => total + v!);
  }

  int? count(String key) =>
      scoutingInt(scoutingMap(data['correctedTotals'])[key]) ??
      scoutingInt(scoutingMap(data['totals'])[key]) ??
      _stationSum(key == 'eggs' ? 'eggMasses' : key);
  String get growthStage =>
      data['growthStage'] is String &&
          (data['growthStage'] as String).trim().isNotEmpty
      ? data['growthStage'] as String
      : (dap == null ? 'Unavailable' : getGrowthStage(dap!).name);
  DateTime? get submittedAt => scoutingDate(data['submittedAt']);
  DateTime? get reportDate =>
      scoutingDate(data['reportDate']) ??
      scoutingDate(data['timestamp']) ??
      submittedAt ??
      scoutingDate(data['createdAt']);
  DateTime? get sortDate =>
      submittedAt ?? scoutingDate(data['createdAt']) ?? reportDate;

  // Classification is distinct from life-stage-specific pest risk.
  String? get savedLevel {
    for (final key in ['reportLevel', 'level']) {
      final value = data[key]
          ?.toString()
          .toLowerCase()
          .replaceAll('-', ' ')
          .trim();
      if (value == 'high' || value == 'high level') return 'High';
      if (value == 'low' || value == 'low level') return 'Low';
    }
    if (data['isHighLevel'] is bool) {
      return data['isHighLevel'] == true ? 'High' : 'Low';
    }
    final severity = data['severityLevel']?.toString().toLowerCase();
    if (severity == 'high level') return 'High';
    if (severity == 'low level') return 'Low';
    if (data['exceedsThreshold'] is bool) {
      return data['exceedsThreshold'] == true ? 'High' : 'Low';
    }
    return null;
  }

  String? get level =>
      savedLevel ??
      (damagePercentage == null
          ? null
          : (damagePercentage! >= 10 ? 'High' : 'Low'));

  bool get levelIsEstimated => savedLevel == null;
  String get severity =>
      (data['correctedRisk'] ??
              data['riskLevel'] ??
              data['severityLevel'] ??
              level ??
              'Unavailable')
          .toString();
}

/// Missing weeks never shift the comparison to an earlier available report.
ScoutingWeekReport? previousScoutingWeek(
  ScoutingWeekReport current,
  Iterable<ScoutingWeekReport> candidates,
) {
  if (current.week == null ||
      current.week! <= 1 ||
      current.ownerId == null ||
      current.cycleId == null) {
    return null;
  }
  final matches = candidates
      .where(
        (r) =>
            r.ownerId == current.ownerId &&
            r.cycleId == current.cycleId &&
            r.week == current.week! - 1,
      )
      .toList();
  matches.sort((a, b) {
    final time = (b.sortDate?.millisecondsSinceEpoch ?? 0).compareTo(
      a.sortDate?.millisecondsSinceEpoch ?? 0,
    );
    return time != 0 ? time : a.id.compareTo(b.id);
  });
  return matches.isEmpty ? null : matches.first;
}

class ScoutingDelta {
  final String label;
  final double? previous, current;
  final String unit;
  final bool neutral;
  const ScoutingDelta(
    this.label,
    this.previous,
    this.current, {
    this.unit = '',
    this.neutral = false,
  });
  double? get change =>
      previous == null || current == null ? null : current! - previous!;
  String get direction => change == null
      ? 'Unavailable'
      : change == 0
      ? 'No change'
      : neutral
      ? (change! > 0 ? '▲ more inspected' : '▼ fewer inspected')
      : (change! > 0 ? '▲ worse' : '▼ better');
}

List<ScoutingDelta> scoutingDeltas(
  ScoutingWeekReport current,
  ScoutingWeekReport? previous,
) {
  if (!current.isResolved || previous == null) return [];
  return [
    ScoutingDelta(
      'Damage',
      previous.damagePercentage,
      current.damagePercentage,
      unit: ' pp',
    ),
    for (final key in ['eggs', 'larvae', 'pupae', 'moths'])
      ScoutingDelta(
        key[0].toUpperCase() + key.substring(1),
        previous.count(key)?.toDouble(),
        current.count(key)?.toDouble(),
      ),
    ScoutingDelta(
      'Inspected',
      previous.inspected?.toDouble(),
      current.inspected?.toDouble(),
      neutral: true,
    ),
    ScoutingDelta(
      'Damaged',
      previous.damaged?.toDouble(),
      current.damaged?.toDouble(),
    ),
  ];
}
