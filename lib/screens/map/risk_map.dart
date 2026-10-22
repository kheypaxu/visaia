import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/faw_risk_service.dart';
import 'package:visaia/services/report_map_location_resolver.dart';

enum PestLifeStage {
  all,
  egg,
  larva,
  pupa,
  moth,
}

class RiskMapScreen extends StatefulWidget {
  const RiskMapScreen({super.key});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
  // Keep map messages on this route so they cannot follow users off the map.
  final _snackBarMessengerKey = GlobalKey<ScaffoldMessengerState>();

  void _showMapSnackBar(SnackBar snackBar) {
    final messenger = _snackBarMessengerKey.currentState;
    if (!mounted || messenger == null) return;
    messenger
      ..clearSnackBars()
      ..removeCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

  Widget _snackBarCloseButton() {
    return IconButton(
      tooltip: 'Close report details',
      icon: const Icon(Icons.close_rounded),
      color: Colors.white,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () => _snackBarMessengerKey.currentState?.removeCurrentSnackBar(),
    );
  }

  // Data
  List<FieldData> _fields = [];
  FarmData? _farm;
  bool _isLoading = true;
  LatLng? _initialCenter;
  double? _initialZoom;
  final MapController _mapController = MapController();
  
  // Risk data
  PestLifeStage _selectedStage = PestLifeStage.all;
  List<RiskPoint> _riskPoints = [];
  List<RiskZone> _riskZones = [];
  List<ReportData> _reports = [];
  bool _showSourceReports = false;

  // Nearby moth threats from other farmers (and own scouting records)
  final List<FawThreat> _threats = [];
  final FawRiskService _riskService = FawRiskService();
  bool _isLoadingThreats = false;

  // ========== CACHED MAP LAYERS ==========
  // Cache map objects to prevent recreation on every build
  final List<Polygon> _cachedPolygons = [];
  final List<Marker> _cachedMarkers = [];
  final List<CircleMarker> _cachedCircles = [];
  final List<Polyline> _cachedPolylines = [];
  
  // Track if cache needs rebuilding
  bool _needsCacheRebuild = true;
  
  // Debounce timer for rebuilds
  Timer? _rebuildTimer;

  // Rendering limits
  static const int maxFieldsRender = 25;
  static const int maxRiskPointsRender = 200;

  @override
  void initState() {
    super.initState();
    _fetchFarmAndFields();
    _loadRiskData();
    _loadReports();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _rebuildTimer?.cancel();
    // Clear cached data
    _cachedPolygons.clear();
    _cachedMarkers.clear();
    _cachedCircles.clear();
    _cachedPolylines.clear();
    super.dispose();
  }

  // Helper method for safe double conversion
  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadReports() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? AuthCacheService().cachedUid;
      if (userId == null) return;

      // Use farmerId if your documents have that field
      QuerySnapshot<Map<String, dynamic>> reportsQuery;
      try {
        reportsQuery = await FirebaseFirestore.instance
            .collection('reports')
            .where('farmerId', isEqualTo: userId)
            .limit(200)
            .get();
      } catch (_) {
        reportsQuery = await FirebaseFirestore.instance
            .collection('reports')
            .where('farmerId', isEqualTo: userId)
            .limit(200)
            .get(const GetOptions(source: Source.cache));
      }

      List<ReportData> loadedReports = [];
      final locations = ReportMapLocationResolver();

      for (var doc in reportsQuery.docs) {
        final data = doc.data();
        final reportLocation = await locations.resolve(data, fallbackOwnerId: userId);
        if (reportLocation == null) continue;

        // ----- Extract risk level (5 level gradient) -----
        RiskLevel riskLevel = RiskLevel.normalize(
            data['risk'] ?? data['riskLevel'] ?? data['severity']);

        // ----- Extract life stage -----
        final stageKey = FawStageKey.fromText(
            data['lifeStage'] ?? data['stage'] ?? data['pestStage']);
        final stage = _toPestLifeStage(stageKey);

        loadedReports.add(ReportData(
          id: doc.id,
          location: reportLocation,
          pestType: data['pestType']?.toString() ?? 'Fall Army Worm',
          riskLevel: riskLevel,
          stage: stage,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }

      if (mounted) {
        setState(() {
          _reports = loadedReports;
          _needsCacheRebuild = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading reports: $e");
    }
  }

  Future<void> _fetchFarmAndFields() async {
    bool isTimeout = false;
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _isLoading) {
        isTimeout = true;

        setState(() {
          _isLoading = false;
        });

        _showMapSnackBar(
          const SnackBar(
            content: Text(
              'Loading timeout. Please check your connection and try again.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? AuthCacheService().cachedUid;
      debugPrint("CURRENT USER ID: $userId");
      
      if (userId == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showMapSnackBar(
            const SnackBar(
              content: Text('User not authenticated. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Fetch farms
      QuerySnapshot<Map<String, dynamic>> farmsQuery;
      try {
        farmsQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('farms')
            .get()
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        farmsQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('farms')
            .get(const GetOptions(source: Source.cache));
      }

      FarmData? loadedFarm;
      
      if (farmsQuery.docs.isNotEmpty) {
        final farmDoc = farmsQuery.docs.first;
        final farmData = farmDoc.data();
        
        List<LatLng> farmBoundaries = [];
        if (farmData['boundaries'] != null && farmData['boundaries'] is List) {
          final boundaries = farmData['boundaries'] as List;
          farmBoundaries = boundaries
              .where((point) => point is Map && point.containsKey('lat') && point.containsKey('lng'))
              .map((point) {
            try {
              final lat = _safeToDouble(point['lat']);
              final lng = _safeToDouble(point['lng']);
              return LatLng(lat, lng);
            } catch (e) {
              debugPrint('Error parsing farm boundary point: $e');
              return null;
            }
          })
              .whereType<LatLng>()
              .toList();
        }

        loadedFarm = FarmData(
          id: farmDoc.id,
          name: farmData['name']?.toString() ?? 'Farm',
          acres: _safeToDouble(farmData['acres']),
          boundaries: farmBoundaries,
        );
      }

      // Fetch fields with limit
      final fieldsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('fields')
          .limit(maxFieldsRender) // Apply limit at query level
          .get()
          .timeout(const Duration(seconds: 10));

      List<FieldData> loadedFields = [];
      for (var doc in fieldsQuery.docs) {
        final fieldData = doc.data();
        List<LatLng> boundaries = [];
        
        if (fieldData['boundaries'] != null && fieldData['boundaries'] is List) {
          final boundariesList = fieldData['boundaries'] as List;
          boundaries = boundariesList
              .where((point) => point is Map && point.containsKey('lat') && point.containsKey('lng'))
              .map((point) {
            try {
              final lat = _safeToDouble(point['lat']);
              final lng = _safeToDouble(point['lng']);
              return LatLng(lat, lng);
            } catch (e) {
              debugPrint('Error parsing field boundary point for ${doc.id}: $e');
              return null;
            }
          })
              .whereType<LatLng>()
              .toList();
        }

        loadedFields.add(FieldData(
          id: doc.id,
          name: fieldData['name']?.toString() ?? 'Unnamed Field',
          acres: _safeToDouble(fieldData['acres']),
          boundaries: boundaries,
          crop: fieldData['crop']?.toString(),
          createdAt: (fieldData['createdAt'] as Timestamp?)?.toDate(),
        ));
      }

      if (mounted && !isTimeout) {
        setState(() {
          _farm = loadedFarm;
          _fields = loadedFields;
          _isLoading = false;
          _needsCacheRebuild = true; // Mark cache as dirty
        });

        _calculateInitialMapView();
        await _loadThreats();
      }
      
    } catch (e, stackTrace) {
      debugPrint('Error fetching data: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted && !isTimeout) {
        setState(() {
          _isLoading = false;
        });
        
        _showMapSnackBar(
          SnackBar(
            content: Text('Failed to load farm data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Loads the nearby FAW threats that can reach this farm.
  ///
  /// Adult moths are winged dispersers, so any moth bearing report or
  /// weekly scouting record inside the 5 km flight radius of one of the
  /// user's fields is a live threat for this farm.
  Future<void> _loadThreats() async {
    final userId = FirebaseAuth.instance.currentUser?.uid ??
        AuthCacheService().cachedUid;
    if (userId == null) return;

    setState(() => _isLoadingThreats = true);

    try {
      final anchors = <LatLng>[];
      for (final field in _fields) {
        if (field.boundaries.length >= 3) {
          anchors.add(polygonCenter(field.boundaries));
        }
      }
      if (_farm != null && _farm!.boundaries.length >= 3) {
        anchors.add(polygonCenter(_farm!.boundaries));
      }

      final threats = await _riskService.loadMothThreats(
        currentUserId: userId,
        anchors: anchors,
      );

      if (!mounted) return;
      setState(() {
        _threats
          ..clear()
          ..addAll(threats);
        _isLoadingThreats = false;
        _needsCacheRebuild = true;
      });
    } catch (e) {
      debugPrint('Error loading nearby threats: $e');
      if (mounted) setState(() => _isLoadingThreats = false);
    }
  }

  void _calculateInitialMapView() {
    try {
      List<LatLng> allPoints = [];
      
      if (_farm != null && _farm!.boundaries.isNotEmpty) {
        allPoints.addAll(_farm!.boundaries);
      }
      
      for (var field in _fields) {
        allPoints.addAll(field.boundaries);
      }

      if (allPoints.isEmpty) {
        _initialCenter = const LatLng(10.7648, 122.5560);
        _initialZoom = 15.0;
        
        if (mounted) {
          setState(() {});
        }
        return;
      }

      // Safe bounds calculation without reduce
      double minLat = allPoints[0].latitude;
      double maxLat = allPoints[0].latitude;
      double minLng = allPoints[0].longitude;
      double maxLng = allPoints[0].longitude;
      
      for (var point in allPoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }

      _initialCenter = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );

      double latDiff = maxLat - minLat;
      double lngDiff = maxLng - minLng;
      double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;
      
      // Calculate zoom level
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
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error calculating map view: $e');
      _initialCenter = const LatLng(10.7648, 122.5560);
      _initialZoom = 15.0;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _loadRiskData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? AuthCacheService().cachedUid;
      if (userId == null) return;

      // Fetch risk points with limit
      QuerySnapshot<Map<String, dynamic>> riskQuery;
      try {
        riskQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('risk_points')
            .limit(maxRiskPointsRender)
            .get()
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        riskQuery = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('risk_points')
            .limit(maxRiskPointsRender)
            .get(const GetOptions(source: Source.cache));
      }

      List<RiskPoint> loadedPoints = [];
      for (var doc in riskQuery.docs) {
        final data = doc.data();
        try {
          final stageString = data['stage']?.toString() ?? 'egg';
          final stage = _toPestLifeStage(
              FawStageKey.fromText(stageString == 'egg' ? 'egg' : stageString));

          final riskLevel = RiskLevel.normalize(
              data['riskLevel'] ?? data['risk'] ?? 'low');

          loadedPoints.add(RiskPoint(
            id: doc.id,
            location: LatLng(
              _safeToDouble(data['lat']),
              _safeToDouble(data['lng']),
            ),
            stage: stage,
            riskLevel: riskLevel,
            detectedAt: (data['detectedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ));
        } catch (e) {
          debugPrint('Error parsing risk point ${doc.id}: $e');
        }
      }

      // Fetch risk zones
      final zonesQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('risk_zones')
          .get()
          .timeout(const Duration(seconds: 10));

      List<RiskZone> loadedZones = [];
      for (var doc in zonesQuery.docs) {
        final data = doc.data();
        try {
          final stageString = data['stage']?.toString() ?? 'moth';
          PestLifeStage stage = PestLifeStage.moth;
          if (stageString.toLowerCase() == 'moth') {
            stage = PestLifeStage.moth;
          }

          loadedZones.add(RiskZone(
            id: doc.id,
            center: LatLng(
              _safeToDouble(data['lat']),
              _safeToDouble(data['lng']),
            ),
            radius: _safeToDouble(data['radius']),
            stage: stage,
            riskLevel: RiskLevel.high,
          ));
        } catch (e) {
          debugPrint('Error parsing risk zone ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          if (loadedPoints.isNotEmpty) _riskPoints = loadedPoints;
          if (loadedZones.isNotEmpty) _riskZones = loadedZones;
          _needsCacheRebuild = true; // Mark cache as dirty
        });
      }
    } catch (e) {
      debugPrint('Error loading risk data: $e');
    }
  }

  // ========== OPTIMIZED LAYER BUILDING ==========
  
  /// Rebuild cached map layers only when needed (debounced)
  void _rebuildMapLayersIfNeeded() {
    if (!_needsCacheRebuild) return;
    
    // Debounce rebuilds to prevent multiple rapid recalculations
    _rebuildTimer?.cancel();
    _rebuildTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _buildOptimizedLayers();
        setState(() {
          _needsCacheRebuild = false;
        });
      }
    });
  }

  /// Build all map layers efficiently and cache them
  void _buildOptimizedLayers() {
    // Clear existing caches
    _cachedPolygons.clear();
    _cachedMarkers.clear();
    _cachedCircles.clear();
    _cachedPolylines.clear();

    // Build polygons from fields
    for (int i = 0; i < _fields.length && i < maxFieldsRender; i++) {
      final field = _fields[i];
      if (field.boundaries.isNotEmpty && field.boundaries.length >= 3) {
        _cachedPolygons.add(
          Polygon(
            points: field.boundaries,
            color: const Color(0xFFFFBA27).withValues(alpha: 0.2),
            borderColor: const Color(0xFFFFBA27),
            borderStrokeWidth: 2,
          ),
        );
      }
    }

    // Build farm boundary as SIMPLE polyline (no more dashed segments)
    if (_farm != null && _farm!.boundaries.isNotEmpty) {
      final closedBoundary = List<LatLng>.from(_farm!.boundaries);
      if (closedBoundary.first != closedBoundary.last) {
        closedBoundary.add(closedBoundary.first);
      }
      _cachedPolylines.add(
        Polyline(
          points: closedBoundary,
          color: const Color(0xFF8DBA60),
          strokeWidth: 3,
        ),
      );
    }

  // Build risk markers (limit to MAX_RISK_POINTS_RENDER)
  int markerCount = 0;
  for (var point in _riskPoints) {
    if (markerCount >= maxRiskPointsRender) break;
    if (_selectedStage == PestLifeStage.all || point.stage == _selectedStage) {
      final radius = _getSpreadRadiusMeters(point.stage, point.riskLevel);
      if (radius > 0) {
        _cachedCircles.add(
          CircleMarker(
            point: point.location,
            radius: radius,
            useRadiusInMeter: true,
            color: _getRiskColor(point.riskLevel).withValues(alpha: 0.15),
            borderColor: _getRiskColor(point.riskLevel),
            borderStrokeWidth: 2,
          ),
        );
      }
      markerCount++;
    }
  }

    // Build risk zones
    if (_selectedStage == PestLifeStage.moth ||
        _selectedStage == PestLifeStage.all) {
      for (var zone in _riskZones) {
        if ((_selectedStage == PestLifeStage.all ||
              zone.stage == _selectedStage) &&
          zone.radius > 0) {
          // Limit radius to reasonable size (max 5km)
          _cachedCircles.add(
            CircleMarker(
              point: zone.center,
              radius: _getSpreadRadiusMeters(
                zone.stage,
                zone.riskLevel,
              ),
              color: _getRiskColor(zone.riskLevel).withValues(alpha: 0.3),
              borderColor: _getRiskColor(zone.riskLevel),
              borderStrokeWidth: 2,
            ),
          );
        }
      }
    }

      for (var report in _reports) {
      if (_hasThreatSource(report.id)) continue;

      if (_selectedStage != PestLifeStage.all &&
          report.stage != _selectedStage) {
        continue;
      }

    _cachedCircles.add(
      CircleMarker(
        point: report.location,
        radius: _getSpreadRadiusMeters(report.stage, report.riskLevel),
        useRadiusInMeter: true,
        color: _getRiskColor(report.riskLevel).withValues(alpha: 0.15),
        borderColor: _getRiskColor(report.riskLevel),
        borderStrokeWidth: 2,
      ),
    );
  }

  // Nearby moth threats from other farmers (and own scouting records).
  for (final threat in _threats) {
    if (_selectedStage != PestLifeStage.all &&
        _selectedStage != PestLifeStage.moth) {
      continue;
    }

    // Adult moth flight / monitoring zone (wind scaled).
    _cachedCircles.add(
      CircleMarker(
        point: threat.location,
        radius: threat.radiusM,
        useRadiusInMeter: true,
        color: _getMothZoneColor(threat.riskLevel).withValues(alpha: 0.10),
        borderColor: _getMothZoneColor(threat.riskLevel),
        borderStrokeWidth: 1.5,
      ),
    );

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
        AuthCacheService().cachedUid;
    if (_showSourceReports &&
        threat.ownerId.isNotEmpty &&
        threat.ownerId != currentUserId) {
      _cachedMarkers.add(
      Marker(
        point: threat.location,
        width: 48,
        height: 48,
        alignment: Alignment.bottomCenter,
        child: _buildThreatMarker(threat),
      ),
    );
    }
  }
  }

  /// Nearby report pins show the detected pest rather than a warning triangle.
  Widget _buildThreatMarker(FawThreat threat) {
    final label = '${threat.stage.label} report - ${threat.riskLevel.label} risk';
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(
          onTap: () => _showThreatDetails(threat),
          child: Container(
            decoration: BoxDecoration(
              color: threat.riskLevel.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: threat.riskLevel.color.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ExcludeSemantics(
              child: Icon(
                _getStageIcon(_toPestLifeStage(threat.stage)),
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Proximity monitoring zones in metres.
  ///
  /// Mirrors the dashboard risk map: larvae are ground bound (2-10 m
  /// depending on risk), adult moths are winged dispersers (5 km flight
  /// radius) and eggs / pupae do not move so they get no zone.
  double _getSpreadRadiusMeters(PestLifeStage stage, RiskLevel risk) {
    switch (stage) {
      case PestLifeStage.all:
        return 0;
      case PestLifeStage.egg:
        return 0; // no proximity
      case PestLifeStage.larva:
        switch (risk) {
          case RiskLevel.veryHigh:
          case RiskLevel.high:
            return 10;
          case RiskLevel.moderate:
            return 5;
          case RiskLevel.low:
          case RiskLevel.veryLow:
            return 2;
        }
      case PestLifeStage.pupa:
        return 0; // pupae don't move much
      case PestLifeStage.moth:
        return (FawRiskService.mothRadiusKm * 1000).roundToDouble();
    }
  }

  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      camera.zoom + 1,
    );
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      camera.zoom - 1,
    );
  }

  void _centerOnFarm() {
    if (_farm != null && _farm!.boundaries.isNotEmpty) {
      final center = _calculatePolygonCenter(_farm!.boundaries);
      _mapController.move(center, 18);
    } else if (_fields.isNotEmpty && _fields.first.boundaries.isNotEmpty) {
      final center = _calculatePolygonCenter(_fields.first.boundaries);
      _mapController.move(center, 18);
    }
  }

  bool _hasThreatSource(String reportId) =>
      _threats.any((threat) => !threat.isClustered && threat.id == reportId);

  bool _matchesStage(PestLifeStage stage) =>
      _selectedStage == PestLifeStage.all || _selectedStage == stage;

  void _showFarmRiskSources({LatLng? at}) {
    final distance = const Distance();
    final threats = _threats.where((threat) =>
      _matchesStage(PestLifeStage.moth) &&
      (at == null || distance.as(LengthUnit.Meter, at, threat.location) <= threat.radiusM)).toList();
    final reports = _reports.where((report) =>
      !_hasThreatSource(report.id) && _matchesStage(report.stage) &&
      (at == null || distance.as(LengthUnit.Meter, at, report.location) <=
        _getSpreadRadiusMeters(report.stage, report.riskLevel))).toList();
    final points = _riskPoints.where((point) => _matchesStage(point.stage) &&
      (at == null || distance.as(LengthUnit.Meter, at, point.location) <=
        _getSpreadRadiusMeters(point.stage, point.riskLevel))).toList();
    final zones = _riskZones.where((zone) => _matchesStage(zone.stage) && zone.radius > 0 &&
      (at == null || distance.as(LengthUnit.Meter, at, zone.center) <= zone.radius.clamp(100, 5000))).toList();
    if (at != null && threats.isEmpty && reports.isEmpty && points.isEmpty && zones.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * 0.6,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text('Detections & monitoring zones', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Sources matching the selected pest stage. Monitoring zones indicate proximity, not confirmed infestation of your farm.'),
          const SizedBox(height: 12),
          if (threats.isEmpty && reports.isEmpty && points.isEmpty && zones.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No matching detections or monitoring zones found.')),
          for (final threat in threats)
            ListTile(
              leading: Icon(Icons.radar, color: threat.riskLevel.color),
              title: Text('${threat.riskLevel.label} risk - adult moths'),
              subtitle: Text('${threat.isClustered ? 'Weekly scouting' : 'Pest report'} - ${formatKm(threat.distanceKm)} from your farm\n${threat.farmName.isEmpty ? threat.areaName : threat.farmName}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                _showThreatMitigation(threat);
              },
            ),
          for (final report in reports)
            ListTile(
              leading: Icon(_getStageIcon(report.stage), color: report.riskLevel.color),
              title: Text('${report.pestType} - ${report.riskLevel.label} risk'),
              subtitle: Text('On your farm - ${report.stage.name}'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showReportDetails(report);
              },
            ),
          for (final zone in zones)
            ListTile(
              leading: Icon(Icons.radar, color: zone.riskLevel.color),
              title: Text('${zone.riskLevel.label} risk - ${zone.stage.name} zone'),
              subtitle: Text('Saved farm monitoring area - ${(zone.radius.clamp(100, 5000) / 1000).toStringAsFixed(1)} km radius'),
            ),
          for (final point in points)
            ListTile(
              leading: Icon(_getStageIcon(point.stage), color: point.riskLevel.color),
              title: Text('${point.stage.name} - ${point.riskLevel.label} risk'),
              subtitle: const Text('Farm risk observation'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showRiskDetails(point);
              },
            ),
        ]),
      )),
    );
  }

  void _showReportDetails(ReportData report) {
    _showMapSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        showCloseIcon: true,
        closeIconColor: Colors.white,
        dismissDirection: DismissDirection.down,

        content: Text(
          "Report: ${report.pestType} • "
          "${report.riskLevel.label} risk",
        ),
      ),
    );
  }

  /// Floating snack bar for a nearby moth threat. Shows what happened,
  /// how far away it is and offers the mitigation strategy.
  void _showThreatDetails(FawThreat threat) {
    final accent = threat.riskLevel.color;
    final steps = threat.mitigationSteps;

    _showMapSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          dismissDirection: DismissDirection.down,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 10),
          margin: const EdgeInsets.all(16),
          content: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.94),
                  const Color(0xFF14532D),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------- HEADER ----------
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.flutter_dash,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "MOTH ACTIVITY NEAR YOUR FARM",
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _riskBadge(threat.riskLevel),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  threat.isClustered
                                      ? "Weekly scouting"
                                      : "Pest report",
                                  style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _snackBarCloseButton(),
                  ],
                ),
                const SizedBox(height: 16),

                // ---------- DETAILS ----------
                _infoRow(
                  Icons.radar,
                  "Distance from your farm",
                  formatKm(threat.distanceKm),
                ),
                _infoRow(
                  Icons.my_location,
                  "Monitoring zone",
                  '${(threat.radiusM / 1000).toStringAsFixed(1)} km'
                      '${threat.windSpeedKmh != null ? ' (wind ${threat.windSpeedKmh!.toStringAsFixed(0)} km/h)' : ''}',
                ),
                _infoRow(
                  Icons.location_on,
                  "Reported at",
                  threat.areaName.isNotEmpty
                      ? threat.areaName
                      : (threat.barangay.isNotEmpty
                          ? threat.barangay
                          : 'Unknown area'),
                ),
                _infoRow(
                  Icons.agriculture,
                  "Crop stage at detection",
                  "${threat.growthStage.label} (DAP ${threat.dap})",
                ),
                _infoRow(
                  Icons.bug_report,
                  "Observed",
                  _threatCountsLabel(threat),
                ),

                const SizedBox(height: 6),

                // ---------- MITIGATION CTA ----------
                GestureDetector(
                  onTap: () => _showThreatMitigation(threat),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.health_and_safety_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          steps.isEmpty
                              ? "VIEW DETAILS"
                              : "VIEW MITIGATION STRATEGY",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  String _threatCountsLabel(FawThreat threat) {
    final parts = <String>[];
    if (threat.moths > 0) parts.add('${threat.moths} moth${threat.moths == 1 ? '' : 's'}');
    if (threat.larvae > 0) parts.add('${threat.larvae} larvae');
    if (threat.eggs > 0) parts.add('${threat.eggs} egg masses');
    if (threat.pupae > 0) parts.add('${threat.pupae} pupae');
    if (parts.isEmpty) parts.add('Adult moth recorded');
    return parts.join(' • ');
  }

  Widget _riskBadge(RiskLevel level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: level.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "${level.label.toUpperCase()} RISK",
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Bottom sheet with the full information and the mitigation strategies
  /// recorded for a nearby threat.
  void _showThreatMitigation(FawThreat threat) {
    final steps = threat.mitigationSteps;
    final accent = threat.riskLevel.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      children: [
                        // ---------- HEADER ----------
                        Row(
                          children: [
                            _riskBadge(threat.riskLevel),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                threat.isClustered
                                    ? 'Weekly scouting report'
                                    : 'Pest report',
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          threat.detection,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1A1C1E),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${formatKm(threat.distanceKm)} from your farm'
                          '${threat.areaName.isNotEmpty ? ' • ${threat.areaName}' : ''}',
                          style: GoogleFonts.inter(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ---------- WHY IT MATTERS ----------
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      size: 16, color: accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'WHY THIS AFFECTS YOUR FARM',
                                    style: GoogleFonts.inter(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Adult moths are the dispersal stage of the fall armyworm. '
                                'They live 7-13 days and each female can lay about 950 eggs, '
                                'so a single detection inside the 5-10 km flight zone '
                                '(scaled by the wind recorded at the detection point) '
                                'can seed a new infestation in your field.',
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade800,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // ---------- FACTS ----------
                        _factRow(Icons.agriculture, 'Crop growth stage',
                            '${threat.growthStage.label} (DAP ${threat.dap})'),
                        _factRow(Icons.bug_report, 'Observed',
                            _threatCountsLabel(threat)),
                        _factRow(Icons.radar, 'Monitoring zone',
                            '${(threat.radiusM / 1000).toStringAsFixed(1)} km'
                            '${threat.windSpeedKmh != null ? ' (wind ${threat.windSpeedKmh!.toStringAsFixed(0)} km/h)' : ''}'),
                        _factRow(Icons.grass, 'Barangay',
                            threat.barangay.isNotEmpty ? threat.barangay : '—'),
                        _factRow(Icons.person_outline, 'Reported by',
                            threat.farmerName.isNotEmpty ? threat.farmerName : '—'),
                        if (threat.fieldName.isNotEmpty)
                          _factRow(Icons.landscape, 'Field',
                              threat.fieldName),
                        if (threat.damagePercentage > 0)
                          _factRow(Icons.trending_down, 'Plant damage',
                              '${threat.damagePercentage.toStringAsFixed(1)}%'
                              '${threat.thresholdReached ? ' • threshold exceeded' : ''}'),

                        const SizedBox(height: 18),

                        // ---------- MITIGATION ----------
                        Text(
                          'MITIGATION STRATEGIES',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF1A1C1E),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (steps.isEmpty)
                          Text(
                            'No mitigation strategy has been recorded for this detection yet. '
                            'Scout your nearest fields for egg masses and larvae, and set up '
                            'pheromone traps to monitor adult activity.',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          )
                        else
                          ...steps.asMap().entries.map(
                                (entry) => _buildMitigationStep(
                                  entry.key + 1,
                                  entry.value.title,
                                  entry.value.body,
                                  accent,
                                ),
                              ),

                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8F4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF81C784).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.shield_moon_outlined,
                                      color: Color(0xFF1B5E37), size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'LOCAL ACTION CHECKLIST',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF1B5E37),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...const [
                                'Scout the nearest 5 km for egg masses and feeding damage.',
                                'Install or refresh pheromone traps to track adult moth activity.',
                                'Increase inspection frequency to weekly during the vulnerable stage.',
                                'Report any egg mass or larva you find immediately.',
                              ].map(
                                (line) => Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ',
                                          style: TextStyle(
                                              color: Color(0xFF1B5E37),
                                              fontSize: 13)),
                                      Expanded(
                                        child: Text(
                                          line,
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF2E6347),
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _factRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey.shade700,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: const Color(0xFF1A1C1E),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMitigationStep(int index, String title, String body, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A1C1E),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: body,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.inter(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
              listBullet: GoogleFonts.inter(
                fontSize: 13,
                height: 1.4,
                color: Colors.grey.shade800,
              ),
              strong: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1C1E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(RiskLevel level) => level.color;

  /// The dashboard's moth monitoring zone colours (violet family).
  Color _getMothZoneColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.veryHigh:
      case RiskLevel.high:
        return const Color(0xFF8B5CF6);
      case RiskLevel.moderate:
        return const Color(0xFFA855F7);
      case RiskLevel.low:
      case RiskLevel.veryLow:
        return const Color(0xFF7C3AED);
    }
  }

  PestLifeStage _toPestLifeStage(FawStageKey stage) {
    switch (stage) {
      case FawStageKey.egg:
        return PestLifeStage.egg;
      case FawStageKey.larva:
        return PestLifeStage.larva;
      case FawStageKey.pupa:
        return PestLifeStage.pupa;
      case FawStageKey.moth:
        return PestLifeStage.moth;
      case FawStageKey.none:
        return PestLifeStage.egg;
    }
  }

  IconData _getStageIcon(PestLifeStage stage) {
    switch (stage) {

      case PestLifeStage.all:
        return Icons.public;

      case PestLifeStage.egg:
        return Icons.circle;

      case PestLifeStage.larva:
        return Icons.bug_report;

      case PestLifeStage.pupa:
        return Icons.pest_control;

      case PestLifeStage.moth:
        return Icons.flutter_dash;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _snackBarMessengerKey,
      child: _buildMap(context),
    );
  }

  Widget _buildMap(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading farm data...'),
            ],
          ),
        ),
      );
    }

    if ((_farm == null || _farm!.boundaries.isEmpty) && _fields.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "No farm data available",
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please create a farm first",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Rebuild cached layers when needed
    _rebuildMapLayersIfNeeded();

    return Scaffold(
      body: Stack(
        children: [
          /// MAP LAYER - Using cached objects
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter ?? const LatLng(10.7648, 122.5560),
              initialZoom: _initialZoom ?? 15,
              onTap: (_, point) => _showFarmRiskSources(at: point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=s,h&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.visaia.app',
              ),
              // Use cached layers
              if (_cachedPolygons.isNotEmpty) 
                PolygonLayer(polygons: _cachedPolygons),
              if (_cachedPolylines.isNotEmpty) 
                PolylineLayer(polylines: _cachedPolylines),
              if (_cachedCircles.isNotEmpty) 
                CircleLayer(circles: _cachedCircles),
              if (_cachedMarkers.isNotEmpty) 
                MarkerLayer(markers: _cachedMarkers),
            ],
          ),

          /// BACK BUTTON
          Positioned(
            top: 50,
            left: 15,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),

          /// HEADER
          Positioned(
            top: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Risk Map - ${_farm?.name ?? 'Your Farm'}",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(blurRadius: 10, color: Colors.black45)],
                ),
              ),
            ),
          ),

          /// NEARBY THREAT BADGE
          if (_isLoadingThreats)
            Positioned(
              top: 86,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFFA855F7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Scanning nearby farms for moth activity...',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_threats.isNotEmpty)
            Positioned(
              top: 86,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _showFarmRiskSources();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.7),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flutter_dash,
                            size: 14, color: Color(0xFFA855F7)),
                        const SizedBox(width: 6),
                        Text(
                          '${_threats.length} moth monitoring zone${_threats.length == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _threats.first.riskLevel.color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _threats.first.riskLevel.label.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          /// LIFE STAGE TOGGLE BUTTONS (Horizontal Scroll)
          Positioned(
            top: 120,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(30),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stageButton(PestLifeStage.all, "All", Icons.public),
                    const SizedBox(width: 8),
                    _stageButton(PestLifeStage.egg, "Eggs", Icons.circle),
                    const SizedBox(width: 8),
                    _stageButton(PestLifeStage.larva, "Larvae", Icons.bug_report),
                    const SizedBox(width: 8),
                    _stageButton(PestLifeStage.pupa, "Pupae", Icons.pest_control),
                    const SizedBox(width: 8),
                    _stageButton(PestLifeStage.moth, "Moths", Icons.flutter_dash),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: 184, left: 15, right: 15,
            child: Material(
              color: Colors.black.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SwitchListTile.adaptive(
                  dense: true,
                  title: const Text('Show nearby report pins', style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Your own report pins stay hidden.',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                  value: _showSourceReports,
                  onChanged: (value) => setState(() {
                    _showSourceReports = value;
                    _needsCacheRebuild = true;
                  }),
                ),
                TextButton.icon(
                  onPressed: () => _showFarmRiskSources(),
                  icon: const Icon(Icons.radar, color: Colors.white, size: 18),
                  label: const Text('View detections & zones affecting my farm',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ]),
            ),
          ),

          /// RISK LEGEND
          Positioned(
            bottom: 120,
            left: 15,
            child: _buildRiskLegend(),
          ),

          /// CONTROLS
          Positioned(
            bottom: 120,
            right: 15,
            child: Column(
              children: [
                Row(
                  children: [
                    _roundButton(Icons.add, onTap: _zoomIn),
                    const SizedBox(width: 10),
                    _roundButton(Icons.remove, onTap: _zoomOut),
                    const SizedBox(width: 10),
                    _roundButton(Icons.explore, onTap: _centerOnFarm),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageButton(PestLifeStage stage, String label, IconData icon) {
    final isSelected = _selectedStage == stage;
    final Color stageColor = _getStageColor(stage);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStage = stage;
          _needsCacheRebuild = true; // Mark cache as dirty when stage changes
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? stageColor.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? stageColor : Colors.white54,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? stageColor : Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? stageColor : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStageColor(PestLifeStage stage) {
    switch (stage) {

      case PestLifeStage.all:
        return Colors.white;

      case PestLifeStage.egg:
        return const Color(0xFFFFEB3B);

      case PestLifeStage.larva:
        return const Color(0xFFFF9800);

      case PestLifeStage.pupa:
        return const Color(0xFF4CAF50);

      case PestLifeStage.moth:
        return const Color(0xFF9C27B0);
    }
  }

  Widget _buildRiskLegend() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          color: Colors.black.withValues(alpha: 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("RISK LEVELS",
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 6),
              _legendItem(RiskLevel.veryLow.color, "Very Low"),
              _legendItem(RiskLevel.low.color, "Low"),
              _legendItem(RiskLevel.moderate.color, "Moderate"),
              _legendItem(RiskLevel.high.color, "High"),
              _legendItem(RiskLevel.veryHigh.color, "Very High"),
              if (_threats.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Divider(color: Colors.white24, height: 12),
                _legendItem(const Color(0xFF8B5CF6),
                    "Moth zone (5-10 km)"),
              ],
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
              ),
            ),
            const SizedBox(width: 8),
            Text(text, 
              style: const TextStyle(color: Colors.white, fontSize: 10)
            ),
          ],
        ),
      );
    }

    Widget _infoRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 10),

          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),

          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showRiskDetails(RiskPoint point) {
    final stage = point.stage.toString().split('.').last.toUpperCase();
    final risk = point.riskLevel.label.toUpperCase();

    final radius = _getSpreadRadiusMeters(point.stage, point.riskLevel);

    _showMapSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        content: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.92),
                const Color(0xFF14532D),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getRiskColor(point.riskLevel),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getStageIcon(point.stage),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$stage DETECTION",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "$risk RISK",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _snackBarCloseButton(),
                ],
              ),
              const SizedBox(height: 18),
              /// DETAILS
              _infoRow(
                Icons.radar,
                "Proximity / Monitoring Zone",
                radius >= 1000
                    ? "${(radius / 1000).toStringAsFixed(1)} km"
                    : "${radius.toInt()} m",
              ),
              _infoRow(
                Icons.access_time,
                "Detected",
                point.detectedAt.toString().substring(0, 19),
              ),
              _infoRow(
                Icons.location_on,
                "Coordinates",
                "${point.location.latitude.toStringAsFixed(5)}, "
                "${point.location.longitude.toStringAsFixed(5)}",
              ),
            ],
          ),
        ),
      ),
    );
  }

  LatLng _calculatePolygonCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(0, 0);
    
    double sumLat = 0;
    double sumLng = 0;
    
    for (var point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }
    
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  Widget _roundButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45, 
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.black87),
      ),
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

class RiskPoint {
  final String id;
  final LatLng location;
  final PestLifeStage stage;
  final RiskLevel riskLevel;
  final DateTime detectedAt;

  RiskPoint({
    required this.id,
    required this.location,
    required this.stage,
    required this.riskLevel,
    required this.detectedAt,
  });
}

class RiskZone {
  final String id;
  final LatLng center;
  final double radius;
  final PestLifeStage stage;
  final RiskLevel riskLevel;

  RiskZone({
    required this.id,
    required this.center,
    required this.radius,
    required this.stage,
    required this.riskLevel,
  });
}

class ReportData {
  final String id;
  final LatLng location;
  final String pestType;
  final RiskLevel riskLevel;
  final DateTime createdAt;
  final PestLifeStage stage;

  ReportData({
    required this.id,
    required this.location,
    required this.pestType,
    required this.riskLevel,
    required this.createdAt,
    required this.stage,
  });
}
