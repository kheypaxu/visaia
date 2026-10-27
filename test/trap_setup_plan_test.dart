import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/utils/trap_setup_plan.dart';

void main() {
  test(
    'additional quantities accumulate over installed traps and prior drafts',
    () {
      final plan = TrapSetupPlan()..loadInstalled(5);
      expect(plan.quantity, 1);
      expect(plan.selectQuantity(2, 5), isTrue);
      expect(plan.targetCount, 7);
      plan.startNextBatch(7);
      expect(plan.installedCount, 5);
      expect(plan.quantity, 1);
      expect(plan.selectQuantity(3, 7), isTrue);
      expect(plan.targetCount, 10);
    },
  );
  test(
    'quantity cannot silently discard placements or remove retained traps',
    () {
      final plan = TrapSetupPlan()..loadInstalled(5);
      plan.selectQuantity(3, 5);
      expect(plan.selectQuantity(1, 7), isFalse);
      expect(plan.targetCount, 8);
      expect(plan.selectQuantity(2, 7), isTrue);
      expect(plan.targetCount, 7);
      expect(plan.selectQuantity(0, 5), isFalse);
    },
  );
  test('first installation can add repeated batches before final save', () {
    final plan = TrapSetupPlan();
    plan.selectQuantity(4, 0);
    plan.startNextBatch(4);
    plan.selectQuantity(2, 4);
    expect(plan.installedCount, 0);
    expect(plan.targetCount, 6);
  });
  const boundary = [
    LatLng(14, 120),
    LatLng(14, 121),
    LatLng(15, 121),
    LatLng(15, 120),
  ];
  test('placement accepts field interior and edges but rejects outside', () {
    expect(isInsideTrapField(const LatLng(14.5, 120.5), boundary), isTrue);
    expect(isInsideTrapField(const LatLng(14, 120.5), boundary), isTrue);
    expect(isInsideTrapField(const LatLng(14, 120), boundary), isTrue);
    expect(isInsideTrapField(const LatLng(15.1, 120.5), boundary), isFalse);
    expect(isInsideTrapField(const LatLng(14.5, 121.1), boundary), isFalse);
    expect(isInsideTrapField(const LatLng(14.5, 120.5), const []), isFalse);
  });
}
