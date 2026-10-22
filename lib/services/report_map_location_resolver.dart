import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

/// Resolves an observation to its linked agricultural site, never upload GPS.
/// Cache lifetime is one map refresh, including failed/missing document reads.
class ReportMapLocationResolver {
  final Future<Map<String, dynamic>?> Function(String path) _read;
  final _documents = <String, Future<Map<String, dynamic>?>>{};

  ReportMapLocationResolver({
    FirebaseFirestore? db,
    Future<Map<String, dynamic>?> Function(String path)? read,
  }) : _read =
           read ??
           ((path) async {
             final doc = await (db ?? FirebaseFirestore.instance)
                 .doc(path)
                 .safeGet();
             return doc.data();
           });

  Future<Map<String, dynamic>?> _get(String path) =>
      _documents.putIfAbsent(path, () async {
        try {
          return await _read(path);
        } catch (_) {
          return null;
        }
      });

  String? _id(dynamic value) {
    if (value is! String || value.trim().isEmpty || value.contains('/')) {
      return null;
    }
    return value.trim();
  }

  Future<LatLng?> resolve(
    Map<String, dynamic> report, {
    String? fallbackOwnerId,
  }) async {
    final owner =
        _id(report['userId']) ??
        _id(report['farmerId']) ??
        _id(fallbackOwnerId);
    if (owner == null) return null;
    final cycleId = _id(report['cycleId']) ?? _id(report['cycle_id']);
    final cycle = cycleId == null
        ? null
        : await _get('users/$owner/cycles/$cycleId');
    final fieldId =
        _id(report['fieldId']) ??
        _id(report['field_id']) ??
        _id(cycle?['fieldId']);
    Map<String, dynamic>? field;
    if (fieldId != null) {
      field = await _get('users/$owner/fields/$fieldId');
      final point = siteLocation(field);
      if (point != null) return point;
    }
    final farmId =
        _id(report['farmId']) ??
        _id(report['farm_id']) ??
        _id(cycle?['farmId']) ??
        _id(field?['farmId']);
    if (farmId == null) return null;
    return siteLocation(await _get('users/$owner/farms/$farmId'));
  }

  static double? _number(dynamic value) => value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value)
      : null;

  static LatLng? _point(dynamic value, {bool geoJson = false}) {
    double? lat, lng;
    if (value is GeoPoint) {
      lat = value.latitude;
      lng = value.longitude;
    }
    if (value is Map) {
      lat = _number(value['lat'] ?? value['latitude']);
      lng = _number(value['lng'] ?? value['longitude'] ?? value['lon']);
    }
    if (geoJson && value is List && value.length >= 2) {
      lng = _number(value[0]);
      lat = _number(value[1]);
    }
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return LatLng(lat, lng);
  }

  static LatLng? _center(dynamic vertices, {bool geoJson = false}) {
    if (vertices is! List) return null;
    final points = vertices
        .map((v) => _point(v, geoJson: geoJson))
        .whereType<LatLng>()
        .toList();
    if (points.length < 3) return null;
    if (points.first == points.last) points.removeLast();
    return LatLng(
      points.fold<double>(0, (s, p) => s + p.latitude) / points.length,
      points.fold<double>(0, (s, p) => s + p.longitude) / points.length,
    );
  }

  static LatLng? siteLocation(Map<String, dynamic>? site) {
    if (site == null) return null;
    final boundaryCenter = _center(site['boundaries']) ?? _center(site['location']);
    if (boundaryCenter != null) return boundaryCenter;
    final geometry = site['geometry'];
    if (geometry is Map) {
      final coords = geometry['coordinates'];
      if (geometry['type'] == 'Point') return _point(coords, geoJson: true);
      if (geometry['type'] == 'Polygon' &&
          coords is List &&
          coords.isNotEmpty) {
        final center = _center(coords.first, geoJson: true);
        if (center != null) return center;
      }
    }
    return _point(site['location']) ?? _point(site['center']) ?? _point(site);
  }
}
