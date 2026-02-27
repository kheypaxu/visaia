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
  // Coordinates for the farm (example location)
  final LatLng _farmCenter = const LatLng(14.5995, 120.9842);
  final LatLng _pestLocation = const LatLng(14.6015, 120.9880);

  bool _isSatellite = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Interactive Map Layer
        FlutterMap(
          options: MapOptions(
            initialCenter: _farmCenter,
            initialZoom: 16.5,
            minZoom: 3.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            if (_isSatellite) ...[
              // Optimized High-Performance Satellite Layer
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.visaia.app',
                tileProvider: NetworkTileProvider(),
                // Performance Tuning:
                keepBuffer: 3, // Keeps tiles from previous zoom levels to prevent white flashes
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 300)),
              ),
              // Consolidate Labels into a single, light overlay if needed, 
              // or just keep base for maximum performance.
              // We'll keep just Transportation for critical context to minimize lag.
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Transportation/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.visaia.app',
                keepBuffer: 1,
              ),
            ] else ...[
              // Standard Street Map (Lightweight)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.visaia.app',
                keepBuffer: 2,
              ),
            ],
            // Circular Overlays (Farm Boundary & Pest Zone)
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _farmCenter,
                  radius: 180,
                  useRadiusInMeter: true,
                  color: const Color(0xFF8DBA60).withOpacity(0.15),
                  borderColor: const Color(0xFF8DBA60),
                  borderStrokeWidth: 2,
                ),
                CircleMarker(
                  point: _pestLocation,
                  radius: 80,
                  useRadiusInMeter: true,
                  color: Colors.red.withOpacity(0.3),
                  borderColor: Colors.red,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            // Markers
            MarkerLayer(
              markers: [
                _buildMapMarker(_farmCenter, "Active Farm", const Color(0xFF00FF85)),
                _buildMapMarker(_pestLocation, "Pest Outbreak", Colors.red),
              ],
            ),
            // Attribution Requirement
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'Esri, Maxar, Earthstar Geographics, and the GIS User Community',
                ),
              ],
            ),
          ],
        ),

        // 2. Floating Search Bar (Adjusted for floating header)
        Positioned(
          top: 140, // Moved down to avoid overlapping with "Field Explorer" header
          left: 20,
          right: 20,
          child: _buildSearchBar(),
        ),
        
        // 3. Risk Map / Your Tasks Toggle Buttons
        Positioned(
          top: 205, // Moved down relative to search bar
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
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search fields, crops, or pests...",
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
              ),
            ),
          ),
          const Icon(Icons.search, color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildPillButton(String label, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF8DBA60).withOpacity(0.8) : Colors.black.withOpacity(0.5),
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