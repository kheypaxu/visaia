import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/utils/scouting_report_date.dart';
import 'package:visaia/utils/growth_stage.dart';

void main() {
  final planting = DateTime(2026, 9, 1, 10);
  DateTime resolve(DateTime submitted, {int week = 0}) => scoutingReportDate(
    plantingDate: planting,
    weekIndex: week,
    submittedAt: submitted,
  );

  test('on-time submission retains its actual time including the last day', () {
    for (final date in [
      DateTime(2026, 9, 3, 14),
      DateTime(2026, 9, 7, 23, 59),
    ]) {
      expect(resolve(date), date);
    }
  });

  test(
    'next-week midnight and much later submissions use the last scouting day',
    () {
      final end = DateTime(2026, 9, 7, 23, 59, 59, 999, 999);
      expect(resolve(DateTime(2026, 9, 8)), end);
      expect(resolve(DateTime(2026, 12, 1)), end);
      expect(scoutingReportDap(planting, end), 6);
    },
  );

  test(
    'late report stage follows its selected week across month boundaries',
    () {
      final date = resolve(DateTime(2026, 12, 1), week: 4);
      expect(date.day, 5);
      expect(date.month, 10);
      final dap = scoutingReportDap(planting, date);
      expect(dap, 34);
      expect(getGrowthStage(dap).name, 'Late Vegetative');
    },
  );

  test('DAP counts calendar days regardless of planting time', () {
    expect(scoutingReportDap(planting, DateTime(2026, 9, 2)), 1);
  });

  test('Growth stages are properly resolved across full crop cycle including 75+ DAP', () {
    expect(getGrowthStage(0).name, 'Seedling');
    expect(getGrowthStage(14).name, 'Seedling');
    expect(getGrowthStage(15).name, 'Early Vegetative');
    expect(getGrowthStage(29).name, 'Early Vegetative');
    expect(getGrowthStage(30).name, 'Late Vegetative');
    expect(getGrowthStage(45).name, 'Late Vegetative');
    expect(getGrowthStage(46).name, 'Tasseling-Silking');
    expect(getGrowthStage(55).name, 'Tasseling-Silking');
    expect(getGrowthStage(56).name, 'Grain Fill');
    expect(getGrowthStage(74).name, 'Grain Fill');
    expect(getGrowthStage(75).name, 'Maturity');
    expect(getGrowthStage(85).name, 'Maturity');
    expect(getGrowthStage(105).name, 'Maturity');
    expect(getGrowthStage(120).name, 'Maturity');
    expect(getGrowthStage(-1).name, 'Unknown');
  });
}
