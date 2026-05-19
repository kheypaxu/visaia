import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class StartCroppingCycleScreen extends StatefulWidget {
  final String? farmId;
  const StartCroppingCycleScreen({super.key, this.farmId});

  @override
  State<StartCroppingCycleScreen> createState() =>
      _StartCroppingCycleScreenState();
}

class _StartCroppingCycleScreenState extends State<StartCroppingCycleScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final MapController mapController = MapController();

  List<Map<String, dynamic>> fields = [];
  List<LatLng> farmBoundary = [];
  List<LatLng> selectedFieldPolygon = [];
  bool isLoading = true;

  String? selectedFieldId;
  String? selectedFieldName;
  String? selectedFarmId;

  final cycleNameController = TextEditingController();
  final cropVarietyController = TextEditingController();
  final seedDensityController = TextEditingController();

  DateTime? plantingDate;
  DateTime? harvestDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchFarm();
    await _fetchFields();

    setState(() => isLoading = false);

    if (farmBoundary.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitMapBounds(farmBoundary);
      });
    }
  }

  @override
  void dispose() {
    cycleNameController.dispose();
    cropVarietyController.dispose();
    seedDensityController.dispose();
    super.dispose();
  }

  void _fitMapBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;

    double zoom = 14.0;
    if (latDiff > 0.1 || lngDiff > 0.1) {
      zoom = 10.0;
    } else if (latDiff > 0.04 || lngDiff > 0.04) {
      zoom = 12.0;
    } else if (latDiff > 0.015 || lngDiff > 0.015) {
      zoom = 14.0;
    } else if (latDiff > 0.005 || lngDiff > 0.005) {
      zoom = 16.0;
    } else {
      zoom = 18.0;
    }

    mapController.move(center, zoom);
  }

  Future<void> _fetchFarm() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('farms')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      selectedFarmId = snapshot.docs.first.id; // ← store the farm doc ID

      final raw = data['boundaries'] as List;
      farmBoundary = raw.map((p) {
        return LatLng(
          (p['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble(),
        );
      }).toList();
    }
  }

  Future<void> _fetchFields() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('fields')
        .get();

    fields = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        'name': data['name'],
        'boundaries': (data['boundaries'] as List)
            .map((p) => LatLng(
                  (p['lat'] as num).toDouble(),
                  (p['lng'] as num).toDouble(),
                ))
            .toList(),
      };
    }).toList();
  }

  Future<void> _saveCycle() async {
    if (user == null || selectedFieldId == null) {
      _showSnackBar('Please select a field first.', isError: true);
      return;
    }
    if (cycleNameController.text.isEmpty) {
      _showSnackBar('Please enter a cycle name.', isError: true);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('cycles')
          .add({
        'fieldId': selectedFieldId,
        'fieldName': selectedFieldName,
        'cycleName': cycleNameController.text,
        'cropVariety': cropVarietyController.text,
        'plantingDate': plantingDate != null
            ? Timestamp.fromDate(plantingDate!)
            : null,
        'harvestDate': harvestDate != null
            ? Timestamp.fromDate(harvestDate!)
            : null,
        'seedDensity': double.tryParse(seedDensityController.text) ?? 0,
        'isCompleted': false,
        'farmId': widget.farmId ?? selectedFarmId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackBar('Cycle saved successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save cycle.', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: isError ? const Color(0xFFBA1A1A) : const Color(0xFF25523B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _pickDate(bool isPlanting) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
    );

    if (date == null) return;

    setState(() {
      if (isPlanting) {
        plantingDate = date;
      } else {
        harvestDate = date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8F5),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back,
                  color: Color(0xFF2D3132), size: 18),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Start Cropping Cycle',
          style: TextStyle(
            color: Color(0xFF1A1C1E),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const _StepIndicator(),
            const SizedBox(height: 28),
            const Text(
              'Configure Cycle',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1C1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up the details for your next planting cycle. Choose the field you\'ll use and decide when planting and harvesting will happen.',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF5E6266).withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            _TargetLocationCard(
              fields: fields,
              isLoading: isLoading,
              selectedFieldId: selectedFieldId,
              selectedFieldPolygon: selectedFieldPolygon,
              mapController: mapController,
              farmBoundary: farmBoundary,
              onFieldChanged: (id) {
                final field = fields.firstWhere((f) => f['id'] == id);
                final fieldBounds = List<LatLng>.from(field['boundaries']);

                setState(() {
                  selectedFieldId = id;
                  selectedFieldName = field['name'];
                  selectedFieldPolygon = fieldBounds;
                });

                _fitMapBounds(fieldBounds);
              },
            ),
            const SizedBox(height: 16),
            _CycleParametersCard(
              cycleNameController: cycleNameController,
              cropVarietyController: cropVarietyController,
              seedDensityController: seedDensityController,
              plantingDate: plantingDate,
              harvestDate: harvestDate,
              onPlantingDateTap: () => _pickDate(true),
              onHarvestDateTap: () => _pickDate(false),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _saveCycle,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25523B),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            shadowColor: const Color(0xFF25523B).withValues(alpha: 0.25),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Save Cropping Cycle',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECEF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25523B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25523B),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 15),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8F5),
                    border:
                        Border.all(color: const Color(0xFF25523B), width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '2',
                      style: TextStyle(
                        color: Color(0xFF25523B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Farm & Field',
              style: TextStyle(
                color: Color(0xFF25523B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Cycle Details',
              style: TextStyle(
                color: Color(0xFF5E6266),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TargetLocationCard extends StatelessWidget {
  final List<Map<String, dynamic>> fields;
  final bool isLoading;
  final String? selectedFieldId;
  final ValueChanged<String?> onFieldChanged;
  final List<LatLng> selectedFieldPolygon;
  final List<LatLng> farmBoundary;
  final MapController mapController;

  const _TargetLocationCard({
    required this.fields,
    required this.isLoading,
    required this.selectedFieldId,
    required this.selectedFieldPolygon,
    required this.onFieldChanged,
    required this.mapController,
    required this.farmBoundary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Select the specific field for this cycle.',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF5E6266)),
                    ),
                  ],
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25523B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_outlined,
                      size: 18, color: Color(0xFF25523B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Text(
              'Select Field',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5E6266)),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE8ECEF).withValues(alpha: 0.6)),
              ),
              child: isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF25523B)),
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (selectedFieldId != null &&
                                fields.any(
                                    (f) => f['id'] == selectedFieldId))
                            ? selectedFieldId
                            : null,
                        isExpanded: true,
                        hint: const Text('Choose Field',
                            style: TextStyle(
                                color: Color(0xFFA1A5A8), fontSize: 14)),
                        icon: const Icon(Icons.expand_more,
                            size: 20, color: Color(0xFF5E6266)),
                        items: fields.map((field) {
                          return DropdownMenuItem<String>(
                            value: field['id'],
                            child: Text(field['name'],
                                style: const TextStyle(
                                    color: Color(0xFF1A1C1E),
                                    fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: onFieldChanged,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: farmBoundary.isNotEmpty
                            ? LatLng(farmBoundary.first.latitude,
                                farmBoundary.first.longitude)
                            : const LatLng(10.7202, 122.5621),
                        initialZoom: 13.0,
                        minZoom: 3.0,
                        maxZoom: 21.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                        ),
                        if (farmBoundary.isNotEmpty)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: [
                                  ...farmBoundary,
                                  farmBoundary.first
                                ],
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.1),
                                borderColor: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.5),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                        if (selectedFieldPolygon.isNotEmpty)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: [
                                  ...selectedFieldPolygon,
                                  selectedFieldPolygon.first
                                ],
                                color: const Color(0xFF25523B)
                                    .withValues(alpha: 0.22),
                                borderColor: const Color(0xFF25523B),
                                borderStrokeWidth: 2.5,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (selectedFieldId != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25523B)
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            const Text(
                              'FIELD SELECTED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildZoomBtn(Icons.add, true),
                          Container(height: 1, color: const Color(0xFFE8ECEF)),
                          _buildZoomBtn(Icons.remove, false),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF25523B)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(Icons.layers_outlined,
                                size: 15, color: Color(0xFF25523B)),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedFieldId == null
                                    ? 'No Field Selected'
                                    : fields
                                        .firstWhere(
                                          (f) =>
                                              f['id'] == selectedFieldId,
                                          orElse: () => {'name': 'Unknown'},
                                        )['name']
                                        .toString(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1C1E)),
                              ),
                              Text(
                                'Tap map for details',
                                style: TextStyle(
                                    fontSize: 9,
                                    color:
                                        Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildZoomBtn(IconData icon, bool isZoomIn) {
    return GestureDetector(
      onTap: () {
        final double currentZoom = mapController.camera.zoom;
        final double newZoom =
            isZoomIn ? currentZoom + 1 : currentZoom - 1;
        mapController.move(mapController.camera.center, newZoom);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: isZoomIn
              ? const BorderRadius.vertical(
                  top: Radius.circular(10), bottom: Radius.zero)
              : const BorderRadius.vertical(
                  top: Radius.zero, bottom: Radius.circular(10)),
        ),
        child: Icon(icon, size: 17, color: const Color(0xFF2D3132)),
      ),
    );
  }
}

class _CycleParametersCard extends StatelessWidget {
  final TextEditingController cycleNameController;
  final TextEditingController cropVarietyController;
  final TextEditingController seedDensityController;
  final DateTime? plantingDate;
  final DateTime? harvestDate;
  final VoidCallback onPlantingDateTap;
  final VoidCallback onHarvestDateTap;

  const _CycleParametersCard({
    required this.cycleNameController,
    required this.cropVarietyController,
    required this.seedDensityController,
    required this.plantingDate,
    required this.harvestDate,
    required this.onPlantingDateTap,
    required this.onHarvestDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cycle Parameters',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1C1E)),
          ),
          const SizedBox(height: 20),
          _buildLabel('Cycle Name / Identifier'),
          _buildTextField(cycleNameController, 'e.g. Winter Wheat \'24'),
          const SizedBox(height: 16),
          _buildLabel('Crop Variety'),
          _buildTextField(cropVarietyController, 'Select Variety'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Est. Planting'),
                    _buildDateField(
                      plantingDate == null
                          ? 'mm/dd/yyyy'
                          : DateFormat('MM/dd/yyyy')
                              .format(plantingDate!),
                      onPlantingDateTap,
                      plantingDate != null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Est. Harvest'),
                    _buildDateField(
                      harvestDate == null
                          ? 'mm/dd/yyyy'
                          : DateFormat('MM/dd/yyyy')
                              .format(harvestDate!),
                      onHarvestDateTap,
                      harvestDate != null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildLabel('Target Seed Density'),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: seedDensityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: '1.2',
                    hintStyle: const TextStyle(
                        color: Color(0xFFA1A5A8), fontSize: 14),
                    fillColor: const Color(0xFFF5F6F3),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color:
                              const Color(0xFFE8ECEF).withValues(alpha: 0.6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF25523B), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25523B).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFF25523B).withValues(alpha: 0.12)),
                  ),
                  child: const Center(
                    child: Text(
                      'KG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF25523B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5E6266)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFFA1A5A8), fontSize: 14),
        fillColor: const Color(0xFFF5F6F3),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: const Color(0xFFE8ECEF).withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF25523B), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDateField(String text, VoidCallback onTap, bool hasDate) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFF25523B).withValues(alpha: 0.04) : const Color(0xFFF5F6F3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? const Color(0xFF25523B).withValues(alpha: 0.2)
                : const Color(0xFFE8ECEF).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 16,
              color: hasDate
                  ? const Color(0xFF25523B)
                  : const Color(0xFFA1A5A8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: hasDate
                      ? const Color(0xFF1A1C1E)
                      : const Color(0xFFA1A5A8),
                  fontSize: 14,
                  fontWeight: hasDate ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}