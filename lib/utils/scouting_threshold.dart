/// Shared High/Low boundary for weekly scouting plant-damage percentages.
const double scoutingDamageThresholdPercent = 12.05;

bool meetsScoutingDamageThreshold(num damagePercentage) =>
    damagePercentage.isFinite &&
    damagePercentage >= scoutingDamageThresholdPercent;
