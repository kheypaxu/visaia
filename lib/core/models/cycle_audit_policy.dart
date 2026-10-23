/// Explicit completion is the harvest handoff used by the cycle screens.
/// Accept legacy completion-only records as well as newer harvest records.
/// An expected harvest date alone never completes a cycle.
bool hasRecordedHarvest(Map<String, dynamic> cycle) {
  final status = cycle['status']?.toString().trim().toLowerCase();
  return cycle['isCompleted'] == true ||
      status == 'completed' ||
      status == 'harvested' ||
      cycle['harvestCompletedAt'] != null ||
      cycle['actualHarvestDate'] != null;
}

bool canEditFinancialAudit(Map<String, dynamic> cycle) =>
    hasRecordedHarvest(cycle) && cycle['isAuditCompleted'] != true;

bool hasCompletedHarvestAudit(Map<String, dynamic> cycle) =>
    hasRecordedHarvest(cycle) && cycle['isAuditCompleted'] == true;
