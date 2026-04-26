import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/utils/geo_utils.dart';
import 'package:visaia/screens/onboarding/field_area_setup_screen.dart';

enum MapMode { idle, add, drag, delete }

class FarmAreaSetup extends StatefulWidget {
  final VoidCallback onFinished;
  const FarmAreaSetup({super.key, required this.onFinished});

  @override
  State<FarmAreaSetup> createState() => _FarmAreaSetupState();
}

class _FarmAreaSetupState extends State<FarmAreaSetup> {
  final List<LatLng> _points = [];
  final List<List<LatLng>> _history = [];

  final MapController _mapController = MapController();
  final TextEditingController _nameController = TextEditingController();

  final GlobalKey _mapKey = GlobalKey();

  final LatLng _center = const LatLng(10.7202, 122.5621);

  MapMode _mode = MapMode.idle;
  int? _draggingIndex;

  Future<void> _handleProceed() async {
    if (_points.length < 3 || _nameController.text.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 🧠 1. CALCULATE AREA HERE (THIS IS THE CORRECT PLACE)
      final areaSqm = GeoUtils.calculateAreaSqm(_points);
      final acres = GeoUtils.toAcres(areaSqm);

      // 🧾 2. SAVE FARM (include acres if your service supports it OR store separately)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('farms')
          .add({
        'name': _nameController.text,
        'acres': acres, // ✅ NOW REAL VALUE
        'boundaries': _points
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 👤 3. Update user flag
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'hasFarm': true}, SetOptions(merge: true));

      // 🚀 4. Navigate
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FieldAreaSetupScreen(
              farmBoundary: _points,
              farmName: _nameController.text,
              onFinished: widget.onFinished,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving farm: $e")),
        );
      }
    }
  }

  // ================= HISTORY =================
  void _save() {
    _history.add(List.from(_points));
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _points
        ..clear()
        ..addAll(_history.removeLast());
    });
  }

  // ================= ADD POINT =================
  void _addPoint(LatLng p) {
    _save();
    setState(() => _points.add(p));
  }

  // ================= DELETE =================
  void _deletePoint(int i) {
    _save();
    setState(() {
      _points.removeAt(i);
      _draggingIndex = null;
    });
  }

  // ================= DRAG =================
  void _updatePointFromScreen(int index, Offset localPos) {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    final size = _mapKey.currentContext!.size!;

    // Map screen position to lat/lng using visible bounds
    final northLat = bounds.north;
    final southLat = bounds.south;
    final eastLng = bounds.east;
    final westLng = bounds.west;

    final lat = northLat - (localPos.dy / size.height) * (northLat - southLat);
    final lng = westLng + (localPos.dx / size.width) * (eastLng - westLng);

    setState(() {
      _points[index] = LatLng(lat, lng);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = _mode == MapMode.drag;

    return Scaffold(
      body: Stack(
        children: [
          // ================= MAP =================
          GestureDetector(
            onPanUpdate: (details) {
              if (!isDragging || _draggingIndex == null) return;

              final box = _mapKey.currentContext!.findRenderObject() as RenderBox;
              final local = box.globalToLocal(details.globalPosition);

              _updatePointFromScreen(_draggingIndex!, local);
            },
            child: FlutterMap(
              key: _mapKey,
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 16,

                interactionOptions: InteractionOptions(
                  flags: (_mode == MapMode.add || (_mode == MapMode.drag && _draggingIndex != null))
                      ? InteractiveFlag.none
                      : InteractiveFlag.all,
                ),

                onTap: (_, latlng) {
                  if (_mode == MapMode.add) {
                    _addPoint(latlng);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.example.app',
                ),

                // ================= POLYGON =================
                if (_points.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _points,
                        color: Colors.green.withValues(alpha: 0.25),
                        borderColor: Colors.green,
                        borderStrokeWidth: 3,
                      ),
                    ],
                  ),

                // ================= DOT MARKERS (NO ICONS) =================
                MarkerLayer(
                  markers: List.generate(_points.length, (i) {
                    final isSelected = _draggingIndex == i;

                    return Marker(
                      point: _points[i],
                      width: 20,
                      height: 20,
                      child: GestureDetector(
                        onTap: () {
                          if (_mode == MapMode.delete) {
                            _deletePoint(i);
                            return;
                          }

                          if (_mode == MapMode.drag) {
                            setState(() {
                              _draggingIndex = i;
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? Colors.orange : Colors.green,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // ================= HEADER =================
          // ================= HEADER =================
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 10), // Optional: adds a little breathing room
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                // Use child: Text(...) instead of title: const Text(...)
                child: const Text(
                  "Setup Your Farm",
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w600, 
                    color: Colors.black, // Set color directly here
                  ),
                ),
              ),
            ),
          ),

          // ================= BUTTONS =================
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.3,
            child: Column(
              children: [
                _btn(Icons.add_location, _mode == MapMode.add, () {
                  setState(() => _mode = MapMode.add);
                }),

                const SizedBox(height: 10),

                _btn(Icons.open_with, _mode == MapMode.drag, () {
                  setState(() => _mode = MapMode.drag);
                  _draggingIndex = null;
                }),

                const SizedBox(height: 10),

                _btn(Icons.delete, _mode == MapMode.delete, () {
                  setState(() => _mode = MapMode.delete);
                }),

                const SizedBox(height: 10),

                _btn(Icons.undo, false, _undo),
              ],
            ),
          ),

          // ================= BOTTOM =================
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define Boundary',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the map to place vertices and outline your farm area.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'FARM IDENTIFIER',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., North Field Alpha',
                      prefixIcon: const Icon(Icons.agriculture),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _points.length >= 3 &&
                              _nameController.text.isNotEmpty
                          ? _handleProceed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B57),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Proceed to Field Setup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, bool active, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Colors.green : Colors.white,
      ),
      child: IconButton(
        icon: Icon(icon,
            color: active ? Colors.white : Colors.black),
        onPressed: onTap,
      ),
    );
  }
}