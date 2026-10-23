import 'package:visaia/core/models/cycle_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/core/models/cycle_audit_policy.dart';

void main() {
  test(
    'Harvest save moves an ongoing cycle to pending audit, then finalized',
    () {
      final cycle = <String, dynamic>{'status': 'active', 'isCompleted': false};
      expect(hasRecordedHarvest(cycle), isFalse);

      // Fields written by HarvestRecordingScreen when the harvest is saved.
      cycle.addAll({
        'status': 'harvested',
        'isCompleted': true,
        'harvestCompletedAt': DateTime(2026, 10, 23),
        'actualHarvestDate': DateTime(2026, 10, 23),
      });
      expect(hasRecordedHarvest(cycle), isTrue);
      expect(canEditFinancialAudit(cycle), isTrue);
      expect(hasCompletedHarvestAudit(cycle), isFalse);

      cycle['isAuditCompleted'] = true;
      expect(hasCompletedHarvestAudit(cycle), isTrue);
      expect(canEditFinancialAudit(cycle), isFalse);
    },
  );

  test('Scheduled cycles cannot be audited', () {
    for (final cycle in <Map<String, dynamic>>[
      {'status': 'active', 'harvestDate': DateTime(2026, 1, 1)},
    ]) {
      expect(hasRecordedHarvest(cycle), isFalse);
      expect(canEditFinancialAudit(cycle), isFalse);
      expect(hasCompletedHarvestAudit(cycle), isFalse);
    }
  });

  test('Completed tab and audit use the same explicit completion evidence', () {
    for (final record in <Map<String, dynamic>>[
      {'isCompleted': true},
      {'status': 'completed'},
      {'status': '  COMPLETED  '},
      {'status': 'harvested'},
      {'status': 'active', 'harvestCompletedAt': DateTime(2026, 1, 1)},
      {'actualHarvestDate': DateTime(2026, 1, 1)},
      {'isPreviousCycle': true, 'isCompleted': true},
    ]) {
      final model = CycleModel.fromMap('cycle', record);
      expect(model.shouldBeCompleted, isTrue, reason: '$record');
      expect(hasRecordedHarvest(record), isTrue);
      expect(canEditFinancialAudit(record), isTrue);
      expect(hasCompletedHarvestAudit(record), isFalse);
      expect(model.copyWith(cycleName: 'Renamed').shouldBeCompleted, isTrue);
      expect(
        CycleModel.fromMap('cycle', model.toMap()).shouldBeCompleted,
        isTrue,
      );
      expect(
        hasCompletedHarvestAudit({...record, 'isAuditCompleted': true}),
        isTrue,
      );
    }
  });

  test(
    'Expected harvest dates and audit flag alone never complete a cycle',
    () {
      for (final record in <Map<String, dynamic>>[
        {'harvestDate': DateTime(2020), 'isCompleted': false},
        {'expectedHarvestDate': DateTime(2020), 'status': 'active'},
        {'isAuditCompleted': true},
      ]) {
        expect(CycleModel.fromMap('cycle', record).shouldBeCompleted, isFalse);
        expect(hasRecordedHarvest(record), isFalse);
        expect(hasCompletedHarvestAudit(record), isFalse);
      }
    },
  );

  test(
    'Harvested pending audits remain editable but cannot enter financial totals',
    () {
      for (final cycle in <Map<String, dynamic>>[
        {'status': 'harvested'},
        {'harvestCompletedAt': DateTime(2026, 1, 1)},
        {'actualHarvestDate': DateTime(2026, 1, 1)},
        {'isPreviousCycle': true, 'isCompleted': true},
      ]) {
        expect(canEditFinancialAudit(cycle), isTrue);
        expect(hasCompletedHarvestAudit(cycle), isFalse);
      }
    },
  );

  test(
    'Only harvested completed audits count and finalized audits stay locked',
    () {
      final cycle = {
        'harvestCompletedAt': DateTime(2026, 1, 1),
        'isAuditCompleted': true,
      };
      expect(hasCompletedHarvestAudit(cycle), isTrue);
      expect(canEditFinancialAudit(cycle), isFalse);
    },
  );
}
