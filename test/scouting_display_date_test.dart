import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/screens/report_history/report_history.dart';
import 'package:visaia/services/scouting_date_context.dart';
import 'package:visaia/utils/scouting_display_date.dart';

void main() {
  final planting = DateTime(2026, 10, 1);
  final weekThreeEnd = DateTime(2026, 10, 21, 23, 59, 59, 999, 999);

  test(
    'card uses the same week-end date as details instead of old report timestamp',
    () async {
      final raw = <String, dynamic>{
        'userId': 'owner',
        'cycleId': 'cycle',
        'weekNumber': 3,
        'dap': 20,
        'reportDate': Timestamp.fromDate(DateTime(2026, 9, 20)),
      };
      final reads = <String>[];
      final context = ScoutingDateContext(
        read: (path) async {
          reads.add(path);
          return {'plantingDate': Timestamp.fromDate(planting)};
        },
      );
      final enriched = await context.withPlantingDate(raw);
      final item = UnifiedReportItem.fromClusteredReport('report', enriched);
      expect(item.timestamp, weekThreeEnd);
      expect(item.timestamp, resolveScoutingDisplayDate(enriched));
      expect(item.rawData['plantingDate'], Timestamp.fromDate(planting));
      expect(reads, ['users/owner/cycles/cycle']);
      expect(raw.containsKey('plantingDate'), isFalse);
    },
  );

  test(
    'DAP-only week boundaries are zero based and cross months correctly',
    () {
      for (final (dap, day) in [
        (0, 7),
        (6, 7),
        (7, 14),
        (13, 14),
        (14, 21),
        (20, 21),
        (28, 4),
      ]) {
        final actual = resolveScoutingDisplayDate({
          'plantingDate': planting,
          'dap': dap,
        });
        expect(actual.day, day);
        expect(actual.month, dap == 28 ? 11 : 10);
        expect(actual.hour, 23);
        expect(actual.minute, 59);
      }
    },
  );

  test(
    'explicit week and embedded cycle planting date work with legacy fields',
    () {
      expect(
        resolveScoutingDisplayDate({
          'cycleInfo': {'plantingDate': planting.toIso8601String()},
          'weekNumber': 'Week 3',
          'dap': 'DAP 7',
          'reportDate': '2026-09-20',
        }),
        weekThreeEnd,
      );
      expect(
        resolveScoutingDisplayDate({
          'plantingDate': planting.millisecondsSinceEpoch,
          'weekNumber': 3,
        }),
        weekThreeEnd,
      );
    },
  );

  test(
    'unavailable cycle context uses valid stored fallback without fixed dates',
    () async {
      final data = <String, dynamic>{
        'farmerId': 'owner',
        'cycleId': 'missing',
        'reportDate': 'bad',
        'timestamp': '2026-11-09',
      };
      final context = ScoutingDateContext(
        read: (_) async => throw Exception('offline'),
      );
      final enriched = await context.withPlantingDate(data);
      expect(resolveScoutingDisplayDate(enriched), DateTime(2026, 11, 9));
      final now = DateTime(2026, 12, 1);
      expect(resolveScoutingDisplayDate({}, now: now), now);
      expect(parseScoutingDate([]), isNull);
    },
  );

  test(
    'legacy cycle fallback and concurrent history reports reuse document reads',
    () async {
      final reads = <String>[];
      final context = ScoutingDateContext(
        read: (path) async {
          reads.add(path);
          return path.startsWith('cycles/') ? {'plantingDate': planting} : null;
        },
      );
      final data = <String, dynamic>{
        'farmerId': 'owner',
        'cycleId': 'legacy',
        'weekNumber': 3,
      };
      final results = await Future.wait([
        context.withPlantingDate(data),
        context.withPlantingDate(data),
      ]);
      expect(reads, ['users/owner/cycles/legacy', 'cycles/legacy']);
      for (final result in results) {
        expect(resolveScoutingDisplayDate(result), weekThreeEnd);
      }
    },
  );

  test(
    'reports with planting snapshots do not require additional reads',
    () async {
      final context = ScoutingDateContext(
        read: (_) async => throw StateError('Unexpected read'),
      );
      final data = <String, dynamic>{'plantingDate': planting, 'weekNumber': 3};
      expect(await context.withPlantingDate(data), same(data));
      expect(resolveScoutingDisplayDate(data), weekThreeEnd);
    },
  );
}
