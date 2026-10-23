import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/faw_risk_service.dart';

void main() {
  final farm = [
    const LatLng(10, 122),
    const LatLng(10, 122.1),
    const LatLng(10.1, 122.1),
    const LatLng(10.1, 122),
  ];
  test('Interior and boundary reports have zero distance', () {
    expect(distanceToFarmMeters(const LatLng(10.05, 122.05), farm), 0);
    expect(
      distanceToFarmMeters(const LatLng(10.05, 122), farm),
      closeTo(0, .01),
    );
  });
  test('Proximity reaches farm edge even when center is outside radius', () {
    final report = const LatLng(10.05, 122.10005);
    expect(distanceToFarmMeters(report, farm), lessThan(10));
    expect(
      const Distance().as(LengthUnit.Meter, report, polygonCenter(farm)),
      greaterThan(5000),
    );
  });
  test('Distant reports and missing farm boundaries cannot overlap', () {
    expect(
      distanceToFarmMeters(const LatLng(11, 123), farm),
      greaterThan(10000),
    );
    expect(distanceToFarmMeters(const LatLng(10, 122), []), double.infinity);
  });
}
