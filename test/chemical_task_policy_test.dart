import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/chemical_task_policy.dart';

void main() {
  bool eligible(
    int week, {
    int damaged = 7,
    int inspected = 50,
    bool completed = true,
    String? method = 'chemical',
    int? start = 3,
    bool future = false,
  }) {
    return isChemicalTaskEligible(
      controlMethod: method,
      startWeek: start,
      weekNumber: week,
      isFutureWeek: future,
      stations: [
        {
          'completed': completed,
          'plantsInspected': inspected,
          'damaged': damaged,
        },
      ],
    );
  }

  test('week 3 selection never generates earlier tasks', () {
    expect(eligible(1), isFalse);
    expect(eligible(2), isFalse);
    expect(eligible(3), isTrue);
  });

  test(
    'low week suppresses application; a later high week qualifies again',
    () {
      expect(eligible(3), isTrue);
      expect(eligible(4, damaged: 6), isFalse);
      expect(eligible(5, damaged: 7), isTrue);
    },
  );

  test('chemical eligibility uses the inclusive 12.05 percent boundary', () {
    expect(eligible(3, damaged: 240, inspected: 2000), isFalse);
    expect(eligible(3, damaged: 241, inspected: 2000), isTrue);
    expect(eligible(3, damaged: 242, inspected: 2000), isTrue);
    expect(eligible(3, damaged: 6), isFalse); // 12% of 50 plants.
    expect(eligible(3, damaged: 7), isTrue); // 14% of 50 plants.
  });

  test(
    'requires completed scouting, chemical selection, and a known start',
    () {
      expect(eligible(3, completed: false), isFalse);
      expect(eligible(3, method: 'biological'), isFalse);
      expect(eligible(3, method: null), isFalse);
      expect(eligible(3, start: null), isFalse);
      expect(eligible(5, future: true), isFalse);
    },
  );

  test('empty and zero-inspection weeks never qualify', () {
    for (final stations in <List<Map<String, dynamic>>>[
      [],
      [
        {'completed': true, 'plantsInspected': 0, 'damaged': 0},
      ],
    ]) {
      expect(
        isChemicalTaskEligible(
          controlMethod: 'chemical',
          startWeek: 3,
          weekNumber: 3,
          isFutureWeek: false,
          stations: stations,
        ),
        isFalse,
      );
    }
  });
}
