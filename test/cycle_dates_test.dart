import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/core/models/cycle_dates.dart';

void main() {
  final planted = DateTime(2026, 1, 1);
  final planned = DateTime(2026, 4, 15);
  final harvested = DateTime(2026, 4, 10);

  test('Schedule stays separate from actual harvest and record creation', () {
    final dates = CycleDates({
      'plantingDate': Timestamp.fromDate(planted),
      'expectedHarvestDate': Timestamp.fromDate(planned),
      'harvestDate': Timestamp.fromDate(harvested),
      'harvestCompletedAt': Timestamp.fromDate(harvested),
      'actualHarvestDate': Timestamp.fromDate(planned),
      'completedAt': DateTime(2026, 5),
      'createdAt': DateTime(2026, 6),
    });
    expect(dates.planting, planted);
    expect(dates.estimatedHarvest, planned);
    expect(dates.harvestCompleted, harvested);
  });

  test('Estimated dates never fall back to the actual harvest', () {
    final dates = CycleDates({'actualHarvestDate': harvested});
    expect(dates.estimatedHarvest, isNull);
    expect(dates.harvestCompleted, harvested);
  });

  test('Creation and expected dates never substitute for harvest completion', () {
    final dates = CycleDates({'createdAt': planted, 'harvestDate': planned});
    expect(dates.harvestCompleted, isNull);
    expect(dates.estimatedHarvest, planned);
  });

  test('Legacy previous cycles use their user-entered historical harvest', () {
    final dates = CycleDates({
      'isPreviousCycle': true, 'harvestDate': harvested, 'createdAt': DateTime(2026, 6),
    });
    expect(dates.harvestCompleted, harvested);
  });

  test('Date parsing supports legacy formats and skips invalid estimates', () {
    final dates = CycleDates({
      'plantingDate': planted.toIso8601String(),
      'expectedHarvestDate': 'invalid',
      'estimatedHarvestDate': planned.millisecondsSinceEpoch,
      'actualHarvestDate': harvested.toIso8601String(),
    });
    expect(dates.planting, planted);
    expect(dates.estimatedHarvest, planned);
    expect(dates.harvestCompleted, harvested);
  });
}
