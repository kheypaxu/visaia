import 'package:latlong2/latlong.dart';
import 'dart:math';

class GeoUtils {
  static double calculateAreaSqm(List<LatLng> points) {
    if (points.length < 3) return 0;

    const R = 6378137.0; // Earth radius in meters
    double area = 0;

    for (int i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];

      final lat1 = p1.latitude * 3.141592653589793 / 180;
      final lat2 = p2.latitude * 3.141592653589793 / 180;
      final lng1 = p1.longitude * 3.141592653589793 / 180;
      final lng2 = p2.longitude * 3.141592653589793 / 180;

      area += (lng2 - lng1) * (2 + (sin(lat1)) + (sin(lat2)));
    }

    area = area * R * R / 2;
    return area.abs();
  }

  static double toAcres(double sqm) => sqm * 0.000247105;
}