import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/core/models/cycle_metrics.dart';

void main() {
  test('efficiency uses kg and supports both harvest record formats', () {
    expect(cycleEfficiency({'actualYield': 6000, 'area': 1}), 75);
    expect(cycleEfficiency({'totalYield': 6000, 'area': 1}), 75);
    expect(cycleEfficiency({'actualYield': '12000', 'area': '1'}), 150);
    expect(
      cycleEfficiency({'actualYield': 0, 'totalYield': 6000, 'area': 1}),
      0,
    );
  });

  test('missing and invalid efficiency inputs are not zero scores', () {
    for (final data in <Map<String, dynamic>>[
      {},
      {'actualYield': 6000},
      {'actualYield': 6000, 'area': 0},
      {'actualYield': -1, 'area': 1},
      {'actualYield': double.nan, 'area': 1},
    ]) {
      expect(cycleEfficiency(data), isNull);
    }
  });

  test('harvest revenue does not deduct damaged weight a second time', () {
    final finance = CycleFinance({
      'actualYield': 1000,
      'damagedYield': 100,
      'marketPrice': 20,
      'totalValue': 18000,
      'fertilizerCost': 2000,
      'seedsCost': 500,
    });
    expect(finance.gross, 18000);
    expect(finance.costs, 2500);
    expect(finance.net, 15500);
  });

  test('legacy losses and explicit zero saved totals are respected', () {
    final legacy = CycleFinance({
      'grossIncome': 1000,
      'pestLoss': 100,
      'otherLoss': 200,
    });
    expect(legacy.net, 700);
    final saved = CycleFinance({
      'grossIncome': 1000,
      'damageCost': 0,
      'pestLoss': 100,
      'totalCycleCost': 0,
      'otherLoss': 200,
      'netIncome': 0,
    });
    expect(saved.damage, 0);
    expect(saved.costs, 0);
    expect(saved.net, 0);
  });

  test('adjustments reconcile itemized amounts to financial report totals', () {
    final finance = CycleFinance({
      'grossIncome': 10000,
      'damageCost': 500,
      'controlMethodCost': 100,
      'fertilizerCost': 200,
      'seedsCost': 300,
      'otherExpenses': 400,
      'totalCycleCost': 1500,
      'netIncome': 7500,
    });
    expect(finance.costAdjustment, 500);
    expect(finance.netAdjustment, -500);
    expect(
      finance.gross -
          finance.damage -
          finance.control -
          finance.fertilizer -
          finance.seeds -
          finance.other -
          finance.costAdjustment +
          finance.netAdjustment,
      finance.net,
    );
  });
}
