import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/daily_log_week_policy.dart';

void main() {
  final planting = DateTime(2026, 1, 1);
  final harvest = planting.add(const Duration(days: 84));

  int weekAt(int days) => currentDailyLogWeek(
        plantingDate: planting,
        harvestDate: harvest,
        now: planting.add(Duration(days: days)),
      );

  test('matches Monitoring at week boundaries', () {
    expect(weekAt(0), 1);
    expect(weekAt(6), 1);
    expect(weekAt(7), 1);
    expect(weekAt(8), 2);
    expect(weekAt(14), 2);
    expect(weekAt(15), 3);
  });

  test('clamps before planting and after harvest', () {
    expect(weekAt(-7), 1);
    expect(weekAt(100), 12);
  });

  test('missing harvest matches Monitoring fallback', () {
    expect(currentDailyLogWeek(
      plantingDate: planting,
      now: planting.add(const Duration(days: 30)),
    ), 1);
  });
}
