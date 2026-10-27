import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/firestore_safe_ext.dart';
import 'package:visaia/services/report_map_location_resolver.dart';
import 'package:visaia/utils/scouting_week_comparison.dart';

class ScoutingMapData {
  final ScoutingWeekReport current;
  final ScoutingWeekReport? previous;
  final LatLng? fieldPoint;
  final List<LatLng> boundary;
  final String siteLabel;
  final List<String> notices;
  const ScoutingMapData({
    required this.current,
    this.previous,
    this.fieldPoint,
    this.boundary = const [],
    this.siteLabel = 'Field',
    this.notices = const [],
  });

  static LatLng? reportPoint(ScoutingWeekReport report) =>
      ReportMapLocationResolver.siteLocation({
        'location': report.data['location'],
      }) ??
      ReportMapLocationResolver.siteLocation({
        'location': report.data['coordinates'],
      }) ??
      ReportMapLocationResolver.siteLocation({
        'lat': report.data['latitude'] ?? report.data['lat'],
        'lng': report.data['longitude'] ?? report.data['lng'],
      });
}

/// Read-only. Owner queries retain legacy documents with no indexed weekNumber.
Future<ScoutingMapData> loadScoutingMapData(ScoutingWeekReport current) async {
  final db = FirebaseFirestore.instance;
  final notices = <String>[];
  final owner = current.ownerId;
  final cycleId = current.cycleId;
  final siblings = <String, ScoutingWeekReport>{};
  if (owner != null &&
      cycleId != null &&
      current.week != null &&
      current.week! > 1) {
    for (final key in ['userId', 'farmerId']) {
      try {
        final snapshot = await db
            .collection('clustered_reports')
            .where(key, isEqualTo: owner)
            .safeGet();
        if (snapshot.metadata.isFromCache) {
          notices.add(
            'Showing saved reports. The previous week may not be cached on this device.',
          );
        }
        for (final doc in snapshot.docs) {
          final report = ScoutingWeekReport(doc.id, doc.data());
          if (report.cycleId == cycleId && report.ownerId == owner) {
            siblings[doc.id] = report;
          }
        }
      } catch (_) {
        notices.add(
          'Could not load all weekly reports. Reopen this report to retry.',
        );
      }
    }
  }
  if (owner == null || cycleId == null) {
    notices.add(
      'Cycle or farmer information is missing; weekly comparison is unavailable.',
    );
  }

  Future<Map<String, dynamic>?> read(String path) async {
    try {
      final snapshot = await db.doc(path).safeGet();
      if (snapshot.metadata.isFromCache) {
        notices.add('Using saved field or farm information.');
      }
      return snapshot.data();
    } catch (_) {
      notices.add('Some saved map locations could not be loaded.');
      return null;
    }
  }

  Map<String, dynamic>? cycle, field, site;
  var siteLabel = 'Field';
  if (owner != null) {
    if (cycleId != null) cycle = await read('users/$owner/cycles/$cycleId');
    final fieldId =
        scoutingId(current.data['fieldId']) ??
        scoutingId(current.data['field_id']) ??
        scoutingId(cycle?['fieldId']);
    if (fieldId != null) field = await read('users/$owner/fields/$fieldId');
    if (ReportMapLocationResolver.siteLocation(field) != null) site = field;
    if (site == null) {
      final farmId =
          scoutingId(current.data['farmId']) ??
          scoutingId(current.data['farm_id']) ??
          scoutingId(cycle?['farmId']) ??
          scoutingId(field?['farmId']);
      if (farmId != null) {
        site = await read('users/$owner/farms/$farmId');
        siteLabel = 'Farm';
      }
    }
  }
  final boundary = <LatLng>[];
  final geometry = scoutingMap(site?['geometry']);
  dynamic vertices =
      site?['boundaries'] ??
      (site?['location'] is List ? site!['location'] : null);
  var geoJson = false;
  if (vertices == null &&
      geometry['type'] == 'Polygon' &&
      geometry['coordinates'] is List &&
      (geometry['coordinates'] as List).isNotEmpty) {
    vertices = geometry['coordinates'][0];
    geoJson = true;
  }
  if (vertices is List) {
    for (final vertex in vertices) {
      final point = geoJson && vertex is List && vertex.length >= 2
          ? ReportMapLocationResolver.siteLocation({
              'lat': vertex[1],
              'lng': vertex[0],
            })
          : ReportMapLocationResolver.siteLocation({'location': vertex});
      if (point != null) boundary.add(point);
    }
  }
  return ScoutingMapData(
    current: current,
    previous: previousScoutingWeek(current, siblings.values),
    fieldPoint: ReportMapLocationResolver.siteLocation(site),
    boundary: boundary.length >= 3 ? boundary : [],
    siteLabel: siteLabel,
    notices: notices.toSet().toList(),
  );
}
