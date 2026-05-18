import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:visaia/core/providers/farm_provider.dart';
import 'package:visaia/screens/map/risk_map.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  List<FieldData> _fields = [];
  FarmData? _farm;
  bool _isLoading = true;
  LatLng? _initialCenter;
  double? _initialZoom;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Read farm from provider on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final farmId = context.read<FarmProvider>().activeFarmId;
      _fetchFarmAndFields(farmId);
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchFarmAndFields(String? farmId) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      DocumentSnapshot<Map<String, dynamic>>? farmDoc;

      if (farmId != null) {
        // Fetch the specific active farm directly by ID
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('farms')
            .doc(farmId)
            .get();
        if (doc.exists) farmDoc = doc;
      } else {
        // Fallback: fetch first farm
        final farmsQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('farms')
            .limit(1)
            .get();
        if (farmsQuery.docs.isNotEmpty) farmDoc = farmsQuery.docs.first;
      }

      if (farmDoc == null) {
        setState(() => _isLoading = false);
        return;
      }

      final farmData = farmDoc.data()!;
      List<LatLng> farmBoundaries = [];
      if (farmData['boundaries'] != null) {
        farmBoundaries = (farmData['boundaries'] as List).map((point) {
          return LatLng(
            (point['lat']).toDouble(),
            (point['lng']).toDouble(),
          );
        }).toList();
      }

      _farm = FarmData(
        id: farmDoc.id,
        name: farmData['name'] ?? 'Farm',
        acres: (farmData['acres'] ?? 0).toDouble(),
        boundaries: farmBoundaries,
      );

      // Fetch fields filtered by farmId
      var fieldsQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fields');

      final fieldsSnapshot = farmId != null
          ? await fieldsQuery.where('farmId', isEqualTo: farmId).get()
          : await fieldsQuery.get();

      List<FieldData> loadedFields = [];
      for (var doc in fieldsSnapshot.docs) {
        final fieldData = doc.data();
        List<LatLng> boundaries = [];

        if (fieldData['boundaries'] != null) {
          boundaries =
              (fieldData['boundaries'] as List).map((point) {
            return LatLng(
              (point['lat']).toDouble(),
              (point['lng']).toDouble(),
            );
          }).toList();
        }

        loadedFields.add(FieldData(
          id: doc.id,
          name: fieldData['name'] ?? 'Unnamed Field',
          acres: (fieldData['acres'] ?? 0).toDouble(),
          boundaries: boundaries,
          crop: fieldData['crop'],
          createdAt: (fieldData['createdAt'] as Timestamp?)?.toDate(),
        ));
      }

      setState(() {
        _fields = loadedFields;
        _isLoading = false;
        _calculateInitialMapView();
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Keep _calculateInitialMapView, _createDashedPolyline, build,
  // _buildMap, and all other methods exactly as they were
  // Only _fetchFarmAndFields changed above

  void _calculateInitialMapView() {
    List<LatLng> allPoints = [];
    if (_farm != null && _farm!.boundaries.isNotEmpty) {
      allPoints.addAll(_farm!.boundaries);
    }
    for (var field in _fields) {
      allPoints.addAll(field.boundaries);
    }

    if (allPoints.isEmpty) {
      _initialCenter = const LatLng(10.7648, 122.5560);
      _initialZoom = 17;
      return;
    }

    double minLat = allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLat = allPoints
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    double minLng = allPoints
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    double maxLng = allPoints
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    _initialCenter = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );

    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff < 0.0005) {
      _initialZoom = 20.0;
    } else if (maxDiff < 0.001) {
      _initialZoom = 19.0;
    } else if (maxDiff < 0.003) {
      _initialZoom = 18.0;
    } else if (maxDiff < 0.005) {
      _initialZoom = 17.0;
    } else if (maxDiff < 0.01) {
      _initialZoom = 16.0;
    } else if (maxDiff < 0.02) {
      _initialZoom = 15.0;
    } else if (maxDiff < 0.05) {
      _initialZoom = 14.0;
    } else {
      _initialZoom = 13.0;
    }
  }

  List<List<LatLng>> _createDashedPolyline(
    List<LatLng> points, {
    double dashLength = 0.00002,
    double gapLength = 0.00005,
  }) {
    List<List<LatLng>> dashedLines = [];
    if (points.length < 2) return dashedLines;

    final closedPoints = [...points];
    if (closedPoints.first != closedPoints.last) {
      closedPoints.add(closedPoints.first);
    }

    for (int i = 0; i < closedPoints.length - 1; i++) {
      final start = closedPoints[i];
      final end = closedPoints[i + 1];
      final dx = end.longitude - start.longitude;
      final dy = end.latitude - start.latitude;
      final distance = math.sqrt(dx * dx + dy * dy);
      final steps = (distance / (dashLength + gapLength)).floor();

      for (int j = 0; j < steps; j++) {
        final startStep = (j * (dashLength + gapLength)) / distance;
        final endStep =
            ((j * (dashLength + gapLength)) + dashLength) / distance;

        dashedLines.add([
          LatLng(start.latitude + dy * startStep,
              start.longitude + dx * startStep),
          LatLng(start.latitude + dy * endStep,
              start.longitude + dx * endStep),
        ]);
      }
    }
    return dashedLines;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_farm == null && _fields.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text("No farm data available",
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600])),
              const SizedBox(height: 8),
              Text("Please create a farm first",
                  style: GoogleFonts.inter(
                      fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _farm?.name ?? "Your Farm",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(blurRadius: 10, color: Colors.black45)
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 15,
            child: Column(
              children: [
                _weatherItem(Icons.wb_sunny_outlined, "14°"),
                _weatherItem(Icons.device_thermostat, "12°",
                    color: Colors.blue),
                _weatherItem(Icons.device_thermostat, "19°",
                    color: Colors.red),
                _weatherItem(Icons.air, "1 km/h"),
                _weatherItem(Icons.water_drop_outlined, "2 mm"),
              ],
            ),
          ),
          Positioned(
              bottom: 100, left: 15, child: _buildLegend()),
          Positioned(
            bottom: 100,
            right: 15,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RiskMapScreen()),
                  ),
                  child: _actionButton(
                    Text("Open Risk Map",
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    width: 140,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _roundButton(Icons.add, onTap: () {
                      final zoom = _mapController.camera.zoom;
                      _mapController.move(
                          _mapController.camera.center, zoom + 1);
                    }),
                    const SizedBox(width: 10),
                    _roundButton(Icons.remove, onTap: () {
                      final zoom = _mapController.camera.zoom;
                      _mapController.move(
                          _mapController.camera.center, zoom - 1);
                    }),
                    const SizedBox(width: 10),
                    _roundButton(Icons.explore, isGreen: false),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    List<Polygon> polygons = [];

    if (_farm != null && _farm!.boundaries.isNotEmpty) {
      polygons.add(Polygon(
        points: _farm!.boundaries,
        color: const Color(0xFF8DBA60).withValues(alpha: 0.08),
        borderColor: Colors.transparent,
        borderStrokeWidth: 0,
      ));
    }

    for (int i = 0; i < _fields.length; i++) {
      final field = _fields[i];
      if (field.boundaries.isNotEmpty) {
        polygons.add(Polygon(
          points: field.boundaries,
          color: const Color(0xFFFFBA27).withValues(alpha: 0.3),
          borderColor: const Color(0xFFFFBA27),
          borderStrokeWidth: 2,
        ));
      }
    }

    List<Marker> markers = [];
    for (int i = 0; i < _fields.length; i++) {
      final field = _fields[i];
      if (field.boundaries.isNotEmpty) {
        final center = _calculatePolygonCenter(field.boundaries);
        markers.add(_buildFieldLabel(center, field.name, i));
      }
    }

    List<Polyline> polylines = [];
    if (_farm != null && _farm!.boundaries.isNotEmpty) {
      final dashedLines = _createDashedPolyline(_farm!.boundaries);
      for (final segment in dashedLines) {
        polylines.add(Polyline(
          points: segment,
          color: const Color(0xFF8DBA60),
          strokeWidth: 2,
        ));
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter ?? const LatLng(10.7648, 122.5560),
        initialZoom: _initialZoom ?? 17,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://mt1.google.com/vt/lyrs=s,h&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.visaia.app',
        ),
        PolygonLayer(polygons: polygons),
        PolylineLayer(polylines: polylines),
        MarkerLayer(markers: markers),
      ],
    );
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    double sumLat = 0, sumLng = 0;
    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  Widget _weatherItem(IconData icon, String value,
      {Color color = Colors.white}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 15),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white.withValues(alpha: 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("LEGEND",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _legendItem(const Color(0xFF1B5E20), "Pheromone Traps"),
              _legendItem(const Color(0xFFFFBA27), "Active Fields"),
              _legendItem(
                  const Color(0xFF8DBA60), "Farm Boundary (Broken Line)"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style:
                  const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }

  Marker _buildFieldLabel(LatLng point, String label, int index) {
    return Marker(
      point: point,
      width: 80,
      height: 40,
      child: Column(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFFFBA27),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFFBA27), width: 1.5),
            ),
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFBA27)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon,
      {bool isGreen = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: isGreen
              ? const Color(0xFF8DBA60)
              : Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87),
      ),
    );
  }

  Widget _actionButton(Widget child, {double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(25),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

// Data Models (unchanged)
class FarmData {
  final String id;
  final String name;
  final double acres;
  final List<LatLng> boundaries;

  FarmData({
    required this.id,
    required this.name,
    required this.acres,
    required this.boundaries,
  });
}

class FieldData {
  final String id;
  final String name;
  final double acres;
  final List<LatLng> boundaries;
  final String? crop;
  final DateTime? createdAt;

  FieldData({
    required this.id,
    required this.name,
    required this.acres,
    required this.boundaries,
    this.crop,
    this.createdAt,
  });
}