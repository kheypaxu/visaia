import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/screens/monitoring_screens/monitoring.dart';
import 'package:visaia/screens/logging_screens/harvest_recording.dart';

class CycleDetailsScreen extends StatefulWidget {
  final String cycleId;
  final String uid;

  const CycleDetailsScreen({super.key, required this.cycleId, required this.uid});

  @override
  State<CycleDetailsScreen> createState() => _CycleDetailsScreenState();
}

class _CycleDetailsScreenState extends State<CycleDetailsScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _cycleData;
  Map<String, dynamic>? _fieldData;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('cycles')
          .doc(widget.cycleId)
          .get();

      if (!cycleDoc.exists) {
        setState(() {
          _error = 'Cycle not found';
          _isLoading = false;
        });
        return;
      }

      final cycle = cycleDoc.data()!;
      setState(() {
        _cycleData = cycle;
      });

      final fieldId = cycle['fieldId'];
      if (fieldId != null) {
        try {
          final fieldDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.uid)
              .collection('fields')
              .doc(fieldId)
              .get();

          if (fieldDoc.exists) {
            setState(() {
              _fieldData = fieldDoc.data();
            });
          }
        } catch (e) {
          debugPrint('Error fetching field: $e');
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load cycle';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int get _totalDays {
    if (_cycleData == null) return 0;
    final harvest = (_cycleData!['harvestDate'] as Timestamp).toDate();
    final planting = (_cycleData!['plantingDate'] as Timestamp).toDate();
    return harvest.difference(planting).inDays;
  }

  int get _elapsedDays {
    if (_cycleData == null) return 0;
    final planting = (_cycleData!['plantingDate'] as Timestamp).toDate();
    return DateTime.now().difference(planting).inDays;
  }

  double get _progress {
    if (_totalDays == 0) return 0.0;
    return (_elapsedDays / _totalDays).clamp(0.0, 1.0);
  }

  String _formatDate(Timestamp timestamp) {
    return DateFormat('MMM d').format(timestamp.toDate());
  }

  List<LatLng> get _fieldBoundaries {
    if (_fieldData == null || _fieldData!['boundaries'] == null) return [];
    final List<dynamic> bounds = _fieldData!['boundaries'];
    return bounds.map((b) => LatLng(b['lat'], b['lng'])).toList();
  }

  LatLng get _fieldCenter {
    if (_fieldBoundaries.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (var point in _fieldBoundaries) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / _fieldBoundaries.length, lng / _fieldBoundaries.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1E)),
        title: const Text(
          'Cycle Detail',
          style: TextStyle(
            color: Color(0xFF1B5E37),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E37)))
          : _error != null && _cycleData == null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildGrowthProgress(),
                      const SizedBox(height: 20),
                      _buildActionButtons(context),
                      const SizedBox(height: 20),
                      _buildRiskAlert(),
                      const SizedBox(height: 20),
                      _buildMapPreview(),
                      const SizedBox(height: 24),
                      _buildRecentActivity(),
                      const SizedBox(height: 40),
                    ],
                  ),
              )
        );
  }

  Widget _buildHeader() {
    final cycleName = _cycleData?['cycleName'] ?? 'Unknown Cycle';
    final fieldName = _cycleData?['fieldName'] ?? 'Unknown Field';
    final cropVariety = _cycleData?['cropVariety'] ?? 'Unknown Crop';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              cycleName,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1C1E),
                height: 1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFBCF491),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF1B5E37),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E37),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '$fieldName • $cropVariety',
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrowthProgress() {
    final plantingDate = _cycleData?['plantingDate'];
    final harvestDate = _cycleData?['harvestDate'];
    final remainingDays = _totalDays - _elapsedDays;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Growth Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Day $_elapsedDays of $_totalDays', style: const TextStyle(color: Colors.black87)),
              Text(
                '$remainingDays days remaining',
                style: const TextStyle(color: Color(0xFF1B5E37), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B5E37)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DateInfo(
                label: 'PLANTED', 
                date: plantingDate != null ? _formatDate(plantingDate) : 'N/A',
              ),
              _DateInfo(
                label: 'EXPECTED HARVEST', 
                date: harvestDate != null ? _formatDate(harvestDate) : 'N/A',
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildActionButton(
          context: context,
          icon: Icons.eco_outlined,
          title: 'Monitoring',
          subtitle: 'Weekly logs and trap records',
          color: const Color(0xFF1B5E37),
          isDark: true,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => MonitoringScreen(cycleId: widget.cycleId, userId: widget.uid,)));
          }
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          context: context,
          icon: Icons.shopping_basket_outlined,
          title: 'Harvest',
          subtitle: 'Record yield and losses',
          color: Colors.white,
          isDark: false,
          onTap: () => {
            Navigator.push(context, MaterialPageRoute(builder: (context) => HarvestRecordingScreen()))
          },
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 20, color: Color.fromARGB(255, 240, 192, 2)),
              SizedBox(width: 8),
              Text('Recommendations: Suggested actions', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFF1F3F1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF1B5E37)),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B5E37),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'High Risk Detected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Immediate attention required for Plot 4B. Review recent scouting data.',
                  style: TextStyle(color: const Color(0xFF991B1B).withValues(alpha:0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    final boundaries = _fieldBoundaries;
    final center = _fieldCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 200,
        width: double.infinity,
        color: const Color(0xFFF1F3F1),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                  userAgentPackageName: 'com.visaia.app',
                ),
                if (boundaries.length >= 3)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: boundaries,
                        color: const Color(0xFFFACC15).withOpacity(0.5),
                        borderColor: const Color(0xFFFACC15),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.map_outlined, size: 16),
                    SizedBox(width: 4),
                    Text('Map View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.assignment_outlined,
            title: 'Monitoring Log added',
            time: '2 hours ago',
            iconColor: const Color(0xFF1B5E37),
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.bug_report_outlined,
            title: 'Pest Uploaded',
            time: '5 hours ago',
            iconColor: const Color(0xFFDC2626),
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.track_changes_outlined,
            title: 'Trap Checked',
            time: 'Yesterday',
            iconColor: const Color(0xFF1B5E37),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String time,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _DateInfo extends StatelessWidget {
  final String label;
  final String date;
  final bool alignEnd;

  const _DateInfo({required this.label, required this.date, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}