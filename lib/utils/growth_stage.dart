// lib/utils/growth_stage.dart

enum GrowthStage {
  seedling,
  earlyVegetative,
  lateVegetative,
  tasselingSilking,
  grainFill,
  maturity,
}

class GrowthStageInfo {
  final GrowthStage stage;
  final String name;
  final String description;
  final double vulnerabilityScore; // 0.0 - 1.0
  final String riskLabel;
  final int minDap;
  final int maxDap;

  GrowthStageInfo({
    required this.stage,
    required this.name,
    required this.description,
    required this.vulnerabilityScore,
    required this.riskLabel,
    required this.minDap,
    required this.maxDap,
  });
}

GrowthStageInfo getGrowthStage(int dap) {
  if (dap < 0) {
    return GrowthStageInfo(
      stage: GrowthStage.seedling,
      name: 'Unknown',
      description: 'DAP out of range.',
      vulnerabilityScore: 0.0,
      riskLabel: 'N/A',
      minDap: 0,
      maxDap: 0,
    );
  } else if (dap <= 14) {
    return GrowthStageInfo(
      stage: GrowthStage.seedling,
      name: 'Seedling',
      description: 'Crop can recover from minor damage.',
      vulnerabilityScore: 0.2,
      riskLabel: 'Low',
      minDap: 0,
      maxDap: 14,
    );
  } else if (dap <= 29) {
    return GrowthStageInfo(
      stage: GrowthStage.earlyVegetative,
      name: 'Early Vegetative',
      description: 'Some recovery possible.',
      vulnerabilityScore: 0.4,
      riskLabel: 'Moderate',
      minDap: 15,
      maxDap: 29,
    );
  } else if (dap <= 45) {
    return GrowthStageInfo(
      stage: GrowthStage.lateVegetative,
      name: 'Late Vegetative',
      description: 'Approaching critical stage.',
      vulnerabilityScore: 0.7,
      riskLabel: 'High',
      minDap: 30,
      maxDap: 45,
    );
  } else if (dap <= 55) {
    return GrowthStageInfo(
      stage: GrowthStage.tasselingSilking,
      name: 'Tasseling-Silking',
      description: 'CRITICAL — maximum vulnerability.',
      vulnerabilityScore: 1.0,
      riskLabel: 'Critical',
      minDap: 46,
      maxDap: 55,
    );
  } else if (dap <= 74) {
    return GrowthStageInfo(
      stage: GrowthStage.grainFill,
      name: 'Grain Fill',
      description: 'Moderate-High; direct ear damage.',
      vulnerabilityScore: 0.6,
      riskLabel: 'Moderate-High',
      minDap: 56,
      maxDap: 74,
    );
  } else {
    return GrowthStageInfo(
      stage: GrowthStage.maturity,
      name: 'Maturity',
      description: 'Low vulnerability; harvest ready.',
      vulnerabilityScore: 0.2,
      riskLabel: 'Low',
      minDap: 75,
      maxDap: 120,
    );
  }
}

// Helper to get growth stage at a specific date relative to planting
GrowthStageInfo getGrowthStageForDate(DateTime plantingDate, DateTime targetDate) {
  final dap = targetDate.difference(plantingDate).inDays;
  return getGrowthStage(dap);
}

// Get all growth stages for a cycle (by week)
List<GrowthStageInfo> getGrowthStagesForCycle(DateTime plantingDate, DateTime harvestDate) {
  final stages = <GrowthStageInfo>[];
  final totalDays = harvestDate.difference(plantingDate).inDays;
  
  for (int dap = 0; dap <= totalDays; dap += 7) {
    final stage = getGrowthStage(dap);
    // Avoid duplicates
    if (stages.isEmpty || stages.last.name != stage.name) {
      stages.add(stage);
    }
  }
  
  return stages;
}