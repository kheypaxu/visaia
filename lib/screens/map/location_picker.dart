import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationPickerModal extends StatefulWidget {
  final String? initialLocation;
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationPickerModal({
    super.key,
    this.initialLocation,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationPickerModal> createState() => _LocationPickerModalState();
}

class _LocationPickerModalState extends State<LocationPickerModal> {
  late MapController _mapController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  String _selectedLocation = '';
  LatLng? _selectedPoint;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  
  // Default center (Pototan, Iloilo)
  static const LatLng _defaultCenter = LatLng(10.9422, 122.6280);
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _selectedLocation = widget.initialLocation ?? '';
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    _searchController.text = _selectedLocation;
    
    // Move map after it's built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_selectedPoint != null) {
          _mapController.move(_selectedPoint!, 15);
        }
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=10&countrycodes=PH',
        ),
        headers: {
          'User-Agent': 'VisaiaApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((item) {
            return {
              'name': item['display_name'],
              'lat': double.parse(item['lat']),
              'lon': double.parse(item['lon']),
              'type': item['type'],
              'importance': item['importance'],
            };
          }).toList();
          _isSearching = false;
        });
      } else {
        throw Exception('Failed to load search results');
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error searching location. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = result['lat'];
    final lon = result['lon'];
    final point = LatLng(lat, lon);
    
    setState(() {
      _selectedPoint = point;
      _selectedLocation = result['name'];
      _searchController.text = _selectedLocation;
      _searchResults = [];
      _searchFocusNode.unfocus();
    });
    
    // Move map to selected location
    _mapController.move(point, 16);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedPoint = point;
      _selectedLocation = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      _searchController.text = _selectedLocation;
    });
  }

  void _confirmSelection() {
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search for a location or tap on the map to select one.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.pop(context, {
      'location': _selectedLocation,
      'latitude': _selectedPoint!.latitude,
      'longitude': _selectedPoint!.longitude,
    });
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _centerOnSelectedLocation() {
    if (_selectedPoint != null) {
      _mapController.move(_selectedPoint!, 15);
    } else {
      _mapController.move(_defaultCenter, 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.9,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF134D37),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: 'Search for a location...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (value) => _searchLocation(value),
                      ),
                    ),
                    IconButton(
                      icon: _isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search, color: Color(0xFF134D37)),
                      onPressed: () => _searchLocation(_searchController.text),
                    ),
                  ],
                ),
              ),
            ),
            
            // Search Results
            if (_searchResults.isNotEmpty)
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      leading: Icon(
                        result['type'] == 'city' ? Icons.location_city :
                        result['type'] == 'village' ? Icons.location_city :
                        result['type'] == 'hamlet' ? Icons.location_on :
                        Icons.place,
                        color: const Color(0xFF134D37),
                      ),
                      title: Text(
                        result['name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      onTap: () => _selectSearchResult(result),
                    );
                  },
                ),
              ),
            
            // Map
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedPoint ?? _defaultCenter,
                          initialZoom: 13,
                          minZoom: 3,
                          maxZoom: 19,
                          onTap: _onMapTap,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          // Terrain/Satellite layer
                          TileLayer(
                            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                            userAgentPackageName: 'com.visaia.app',
                            tileProvider: NetworkTileProvider(),
                          ),
                          
                          // Selected location marker
                          if (_selectedPoint != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedPoint!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      
                      // Map control buttons
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Column(
                          children: [
                            _buildMapButton(Icons.add, _zoomIn),
                            const SizedBox(height: 8),
                            _buildMapButton(Icons.remove, _zoomOut),
                            const SizedBox(height: 8),
                            _buildMapButton(Icons.my_location, _centerOnSelectedLocation),
                          ],
                        ),
                      ),
                      
                      // Instruction overlay
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.touch_app, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Tap on map to pinpoint location',
                                style: TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Selected location preview
            if (_selectedPoint != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SELECTED LOCATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E6266),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedLocation,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1C1E),
                      ),
                    ),
                    if (_selectedPoint != null)
                      Text(
                        'Lat: ${_selectedPoint!.latitude.toStringAsFixed(6)}, Lng: ${_selectedPoint!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF5E6266),
                        ),
                      ),
                  ],
                ),
              ),
            
            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF134D37)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF134D37),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF134D37)),
      ),
    );
  }
}