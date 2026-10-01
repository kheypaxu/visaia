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

  /// Validates whether GPS coordinates are within standard geographic bounds
  static bool isValidCoordinate(LatLng point) {
    if (point.latitude < -90.0 || point.latitude > 90.0) return false;
    if (point.longitude < -180.0 || point.longitude > 180.0) return false;
    return true;
  }

  /// Checks if any coordinates in the list are invalid GPS values
  static bool hasInvalidCoordinates(List<LatLng> points) {
    if (points.isEmpty) return true;
    for (final p in points) {
      if (!isValidCoordinate(p)) return true;
    }
    return false;
  }

  /// Returns true if a polygon has self-crossing / self-intersecting edges
  static bool hasSelfIntersection(List<LatLng> points) {
    if (points.length < 4) return false; // Triangles cannot self-intersect

    final int n = points.length;
    for (int i = 0; i < n; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % n];

      for (int j = i + 1; j < n; j++) {
        // Skip adjacent edges and the wrap-around closing edge
        if (j == (i + 1) % n || (i == 0 && j == n - 1)) continue;

        final p3 = points[j];
        final p4 = points[(j + 1) % n];

        if (_segmentsIntersect(p1, p2, p3, p4)) {
          return true;
        }
      }
    }
    return false;
  }

  static double _ccw(LatLng a, LatLng b, LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  static bool _segmentsIntersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    final ccw1 = _ccw(a, c, d);
    final ccw2 = _ccw(b, c, d);
    final ccw3 = _ccw(a, b, c);
    final ccw4 = _ccw(a, b, d);

    if (((ccw1 > 0 && ccw2 < 0) || (ccw1 < 0 && ccw2 > 0)) &&
        ((ccw3 > 0 && ccw4 < 0) || (ccw3 < 0 && ccw4 > 0))) {
      return true;
    }
    return false;
  }
}