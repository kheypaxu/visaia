import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/report_map_location_resolver.dart';

/// Uses saved geographic data only; distance alone cannot locate a report.
class NotificationProximityMap extends StatefulWidget {
  final Map<String, dynamic> alertData;
  const NotificationProximityMap({super.key, required this.alertData});

  @override
  State<NotificationProximityMap> createState() =>
      _NotificationProximityMapState();
}

class _NotificationProximityMapState extends State<NotificationProximityMap> {
  final _controller = MapController();
  late final _data = _load();

  Future<({LatLng? report, List<List<LatLng>> farms})> _load() async {
    final db = FirebaseFirestore.instance;
    final alert = widget.alertData;
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? AuthCacheService().cachedUid;
    final farms = <List<LatLng>>[];
    if (uid != null && uid.isNotEmpty) {
      final docs = await db
          .collection('users')
          .doc(uid)
          .collection('farms')
          .get();
      for (final doc in docs.docs) {
        final raw = doc.data()['boundaries'];
        if (raw is! List) continue;
        final points = raw
            .map((p) => ReportMapLocationResolver.siteLocation({'location': p}))
            .whereType<LatLng>()
            .toList();
        if (points.length >= 3) farms.add(points);
      }
    }
    LatLng? report;
    final id = alert['reportId']?.toString();
    if (id != null && id.isNotEmpty && !id.contains('/')) {
      final types = alert['reportType'] == 'clustered'
          ? ['clustered_reports']
          : alert['reportType'] == 'regular'
          ? ['reports']
          : ['reports', 'clustered_reports'];
      for (final collection in types) {
        try {
          final doc = await db.collection(collection).doc(id).get();
          if (doc.exists) {
            report = await ReportMapLocationResolver().resolve(doc.data()!);
            break;
          }
        } on FirebaseException {
          // A legacy report may be unavailable to the notification recipient.
          continue;
        }
      }
    }
    // Explicit report coordinates may be included when the source is private.
    report ??= ReportMapLocationResolver.siteLocation({
      'location': alert['reportLocation'],
    });
    return (report: report, farms: farms);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Could not load map locations. Close and reopen this view to retry.',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 320,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final data = snapshot.data!;
      final points = [
        if (data.report != null) data.report!,
        ...data.farms.expand((p) => p),
      ];
      if (points.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No saved report location or farm boundary is available for this alert.',
          ),
        );
      }
      final fit = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(48),
        maxZoom: 17,
      );
      return Column(
        children: [
          SizedBox(
            height: 340,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _controller,
                    options: MapOptions(initialCameraFit: fit),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=s,h&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.visaia.app',
                      ),
                      PolygonLayer(
                        polygons: data.farms
                            .map(
                              (p) => Polygon(
                                points: p,
                                color: const Color(
                                  0xFF0D4D33,
                                ).withValues(alpha: 0.25),
                                borderColor: const Color(0xFF8DBA60),
                                borderStrokeWidth: 3,
                              ),
                            )
                            .toList(),
                      ),
                      MarkerLayer(
                        markers: [
                          if (data.report != null)
                            Marker(
                              point: data.report!,
                              width: 48,
                              height: 48,
                              child: const Tooltip(
                                message: 'Report location',
                                child: Icon(
                                  Icons.location_pin,
                                  color: Color(0xFFDC2626),
                                  size: 44,
                                  semanticLabel: 'Report location',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          IconButton(
                            tooltip: 'Zoom in',
                            icon: const Icon(Icons.add),
                            onPressed: () => _controller.move(
                              _controller.camera.center,
                              (_controller.camera.zoom + 1).clamp(2, 20),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Zoom out',
                            icon: const Icon(Icons.remove),
                            onPressed: () => _controller.move(
                              _controller.camera.center,
                              (_controller.camera.zoom - 1).clamp(2, 20),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Show report and farms',
                            icon: const Icon(Icons.center_focus_strong),
                            onPressed: () => _controller.fitCamera(fit),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Red pin: report location · Green outline: your farm area',
            ),
          ),
          if (data.report == null)
            const Text(
              'The report location is unavailable. Only your saved farm boundaries are shown.',
            ),
          if (data.farms.isEmpty)
            const Text(
              'No saved farm boundary is available. Only the report location is shown.',
            ),
        ],
      );
    },
  );
}
