import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class FieldCreation extends StatefulWidget {
  final List<LatLng> farmBoundary;
  final String farmName;
  final List<Map<String, dynamic>> existingFields;
  final VoidCallback onFinished;
  final String? suggestedName; // Add this parameter

  const FieldCreation({
    super.key,
    required this.farmBoundary,
    required this.farmName,
    required this.existingFields,
    required this.onFinished,
    this.suggestedName, // Add this
  });

  @override
  State<FieldCreation> createState() => _FieldCreationState();
}

class _FieldCreationState extends State<FieldCreation> {
  final List<LatLng> _fieldPoints = [];
  final List<List<LatLng>> _history = [];

  final MapController _mapController = MapController();
  final TextEditingController _fieldNameController = TextEditingController();
  final GlobalKey _mapKey = GlobalKey();

  MapMode _mode = MapMode.idle;
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    // Auto-populate the field name with the suggested name
    if (widget.suggestedName != null && widget.suggestedName!.isNotEmpty) {
      _fieldNameController.text = widget.suggestedName!;
    }
  }

  // ================= HISTORY =================
  void _save() {
    _history.add(List.from(_fieldPoints));
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _fieldPoints
        ..clear()
        ..addAll(_history.removeLast());
    });
  }

  // ================= ADD POINT =================
  void _addPoint(LatLng p) {
    _save();
    setState(() => _fieldPoints.add(p));
  }

  // ================= DELETE =================
  void _deletePoint(int i) {
    _save();
    setState(() {
      _fieldPoints.removeAt(i);
      _draggingIndex = null;
    });
  }

  // ================= DRAG =================
  void _updatePointFromScreen(int index, Offset localPos) {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    final size = _mapKey.currentContext!.size!;

    final northLat = bounds.north;
    final southLat = bounds.south;
    final eastLng = bounds.east;
    final westLng = bounds.west;

    final lat = northLat - (localPos.dy / size.height) * (northLat - southLat);
    final lng = westLng + (localPos.dx / size.width) * (eastLng - westLng);

    setState(() {
      _fieldPoints[index] = LatLng(lat, lng);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDragging = _mode == MapMode.drag;

    final farmCenter = widget.farmBoundary.isNotEmpty
        ? LatLng(
            widget.farmBoundary.map((p) => p.latitude).reduce((a, b) => a + b) /
                widget.farmBoundary.length,
            widget.farmBoundary.map((p) => p.longitude).reduce((a, b) => a + b) /
                widget.farmBoundary.length,
          )
        : const LatLng(10.7202, 122.5621);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Field"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
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
                initialCenter: farmCenter,
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
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.example.app',
                ),

                // ================= FARM BOUNDARY =================
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: widget.farmBoundary,
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

                // ================= EXISTING FIELDS =================
                if (widget.existingFields.isNotEmpty)
                  PolygonLayer(
                    polygons: widget.existingFields
                        .where((field) => (field['boundaries'] as List?)?.isNotEmpty ?? false)
                        .map((field) {
                          final boundaries = field['boundaries'] as List<LatLng>;
                          return Polygon(
                            points: boundaries,
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderColor: Colors.grey,
                            borderStrokeWidth: 2,
                          );
                        })
                        .toList(),
                  ),

                // ================= FIELD POLYGON =================
                if (_fieldPoints.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: _fieldPoints,
                        color: Colors.green.withValues(alpha: 0.35),
                        borderColor: Colors.green,
                        borderStrokeWidth: 4,
                      ),
                    ],
                  ),

                // ================= FIELD POINTS =================
                MarkerLayer(
                  markers: List.generate(_fieldPoints.length, (i) {
                    final isSelected = _draggingIndex == i;

                    return Marker(
                      point: _fieldPoints[i],
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

          // ================= BUTTONS =================
          Positioned(
            right: 16,
            top: 16,
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

          // ================= BOTTOM PANEL =================
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define Field',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a field within ${widget.farmName}. Use Add Mode to place points.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'FIELD NAME',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _fieldNameController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Field A',
                      prefixIcon: const Icon(Icons.agriculture),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      // Add a suffix icon to indicate auto-generated
                      suffixIcon: widget.suggestedName != null
                          ? Icon(
                              Icons.auto_awesome,
                              color: Colors.green[400],
                              size: 18,
                            )
                          : null,
                    ),
                    // Show a hint below the field if auto-generated
                  ),
                  if (widget.suggestedName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Auto-generated name based on farm fields',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _fieldPoints.length >= 3 &&
                              _fieldNameController.text.isNotEmpty
                          ? () {
                              Navigator.pop(context, {
                                'name': _fieldNameController.text,
                                'acres': 0,
                                'crop': null,
                                'boundaries': _fieldPoints,
                              });
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B57),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Add Field'),
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: IconButton(
        icon: Icon(icon, color: active ? Colors.white : Colors.black),
        onPressed: onTap,
      ),
    );
  }
}

enum MapMode { idle, add, drag, delete }