import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/utils/geo_utils.dart';
import 'package:visaia/screens/onboarding/field_area_setup_screen.dart';

enum MapMode { idle, add, drag, delete }

// Helper class for search results
class AddressResult {
  final String name;
  final String type; // barangay, district, municipality, province
  final String fullAddress;
  final LatLng coordinates;

  AddressResult({
    required this.name,
    required this.type,
    required this.fullAddress,
    required this.coordinates,
  });
}

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
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey _mapKey = GlobalKey();

  final LatLng _center = const LatLng(10.7202, 122.5621);

  MapMode _mode = MapMode.idle;
  int? _draggingIndex;

  // Search state
  List<AddressResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  // ============================================================
  // CABATUAN COORDINATES (approximate centroids)
  // ============================================================
  static const Map<String, LatLng> _cabatuanCoords = {
    'Poblacion': LatLng(10.8784, 122.4853),
    'Agdayao': LatLng(10.8950, 122.4800),
    'Agyenan': LatLng(10.8900, 122.4900),
    'Amboyu-an': LatLng(10.8850, 122.4750),
    'Apdo': LatLng(10.8700, 122.4950),
    'Aslag': LatLng(10.8800, 122.4700),
    'Balabago': LatLng(10.8750, 122.5000),
    'Baluyan': LatLng(10.8920, 122.4780),
    'Bita-og Daku': LatLng(10.9000, 122.4850),
    'Bita-og Guimon': LatLng(10.9050, 122.4880),
    'Buenavista': LatLng(10.8980, 122.4750),
    'Buyo': LatLng(10.8950, 122.4920),
    'Cabudian': LatLng(10.9020, 122.4800),
    'Cadoldolan': LatLng(10.9080, 122.4850),
    'Caguyuman': LatLng(10.9120, 122.4780),
    'Caloy-an': LatLng(10.9200, 122.4820),
    'Camiri': LatLng(10.9250, 122.4750),
    'Canabuan': LatLng(10.9300, 122.4700),
    'Cañao': LatLng(10.9350, 122.4650),
    'Capuyan': LatLng(10.9400, 122.4680),
    'Dalid': LatLng(10.9450, 122.4720),
    'Duyan-Duyan': LatLng(10.9500, 122.4780),
    'Gines': LatLng(10.9550, 122.4820),
    'Imbadan': LatLng(10.9600, 122.4850),
    'Inabasan': LatLng(10.9650, 122.4880),
    'Jolongajog': LatLng(10.9700, 122.4900),
    'Lanag': LatLng(10.9750, 122.4920),
    'Libo-on': LatLng(10.9800, 122.4880),
    'Lincud': LatLng(10.9850, 122.4850),
    'Ludiong': LatLng(10.9900, 122.4800),
    'Lumanay': LatLng(10.9950, 122.4780),
    'Lusaran': LatLng(11.0000, 122.4750),
    'Luyahan': LatLng(11.0050, 122.4700),
    'Maasin': LatLng(11.0100, 122.4650),
    'Malio': LatLng(11.0150, 122.4680),
    'Mambiranan': LatLng(11.0200, 122.4720),
    'Mambog': LatLng(11.0250, 122.4780),
    'Maribong': LatLng(11.0300, 122.4820),
    'Natividad': LatLng(11.0350, 122.4850),
    'Pabjanay': LatLng(11.0400, 122.4880),
    'Pagaypay': LatLng(11.0450, 122.4900),
    'Pajo': LatLng(11.0500, 122.4920),
    'Palaca': LatLng(11.0550, 122.4880),
    'Pananao': LatLng(11.0600, 122.4850),
    'Pasol-o': LatLng(11.0650, 122.4800),
    'Quezon': LatLng(11.0700, 122.4780),
    'Quisao': LatLng(11.0750, 122.4750),
    'Sagcungan': LatLng(11.0800, 122.4700),
    'Salong': LatLng(11.0850, 122.4650),
    'San Agustin': LatLng(11.0900, 122.4680),
    'San Francisco': LatLng(11.0950, 122.4720),
    'San Isidro': LatLng(11.1000, 122.4780),
    'San Jose': LatLng(11.1050, 122.4820),
    'San Juan': LatLng(11.1100, 122.4850),
    'San Mateo': LatLng(11.1150, 122.4880),
    'San Miguel': LatLng(11.1200, 122.4900),
    'Santo Tomas': LatLng(11.1250, 122.4920),
    'Talanghauan': LatLng(11.1300, 122.4880),
    'Tina': LatLng(11.1350, 122.4850),
    'Tina-an': LatLng(11.1400, 122.4800),
    'Tuburan': LatLng(11.1450, 122.4780),
    'Tugas': LatLng(11.1500, 122.4750),
  };

  // ============================================================
  // ILOILO CITY COORDINATES (approximate centroids)
  // ============================================================
  static const Map<String, LatLng> _iloiloCityCoords = {
    'Arevalo': LatLng(10.7000, 122.5400),
    'City Proper': LatLng(10.6950, 122.5650),
    'Jaro': LatLng(10.7200, 122.5400),
    'La Paz': LatLng(10.7200, 122.5700),
    'Lapuz': LatLng(10.7100, 122.5800),
    'Mandurriao': LatLng(10.7350, 122.5500),
    'Molo': LatLng(10.7000, 122.5550),
  };

  // ============================================================
  // ILOILO PROVINCE MUNICIPALITY COORDINATES
  // ============================================================
  static const Map<String, LatLng> _iloiloMunicipalityCoords = {
    'Ajuy': LatLng(11.0300, 123.0200),
    'Alimodian': LatLng(10.8200, 122.4300),
    'Anilao': LatLng(10.9000, 122.7500),
    'Badiangan': LatLng(10.9800, 122.5000),
    'Balasan': LatLng(11.2500, 123.0800),
    'Banate': LatLng(10.9500, 122.7800),
    'Barotac Nuevo': LatLng(10.8900, 122.7000),
    'Barotac Viejo': LatLng(11.0500, 122.8500),
    'Batad': LatLng(11.1800, 123.0500),
    'Bingawan': LatLng(11.1000, 122.5500),
    'Cabatuan': LatLng(10.8784, 122.4853),
    'Calinog': LatLng(11.1200, 122.5400),
    'Carles': LatLng(11.4700, 123.1300),
    'Concepcion': LatLng(11.2100, 123.1200),
    'Dingle': LatLng(10.9500, 122.6300),
    'Dueñas': LatLng(11.0700, 122.6200),
    'Dumangas': LatLng(10.8300, 122.7200),
    'Estancia': LatLng(11.4500, 123.1500),
    'Guimbal': LatLng(10.6600, 122.3200),
    'Igbaras': LatLng(10.7200, 122.2700),
    'Iloilo City': LatLng(10.7202, 122.5621),
    'Janiuay': LatLng(10.9500, 122.5000),
    'Lambunao': LatLng(11.0500, 122.4700),
    'Leganes': LatLng(10.7800, 122.5900),
    'Lemery': LatLng(11.2800, 122.9200),
    'Leon': LatLng(10.7800, 122.3900),
    'Maasin': LatLng(10.9000, 122.4300),
    'Miagao': LatLng(10.6400, 122.2400),
    'Mina': LatLng(10.9300, 122.5800),
    'New Lucena': LatLng(10.8800, 122.6000),
    'Oton': LatLng(10.6900, 122.4700),
    'Pavia': LatLng(10.7700, 122.5400),
    'Pototan': LatLng(10.9400, 122.6300),
    'San Dionisio': LatLng(11.2700, 123.0700),
    'San Enrique': LatLng(10.9700, 122.6500),
    'San Joaquin': LatLng(10.6000, 122.2400),
    'San Miguel': LatLng(10.8800, 122.7300),
    'San Rafael': LatLng(11.0000, 122.7300),
    'Santa Barbara': LatLng(10.8200, 122.5300),
    'Sara': LatLng(11.2500, 123.0100),
    'Tigbauan': LatLng(10.6700, 122.3700),
    'Tubungan': LatLng(10.7800, 122.3100),
    'Zarraga': LatLng(10.8200, 122.6000),
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    // Debounce search
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_searchController.text.trim() != query) return;
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    final results = <AddressResult>[];
    final lowerQuery = query.toLowerCase();

    // ============================================================
    // SEARCH CABATUAN BARANGAYS
    // ============================================================
    if ('cabatuan'.contains(lowerQuery)) {
      results.add(AddressResult(
        name: 'Cabatuan',
        type: 'Municipality',
        fullAddress: 'Cabatuan, Iloilo',
        coordinates: const LatLng(10.8784, 122.4853),
      ));
    }

    for (final entry in _cabatuanCoords.entries) {
      final barangay = entry.key;
      final coords = entry.value;
      if (barangay.toLowerCase().contains(lowerQuery)) {
        results.add(AddressResult(
          name: barangay,
          type: 'Barangay',
          fullAddress: '$barangay, Cabatuan, Iloilo',
          coordinates: coords,
        ));
      }
    }

    // ============================================================
    // SEARCH ILOILO CITY DISTRICTS
    // ============================================================
    if ('iloilo city'.contains(lowerQuery) || 'iloilo'.contains(lowerQuery)) {
      results.add(AddressResult(
        name: 'Iloilo City',
        type: 'City',
        fullAddress: 'Iloilo City, Iloilo',
        coordinates: const LatLng(10.7202, 122.5621),
      ));
    }

    for (final entry in _iloiloCityCoords.entries) {
      final district = entry.key;
      final coords = entry.value;
      if (district.toLowerCase().contains(lowerQuery)) {
        results.add(AddressResult(
          name: district,
          type: 'District',
          fullAddress: '$district District, Iloilo City',
          coordinates: coords,
        ));
      }
    }

    // ============================================================
    // SEARCH ILOILO PROVINCE MUNICIPALITIES
    // ============================================================
    for (final entry in _iloiloMunicipalityCoords.entries) {
      final municipality = entry.key;
      final coords = entry.value;
      if (municipality.toLowerCase().contains(lowerQuery)) {
        results.add(AddressResult(
          name: municipality,
          type: 'Municipality',
          fullAddress: '$municipality, Iloilo',
          coordinates: coords,
        ));
      }
    }

    // Sort results: exact matches first, then by type priority
    results.sort((a, b) {
      final aExact = a.name.toLowerCase() == lowerQuery;
      final bExact = b.name.toLowerCase() == lowerQuery;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;
      
      // Priority: Municipality > City > District > Barangay
      final priority = {'Municipality': 0, 'City': 1, 'District': 2, 'Barangay': 3};
      return (priority[a.type] ?? 5).compareTo(priority[b.type] ?? 5);
    });

    setState(() {
      _searchResults = results.take(20).toList();
      _isSearching = false;
    });
  }

  void _selectSearchResult(AddressResult result) {
    setState(() {
      _searchController.text = result.name;
      _showSearchResults = false;
      _searchResults = [];
    });

    // Center map on the selected location with appropriate zoom level
    // Use higher zoom for barangays (15), lower for municipalities/cities (13)
    final zoomLevel = result.type == 'Barangay' ? 15.0 : 14.0;
    _mapController.move(result.coordinates, zoomLevel);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📍 ${result.fullAddress}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2E8B57),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'Municipality': return Icons.place;
      case 'City': return Icons.location_city;
      case 'District': return Icons.map;
      case 'Barangay': return Icons.home;
      default: return Icons.location_on;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'Municipality': return Colors.green;
      case 'City': return Colors.blue;
      case 'District': return Colors.orange;
      case 'Barangay': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Future<void> _handleProceed() async {
    if (_points.length < 3 || _nameController.text.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final areaSqm = GeoUtils.calculateAreaSqm(_points);
      final acres = GeoUtils.toAcres(areaSqm);

      final farmRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('farms')
          .add({
        'name': _nameController.text,
        'acres': acres,
        'boundaries': _points
            .map((p) => {
                  'lat': p.latitude,
                  'lng': p.longitude,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(user.uid)
          .set({
        'activeFarmId': farmRef.id,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'hasFarm': true}, SetOptions(merge: true));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FieldAreaSetupScreen(
              farmId: farmRef.id,
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
                initialZoom: 14,
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

          // ================= SEARCH BAR =================
          Positioned(
            top: 100,
            left: 30,
            right: 30,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search the location here...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _showSearchResults = false;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onTap: () {
                      if (_searchController.text.isNotEmpty) {
                        setState(() {
                          _showSearchResults = true;
                          _performSearch(_searchController.text);
                        });
                      }
                    },
                  ),
                ),
                // Search Results Dropdown
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: Icon(
                            _getIconForType(result.type),
                            color: _getColorForType(result.type),
                            size: 20,
                          ),
                          title: Text(
                            result.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            result.fullAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          dense: true,
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
                if (_isSearching && _showSearchResults)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ================= HEADER =================
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
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
                child: const Text(
                  "Setup Your Farm",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define Boundary',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      letterSpacing: 1,
                    ),
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
                      onPressed: _points.length >= 3 && _nameController.text.isNotEmpty
                          ? _handleProceed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E8B57),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: active ? Colors.white : Colors.black),
        onPressed: onTap,
      ),
    );
  }
}