import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/chemical_task_policy.dart';

void main() {
  bool eligible(
    int week, {
    int damaged = 5,
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
        {'completed': completed, 'plantsInspected': 50, 'damaged': damaged},
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
      expect(eligible(4, damaged: 4), isFalse);
      expect(eligible(5, damaged: 6), isTrue);
    },
  );

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
