import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/core/models/cycle_audit_policy.dart';

void main() {
  test('Scheduled and manually completed cycles cannot be audited', () {
    for (final cycle in <Map<String, dynamic>>[
      {'status': 'active', 'harvestDate': DateTime(2026, 1, 1)},
      {'isCompleted': true},
      {'status': 'completed', 'isCompleted': true, 'isAuditCompleted': true},
    ]) {
      expect(hasRecordedHarvest(cycle), isFalse);
      expect(canEditFinancialAudit(cycle), isFalse);
      expect(hasCompletedHarvestAudit(cycle), isFalse);
    }
  });

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
