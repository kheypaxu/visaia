import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/services/auth_cache_service.dart';

enum PestLifeStage {
  all,
  egg,
  larva,
  pupa,
  moth,
}

enum RiskLevel {
  low,
  medium,
  high,
  critical,
}

class RiskMapScreen extends StatefulWidget {
  const RiskMapScreen({super.key});

  @override
  State<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends State<RiskMapScreen> {
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

      for (var doc in reportsQuery.docs) {
        final data = doc.data();
        debugPrint("REPORT DATA: $data");

        // ----- Extract location (nested) -----
        double lat = 0, lng = 0;
        final locationField = data['location'];
        if (locationField is Map) {
          lat = _safeToDouble(locationField['lat']);
          lng = _safeToDouble(locationField['lng']);
        } else if (locationField is GeoPoint) {
          lat = locationField.latitude;
          lng = locationField.longitude;
        } else {
          // Fallback to top-level lat/lng if they exist
          lat = _safeToDouble(data['lat']);
          lng = _safeToDouble(data['lng']);
        }

        if (lat == 0 || lng == 0) continue;

        // ----- Extract risk level (handle both 'risk' and 'riskLevel') -----
        String? riskStr = data['risk']?.toString().toLowerCase();
        riskStr ??= data['riskLevel']?.toString().toLowerCase();
        RiskLevel riskLevel = RiskLevel.low;
        switch (riskStr) {
          case 'medium':
            riskLevel = RiskLevel.medium;
            break;
          case 'high':
            riskLevel = RiskLevel.high;
            break;
          case 'critical':
            riskLevel = RiskLevel.critical;
            break;
        }

        // ----- Extract life stage -----
        String? stageStr = data['lifeStage']?.toString().toLowerCase();
        stageStr ??= data['stage']?.toString().toLowerCase(); // fallback
        PestLifeStage stage = PestLifeStage.egg;
        switch (stageStr) {
          case 'larva':
            stage = PestLifeStage.larva;
            break;
          case 'pupa':
            stage = PestLifeStage.pupa;
            break;
          case 'moth':
            stage = PestLifeStage.moth;
            break;
        }

        loadedReports.add(ReportData(
          id: doc.id,
          location: LatLng(lat, lng),
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

        ScaffoldMessenger.of(context).showSnackBar(
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
          ScaffoldMessenger.of(context).showSnackBar(
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
      }
      
    } catch (e, stackTrace) {
      debugPrint('Error fetching data: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted && !isTimeout) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load farm data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          PestLifeStage stage = PestLifeStage.egg;
          switch (stageString.toLowerCase()) {
            case 'larva':
              stage = PestLifeStage.larva;
              break;
            case 'pupa':
              stage = PestLifeStage.pupa;
              break;
            case 'moth':
              stage = PestLifeStage.moth;
              break;
            default:
              stage = PestLifeStage.egg;
          }

          final riskString = data['riskLevel']?.toString() ?? 'low';
          RiskLevel riskLevel = RiskLevel.low;
          switch (riskString.toLowerCase()) {
            case 'medium':
              riskLevel = RiskLevel.medium;
              break;
            case 'high':
              riskLevel = RiskLevel.high;
              break;
            case 'critical':
              riskLevel = RiskLevel.critical;
              break;
            default:
              riskLevel = RiskLevel.low;
          }

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

    // Highlight high-risk areas for larvae
    if (_selectedStage == PestLifeStage.larva) {
      for (var field in _fields) {
        if (field.boundaries.isNotEmpty && field.boundaries.length >= 3) {
          _cachedPolygons.add(
            Polygon(
              points: field.boundaries,
              color: const Color(0xFFF44336).withValues(alpha: 0.4),
              borderColor: const Color(0xFFF44336),
              borderStrokeWidth: 3,
            ),
          );
        }
      }
    }

  // Build risk markers (limit to MAX_RISK_POINTS_RENDER)
  int markerCount = 0;
  for (var point in _riskPoints) {
    if (markerCount >= maxRiskPointsRender) break;
    if (_selectedStage == PestLifeStage.all || point.stage == _selectedStage) {
      _cachedMarkers.add(
        Marker(
          point: point.location,
          width: 40,
          height: 40,
          child: _buildRiskMarker(point),
        ),
      );
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

      if (_selectedStage != PestLifeStage.all &&
          report.stage != _selectedStage) {
        continue;
      }

    _cachedMarkers.add(
      Marker(
        point: report.location,
        width: 45,
        height: 45,

        child: GestureDetector(
          onTap: () {
            _showReportDetails(report);
          },

          child: Container(
            decoration: BoxDecoration(
              color: _getRiskColor(report.riskLevel),
              shape: BoxShape.circle,

              border: Border.all(
                color: Colors.white,
                width: 2,
              ),

              boxShadow: [
                BoxShadow(
                  color: _getRiskColor(report.riskLevel)
                      .withValues(alpha: 0.5),

                  blurRadius: 12,
                  spreadRadius: 4,
                ),
              ],
            ),

            child: const Icon(
              Icons.warning,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
    );

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
  }

  double _getSpreadRadiusMeters(PestLifeStage stage, RiskLevel risk) {
    switch (stage) {
      case PestLifeStage.all:
        return 0;
      case PestLifeStage.egg:
        return 0; // no proximity
      case PestLifeStage.larva:
        return 500; // 0.5 km (change to 1000 if you want 1 km)
      case PestLifeStage.pupa:
        return 0; // pupae don't move much
      case PestLifeStage.moth:
        switch (risk) {
          case RiskLevel.low:
            return 1000;
          case RiskLevel.medium:
            return 3000;
          case RiskLevel.high:
            return 5000;
          case RiskLevel.critical:
            return 8000;
        }
    }
  }

  Widget _buildRiskMarker(RiskPoint point) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.15),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,

      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },

      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },

      child: GestureDetector(
        onTap: () {
          _showRiskDetails(point);
        },

        child: Container(
          width: 40,
          height: 40,

          decoration: BoxDecoration(
            color: _getRiskColor(point.riskLevel),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),

            boxShadow: [
              BoxShadow(
                color: _getRiskColor(point.riskLevel)
                    .withValues(alpha: 0.5),
                blurRadius: 10,
                spreadRadius: 3,
              ),
            ],
          ),

          child: Icon(
            _getStageIcon(point.stage),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
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

  void _showReportDetails(ReportData report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,

        content: Text(
          "Report: ${report.pestType} • "
          "${report.riskLevel.name.toUpperCase()}",
        ),
      ),
    );
  }

  Color _getRiskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return const Color(0xFFFFEB3B);
      case RiskLevel.medium:
        return const Color(0xFFFF9800);
      case RiskLevel.high:
        return const Color(0xFFF44336);
      case RiskLevel.critical:
        return const Color(0xFF9C27B0);
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
              _legendItem(const Color(0xFFFFEB3B), "Low Risk"),
              _legendItem(const Color(0xFFFF9800), "Medium Risk"),
              _legendItem(const Color(0xFFF44336), "High Risk"),
              _legendItem(const Color(0xFF9C27B0), "Critical"),
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
    final risk = point.riskLevel.toString().split('.').last.toUpperCase();

    final radius = _getSpreadRadiusMeters(point.stage, point.riskLevel);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
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
                ],
              ),
              const SizedBox(height: 18),
              /// DETAILS
              _infoRow(
                Icons.radar,
                "Spread Radius",
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