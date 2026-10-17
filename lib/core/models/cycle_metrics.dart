/// Numeric values in cycle records, including older string-valued imports.
double? cycleNumber(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

double? recordedYield(Map<String, dynamic> data) =>
    cycleNumber(data['actualYield']) ?? cycleNumber(data['totalYield']);

/// Yield against the existing 8 tonnes/hectare benchmark, in kilograms.
double? cycleEfficiency(Map<String, dynamic> data) {
  final yieldKg = recordedYield(data);
  final hectares = cycleNumber(data['area']);
  if (yieldKg == null || yieldKg < 0 || hectares == null || hectares <= 0) {
    return null;
  }
  final score = yieldKg / hectares / 8000 * 100;
  return score.isFinite ? score : null;
}

/// Matches the saved values and legacy fallbacks in the financial report.
class CycleFinance {
  CycleFinance(this.data);
  final Map<String, dynamic> data;

  double get gross =>
      cycleNumber(data['grossIncome']) ??
      cycleNumber(data['totalValue']) ??
      cycleNumber(data['income']) ??
      0;
  double get control => cycleNumber(data['controlMethodCost']) ?? 0;
  double get fertilizer => cycleNumber(data['fertilizerCost']) ?? 0;
  double get seeds => cycleNumber(data['seedsCost']) ?? 0;
  double get other =>
      cycleNumber(data['otherExpenses']) ?? cycleNumber(data['otherLoss']) ?? 0;
  double get damage =>
      cycleNumber(data['damageCost']) ?? cycleNumber(data['pestLoss']) ?? 0;
  double get costs =>
      cycleNumber(data['totalCycleCost']) ??
      (control + fertilizer + seeds + other);
  double get net => cycleNumber(data['netIncome']) ?? (gross - costs - damage);
  double get costAdjustment => costs - control - fertilizer - seeds - other;
  double get netAdjustment => net - (gross - costs - damage);
}
