import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/trap_inspection_policy.dart';

void main() {
  test(
    'inspection on planting day is day zero regardless of planting time',
    () {
      expect(
        trapInspectionDayIndex(
          DateTime(2026, 10, 28),
          DateTime(2026, 10, 28, 15),
        ),
        0,
      );
    },
  );
  test('day indexing crosses months and rejects dates before planting', () {
    expect(
      trapInspectionDayIndex(DateTime(2026, 11, 1), DateTime(2026, 10, 31, 15)),
      1,
    );
    expect(
      trapInspectionDayIndex(DateTime(2026, 10, 30), DateTime(2026, 10, 31)),
      -1,
    );
  });
  test('historical inspection cannot replace a newer trap summary', () {
    final previous = DateTime(2026, 10, 28);
    expect(
      shouldUpdateTrapInspection(DateTime(2026, 10, 27), previous),
      isFalse,
    );
    expect(shouldUpdateTrapInspection(previous, previous), isTrue);
    expect(
      shouldUpdateTrapInspection(DateTime(2026, 10, 29), previous),
      isTrue,
    );
    expect(shouldUpdateTrapInspection(DateTime(2026, 10, 27), null), isTrue);
  });
}
