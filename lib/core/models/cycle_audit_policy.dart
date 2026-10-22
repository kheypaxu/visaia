/// Harvest evidence is separate from general cycle completion. A cycle can be
/// manually marked complete without recording a harvest.
bool hasRecordedHarvest(Map<String, dynamic> cycle) {
  final status = cycle['status']?.toString().trim().toLowerCase();
  return status == 'harvested' ||
      cycle['harvestCompletedAt'] != null ||
      cycle['actualHarvestDate'] != null ||
      (cycle['isPreviousCycle'] == true &&
          (cycle['isCompleted'] == true || status == 'completed'));
}

bool canEditFinancialAudit(Map<String, dynamic> cycle) =>
    hasRecordedHarvest(cycle) && cycle['isAuditCompleted'] != true;

bool hasCompletedHarvestAudit(Map<String, dynamic> cycle) =>
    hasRecordedHarvest(cycle) && cycle['isAuditCompleted'] == true;
