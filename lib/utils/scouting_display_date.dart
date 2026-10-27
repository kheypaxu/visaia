import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseScoutingDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } on ArgumentError {
      return null;
    }
  }
  return null;
}

int? _integer(Object? value) {
  if (value is num && value.isFinite && value >= 0) return value.toInt();
  if (value is String) {
    final match = RegExp(
      r'^(?:Week\s*|DAP\s*)?(\d+)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match != null) return int.tryParse(match.group(1)!);
  }
  return null;
}

/// Calendar date shown by both scouting-history cards and report details.
/// Separate from scoutingReportDate, which preserves on-time submission times.
DateTime resolveScoutingDisplayDate(
  Map<String, dynamic> data, {
  DateTime? cyclePlantingDate,
  DateTime? now,
}) {
  final cycleInfo = data['cycleInfo'];
  final planting =
      parseScoutingDate(data['plantingDate']) ??
      cyclePlantingDate ??
      (cycleInfo is Map ? parseScoutingDate(cycleInfo['plantingDate']) : null);
  DateTime? fallback;
  for (final key in [
    'reportDate',
    'timestamp',
    'createdAt',
    'submittedAt',
    'dateConducted',
    'scoutingDate',
  ]) {
    fallback = parseScoutingDate(data[key]);
    if (fallback != null) break;
  }
  final week = _integer(data['weekNumber']);
  final dap = _integer(data['dap']);
  final effectivePlanting =
      planting ??
      (fallback != null && dap != null
          ? DateTime(fallback.year, fallback.month, fallback.day - dap)
          : null);
  final weekIndex = week != null && week >= 1
      ? week - 1
      : dap == null
      ? null
      : dap ~/ 7;
  if (effectivePlanting != null && weekIndex != null) {
    return DateTime(
      effectivePlanting.year,
      effectivePlanting.month,
      effectivePlanting.day + (weekIndex + 1) * 7,
    ).subtract(const Duration(microseconds: 1));
  }
  return fallback ?? now ?? DateTime.now();
}
