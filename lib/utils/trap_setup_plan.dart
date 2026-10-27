import 'package:latlong2/latlong.dart';

/// Each quantity selection adds a batch to the placements retained so far.
class TrapSetupPlan {
  int installedCount = 0;
  int retainedCount = 0;
  int quantity = 1;
  int get targetCount => retainedCount + quantity;

  void loadInstalled(int count) {
    installedCount = count;
    retainedCount = count;
    quantity = 1;
  }

  void startNextBatch(int placedCount) {
    retainedCount = placedCount;
    quantity = 1;
  }

  bool selectQuantity(int value, int placedCount) {
    if (value < 1 || value > 20 || retainedCount + value < placedCount) {
      return false;
    }
    quantity = value;
    return true;
  }
}

/// Includes points on the boundary so field-edge traps remain valid.
bool isInsideTrapField(LatLng point, List<LatLng> boundary) {
  if (boundary.length < 3) return false;
  var inside = false;
  for (int i = 0, j = boundary.length - 1; i < boundary.length; j = i++) {
    final a = boundary[j];
    final b = boundary[i];
    final cross =
        (point.longitude - a.longitude) * (b.latitude - a.latitude) -
        (point.latitude - a.latitude) * (b.longitude - a.longitude);
    if (cross.abs() < 1e-12 &&
        point.longitude >=
            (a.longitude < b.longitude ? a.longitude : b.longitude) &&
        point.longitude <=
            (a.longitude > b.longitude ? a.longitude : b.longitude) &&
        point.latitude >= (a.latitude < b.latitude ? a.latitude : b.latitude) &&
        point.latitude <= (a.latitude > b.latitude ? a.latitude : b.latitude)) {
      return true;
    }
    if ((a.latitude > point.latitude) != (b.latitude > point.latitude) &&
        point.longitude <
            (b.longitude - a.longitude) *
                    (point.latitude - a.latitude) /
                    (b.latitude - a.latitude) +
                a.longitude) {
      inside = !inside;
    }
  }
  return inside;
}
