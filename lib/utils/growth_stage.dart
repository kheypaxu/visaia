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
  if (dap >= 0 && dap <= 14) {
    return GrowthStageInfo(
      stage: GrowthStage.seedling,
      name: 'Seedling',
      description: 'Crop can recover from minor damage.',
      vulnerabilityScore: 0.2,
      riskLabel: 'Low',
      minDap: 0,
      maxDap: 14,
    );
  } else if (dap >= 15 && dap <= 29) {
    return GrowthStageInfo(
      stage: GrowthStage.earlyVegetative,
      name: 'Early Vegetative',
      description: 'Some recovery possible.',
      vulnerabilityScore: 0.4,
      riskLabel: 'Moderate',
      minDap: 15,
      maxDap: 29,
    );
  } else if (dap >= 30 && dap <= 48) {
    return GrowthStageInfo(
      stage: GrowthStage.lateVegetative,
      name: 'Late Vegetative',
      description: 'Approaching critical stage.',
      vulnerabilityScore: 0.7,
      riskLabel: 'High',
      minDap: 30,
      maxDap: 48,
    );
  } else if (dap >= 44 && dap <= 53) {
    return GrowthStageInfo(
      stage: GrowthStage.tasselingSilking,
      name: 'Tasseling-Silking',
      description: 'CRITICAL — maximum vulnerability.',
      vulnerabilityScore: 1.0,
      riskLabel: 'Critical',
      minDap: 44,
      maxDap: 53,
    );
  } else if (dap >= 54 && dap <= 69) {
    return GrowthStageInfo(
      stage: GrowthStage.grainFill,
      name: 'Grain Fill',
      description: 'Moderate-High; direct ear damage.',
      vulnerabilityScore: 0.6,
      riskLabel: 'Moderate-High',
      minDap: 54,
      maxDap: 69,
    );
  } else if (dap >= 70 && dap <= 75) {
    return GrowthStageInfo(
      stage: GrowthStage.maturity,
      name: 'Maturity',
      description: 'Low vulnerability; harvest ready.',
      vulnerabilityScore: 0.2,
      riskLabel: 'Low',
      minDap: 70,
      maxDap: 75,
    );
  } else {
    return GrowthStageInfo(
      stage: GrowthStage.seedling,
      name: 'Unknown',
      description: 'DAP out of range.',
      vulnerabilityScore: 0.0,
      riskLabel: 'N/A',
      minDap: 0,
      maxDap: 0,
    );
  }
}

// Helper to get growth stage at a specific date relative to planting
GrowthStageInfo getGrowthStageForDate(DateTime plantingDate, DateTime targetDate) {
  final dap = targetDate.difference(plantingDate).inDays;
  return getGrowthStage(dap.clamp(0, 75));
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