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

  String _formatTimeAgo(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat('MMM d').format(dateTime);
    if (diff.inDays > 0) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    if (diff.inHours > 0) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    return 'Just now';
  }

  IconData _getIconForActivity(String title) {
    if (title.contains('Watering')) return Icons.water_drop_outlined;
    if (title.contains('Field Scouting')) return Icons.pest_control_outlined;
    if (title.contains('Fertilizing')) return Icons.science_outlined;
    if (title.contains('Harvest')) return Icons.agriculture_outlined;
    return Icons.assignment_outlined;
  }

  Color _getColorForActivity(String title) {
    if (title.contains('Watering')) return Colors.blue;
    if (title.contains('Field Scouting')) return const Color(0xFF1B5E37);
    return const Color(0xFF1B5E37);
  }

  Future<List<Map<String, dynamic>>> _fetchRecentActivities() async {
    final plantingTimestamp = _cycleData?['plantingDate'] as Timestamp?;
    if (plantingTimestamp == null) return [];

    final plantingDate = plantingTimestamp.toDate();
    final now = DateTime.now();
    final daysSincePlanting = now.difference(plantingDate).inDays;
    if (daysSincePlanting < 0) return [];

    final List<Map<String, dynamic>> allActivities = [];

    // Look at the last 5 days (including today)
    for (int offset = 0; offset < 5; offset++) {
      int dayNumber = daysSincePlanting - offset;
      if (dayNumber < 0) continue;
      
      // Day numbers are 1‑based for display
      final dayIndex = dayNumber + 1;
      final dayId = 'day_${dayIndex.toString().padLeft(2, '0')}';
      
      try {
        final activitiesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .collection('cycles')
            .doc(widget.cycleId)
            .collection('dailyLogs')
            .doc(dayId)
            .collection('activities')
            .orderBy('timestamp', descending: true)
            .limit(3) // optional to keep reads low
            .get();

        for (var doc in activitiesSnapshot.docs) {
          final data = doc.data();
          allActivities.add({
            'id': doc.id,
            'title': data['type'] ?? 'Activity',
            'subtitle': data['notes'] ?? '',
            'timestamp': data['timestamp'] as Timestamp? ?? Timestamp.now(),
            'completed': data['completed'] ?? false,
          });
        }
      } catch (e) {
        // Day folder might not exist – that's fine, skip
        debugPrint('No activities for $dayId');
      }
    }

    // Sort all activities by timestamp (newest first)
    allActivities.sort((a, b) => (b['timestamp'] as Timestamp)
        .toDate()
        .compareTo((a['timestamp'] as Timestamp).toDate()));

    return allActivities.take(5).toList();
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
    final now = DateTime.now();
    final harvestDate = (_cycleData?['harvestDate'] as Timestamp?)?.toDate();
    final isEarlyHarvest = harvestDate != null && now.isBefore(harvestDate);
    
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
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => MonitoringScreen(
                cycleId: widget.cycleId, 
                userId: widget.uid,
              )
            ));
          }
        ),
        const SizedBox(height: 12),
        
        // Harvest button - always enabled with confirmation
        _buildHarvestButton(context, isEarlyHarvest),
        
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
              Icon(Icons.lightbulb_outline, size: 20, color: Color(0xFFF0C002)),
              SizedBox(width: 8),
              Text('Recommendations: Suggested actions', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestButton(BuildContext context, bool isEarlyHarvest) {
    return _buildActionButton(
      context: context,
      icon: Icons.shopping_basket_outlined,
      title: 'Record Harvest',
      subtitle: isEarlyHarvest ? 'Early harvest - confirmation required' : 'Finalize yield and losses',
      color: isEarlyHarvest ? Colors.white : const Color(0xFF1B5E37),
      isDark: !isEarlyHarvest,
      onTap: () {
        if (isEarlyHarvest) {
          _showEarlyHarvestConfirmation(context);
        } else {
          // Normal harvest on or after expected date
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => HarvestRecordingScreen(
              cycleId: widget.cycleId,
              userId: widget.uid,
            )
          ));
        }
      },
    );
  }

  void _showEarlyHarvestConfirmation(BuildContext context) {
    final harvestDate = (_cycleData?['harvestDate'] as Timestamp?)?.toDate();
    final daysEarly = harvestDate != null 
        ? harvestDate.difference(DateTime.now()).inDays 
        : 0;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber, color: Color(0xFFFF9800), size: 28),
            SizedBox(width: 12),
            Text('Early Harvest Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are attempting to harvest $daysEarly days before the expected harvest date.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Are you sure you want to proceed with harvesting?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Yield may be lower than expected\n'
                    '• Grain quality might be affected\n'
                    '• This will mark the cycle as completed\n'
                    '• You will need to provide a reason for early harvest',
                    style: TextStyle(fontSize: 13, color: Color(0xFFE65100)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to harvest recording with early harvest flag
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => HarvestRecordingScreen(
                  cycleId: widget.cycleId,
                  userId: widget.uid,
                  isEarlyHarvest: true,
                  daysEarly: daysEarly,
                )
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E37),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Yes, Proceed',
              style: TextStyle(
                color: Colors.white, // change to any color you want
              ),
            ),
          ),
        ],
      ),
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
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchRecentActivities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    height: 100,
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final activities = snapshot.data ?? [];
              if (activities.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No recent activities'),
                  ),
                );
              }
              return Column(
                children: activities.asMap().entries.map((entry) {
                  final index = entry.key;
                  final act = entry.value;
                  final isLast = index == activities.length - 1;
                  return Column(
                    children: [
                      _buildActivityItem(
                        icon: _getIconForActivity(act['title']),
                        title: act['title'],
                        subtitle: act['subtitle'],
                        time: _formatTimeAgo(act['timestamp']),
                        iconColor: _getColorForActivity(act['title']),
                      ),
                      if (!isLast) const Divider(height: 24),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              Text(
                time,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
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