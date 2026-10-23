import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/cycle_naming_service.dart';

void main() {
  test('Names follow the requested formats', () {
    expect(formatCycleName(crop: 'Corn', variety: 'GMO Hybrid', isPrevious: false, number: 1),
        'Corn (GMO Hybrid) - New Cycle 1');
    expect(formatCycleName(crop: 'Corn', variety: 'Sweet Corn', isPrevious: true, number: 1),
        'Corn (Sweet Corn) - Prev Cycle 1');
  });

  test('New and previous sequences are independent across varieties', () {
    final cycles = [
      {'cycleName': 'Corn (GMO Hybrid) - New Cycle 1'},
      {'cycleName': 'Corn (Sweet Corn) - Prev Cycle 1', 'isPreviousCycle': true},
      {'cycleName': 'Corn (Green Corn) - New Cycle 2'},
    ];
    expect(nextCycleNumber(cycles, isPrevious: false), 3);
    expect(nextCycleNumber(cycles, isPrevious: true), 2);
    expect(nextCycleNumber([], isPrevious: false), 1);
    expect(nextCycleNumber([], isPrevious: true), 1);
  });

  test('Existing legacy and custom cycles contribute to their sequences', () {
    final cycles = [
      {'cycleName': 'New Cycle | Corn - GMO Hybrid', 'isCompleted': true},
      {'cycleName': 'Prev. Cycle | Corn - Sweet Corn'},
      {'cycleName': 'My historical crop', 'isPreviousCycle': true},
    ];
    expect(nextCycleNumber(cycles, isPrevious: false), 2);
    expect(nextCycleNumber(cycles, isPrevious: true), 3);
  });

  test('Number gaps do not cause an existing suffix to be reused', () {
    expect(nextCycleNumber([
      {'cycleName': 'Corn (GMO Hybrid) - New Cycle 7'},
    ], isPrevious: false), 8);
  });
}
