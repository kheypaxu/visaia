import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';

class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  // Coordinates for farmlands in Pototan, Iloilo
  // Pototan is known as the "Rice Granary of Iloilo"
  final LatLng _farmCenter = const LatLng(10.9422, 122.6280); 
  final LatLng _pestLocation = const LatLng(10.9450, 122.6320);

  bool _isSatellite = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Interactive Map Layer
        FlutterMap(
          options: MapOptions(
            initialCenter: _farmCenter,
            initialZoom: 15.0, // Zoomed slightly out to see more fields
            minZoom: 3.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            if (_isSatellite) ...[
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.visaia.app',
                tileProvider: NetworkTileProvider(),
                keepBuffer: 3,
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 300)),
              ),
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.visaia.app',
                keepBuffer: 1,
              ),
            ] else ...[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.visaia.app',
                keepBuffer: 2,
              ),
            ],

            // Circular Overlays (Iloilo Farm Boundary & Pest Zone)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _farmCenter,
                  radius: 350, // Increased radius for larger Iloilo fields
                  useRadiusInMeter: true,
                  color: const Color(0xFF8DBA60).withValues(alpha: 0.15),
                  borderColor: const Color(0xFF8DBA60),
                  borderStrokeWidth: 2,
                ),
                CircleMarker(
                  point: _pestLocation,
                  radius: 120,
                  useRadiusInMeter: true,
                  color: Colors.red.withValues(alpha: 0.3),
                  borderColor: Colors.red,
                  borderStrokeWidth: 2,
                ),
              ],
            ),

            // Markers
            MarkerLayer(
              markers: [
                _buildMapMarker(_farmCenter, "Pototan Rice Field", const Color(0xFF00FF85)),
                _buildMapMarker(_pestLocation, "Armyworm Alert", Colors.red),
              ],
            ),

            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'Esri, Maxar, Earthstar Geographics, and Iloilo GIS Community',
                ),
              ],
            ),
          ],
        ),

        // 2. Floating Search Bar
        Positioned(
          top: 140,
          left: 20,
          right: 20,
          child: _buildSearchBar(),
        ),
        
        // 3. Map Type Toggle
        Positioned(
          top: 205,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isSatellite = true),
                child: _buildPillButton("Satellite", isPrimary: _isSatellite),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _isSatellite = false),
                child: _buildPillButton("Street Map", isPrimary: !_isSatellite),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ... (Remainder of helper methods _buildMapMarker, _buildSearchBar, _buildPillButton remain the same)
  Marker _buildMapMarker(LatLng point, String label, Color color) {
    return Marker(
      point: point,
      width: 120,
      height: 60,
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              shadows: [const Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Row(
        children: [
          Expanded(
            child: TextField(
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search Iloilo fields...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          Icon(Icons.search, color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildPillButton(String label, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF8DBA60).withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: isPrimary ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}