import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/scouting_map_data.dart';
import 'package:visaia/utils/scouting_week_comparison.dart';

ScoutingWeekReport report(String id, Map<String, dynamic> data) =>
    ScoutingWeekReport(id, {'userId': 'owner', 'cycleId': 'cycle', ...data});

void main() {
  test('week boundaries include DAP zero and preserve the assigned week', () {
    for (final (dap, week) in [(0, 1), (6, 1), (7, 2), (13, 2), (14, 3)]) {
      expect(report('r', {'dap': dap}).week, week);
    }
    expect(report('r', {'dap': 14, 'weekNumber': 8}).week, 8);
    expect(report('r', {'dap': 14, 'weekNumber': 'bad'}).week, 3);
  });

  test('only exact previous week in same owner and cycle is selected', () {
    final current = report('current', {'weekNumber': 3});
    final older = report('older', {
      'weekNumber': 2,
      'submittedAt': '2026-01-01',
    });
    final newer = report('newer', {'dap': 7, 'submittedAt': '2026-01-02'});
    expect(
      previousScoutingWeek(current, [
        older,
        newer,
        report('other-owner', {'weekNumber': 2, 'userId': 'other'}),
        report('other-cycle', {'weekNumber': 2, 'cycleId': 'other'}),
        report('week1', {'weekNumber': 1}),
      ])?.id,
      'newer',
    );
    expect(
      previousScoutingWeek(current, [
        report('gap', {'weekNumber': 1}),
      ]),
      isNull,
    );
    expect(
      previousScoutingWeek(report('first', {'weekNumber': 1}), [older]),
      isNull,
    );
    expect(previousScoutingWeek(report('unknown', {}), [older]), isNull);
    final legacy = ScoutingWeekReport('legacy', {
      'farmerId': 'owner',
      'cycleId': 'cycle',
      'weekNumber': 2,
    });
    expect(previousScoutingWeek(current, [legacy]), legacy);
  });

  test(
    'corrections override original counts without treating zero as missing',
    () {
      final r = report('r', {
        'correctedInspected': 50,
        'correctedDamaged': 0,
        'totalInspected': 100,
        'totalDamaged': 30,
        'damagePercentage': 30,
        'totals': {'eggs': 8, 'larvae': 5},
        'correctedTotals': {'eggs': 0},
      });
      expect(r.inspected, 50);
      expect(r.damaged, 0);
      expect(r.damagePercentage, 0);
      expect(r.count('eggs'), 0);
      expect(r.count('larvae'), 5);
    },
  );

  test('malformed legacy fields remain unavailable and never crash', () {
    final r = report('r', {
      'weekNumber': [],
      'dap': -1,
      'correctedTotals': [],
      'totals': 'bad',
      'stationsData': [
        null,
        3,
        {'plantsInspected': 'bad', 'eggMasses': double.nan},
      ],
      'totalInspected': double.infinity,
      'totalDamaged': -5,
      'damagePercentage': 'bad',
    });
    expect(r.week, isNull);
    expect(r.inspected, isNull);
    expect(r.damagePercentage, isNull);
    expect(r.count('eggs'), isNull);
    expect(r.growthStage, 'Unavailable');
    expect(
      report('r', {'totalInspected': 0, 'totalDamaged': 0}).damagePercentage,
      isNull,
    );
  });

  test(
    'station summaries supply complete totals but never invent missing counts',
    () {
      final r = report('r', {
        'stationsData': [
          {'plantsInspected': 10, 'damaged': 2, 'eggMasses': 3},
          {'plantsInspected': 20, 'damaged': 1, 'eggMasses': 0},
        ],
      });
      expect(r.inspected, 30);
      expect(r.damaged, 3);
      expect(r.damagePercentage, 10);
      expect(r.count('eggs'), 3);
      expect(r.count('moths'), isNull);
    },
  );

  test(
    'deltas are only available for resolved, never aliases or validation',
    () {
      final previous = report('previous', {
        'weekNumber': 1,
        'damagePercentage': 20,
        'totalInspected': 50,
        'totals': {'eggs': 4},
      });
      for (final status in [
        'pending',
        'validated',
        'controlled',
        'rejected',
        null,
      ]) {
        expect(
          scoutingDeltas(report('current', {'status': status}), previous),
          isEmpty,
        );
      }
      final current = report('current', {
        'status': ' Resolved ',
        'damagePercentage': 10,
        'totalInspected': 100,
        'totals': {'eggs': 0},
      });
      final deltas = scoutingDeltas(current, previous);
      expect(deltas.first.change, -10);
      expect(deltas.first.unit, ' pp');
      expect(deltas.first.direction, '▼ better');
      expect(deltas[1].change, -4);
      expect(deltas[2].change, isNull);
      expect(deltas[5].direction, '▲ more inspected');
      expect(scoutingDeltas(current, null), isEmpty);
    },
  );

  test('saved classification wins over a conflicting damage fallback', () {
    expect(
      report('r', {'reportLevel': 'Low-Level', 'damagePercentage': 11}).level,
      'Low',
    );
    expect(
      report('r', {'isHighLevel': false, 'damagePercentage': 20}).level,
      'Low',
    );
    expect(report('r', {'damagePercentage': 10}).level, 'High');
    expect(report('r', {'damagePercentage': 10}).levelIsEstimated, isTrue);
    expect(report('r', {}).level, isNull);
  });

  test('report coordinates are validated and zero coordinates retained', () {
    expect(
      ScoutingMapData.reportPoint(
        report('r', {
          'location': {'lat': 0, 'lng': 122},
        }),
      )?.latitude,
      0,
    );
    expect(
      ScoutingMapData.reportPoint(
        report('r', {
          'location': {'lat': 100, 'lng': 122},
        }),
      ),
      isNull,
    );
    expect(
      ScoutingMapData.reportPoint(report('r', {'location': 'bad'})),
      isNull,
    );
  });
}
