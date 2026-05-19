import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:visaia/screens/monitoring_screens/monitoring.dart';
import 'package:visaia/screens/logging_screens/harvest_recording.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class CycleDetailsScreen extends StatefulWidget {
  final String cycleId;
  final String uid;

  const CycleDetailsScreen(
      {super.key, required this.cycleId, required this.uid});

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

  Future<List<QueryDocumentSnapshot>> _fetchReports() async {
    // Fetch all reports for this farmer (default index exists on 'farmerId')
    final snapshot = await FirebaseFirestore.instance
        .collection('reports')
        .where('farmerId', isEqualTo: widget.uid)
        .get();

    // Filter by cycleId and sort in memory (no extra index needed)
    final filtered = snapshot.docs
        .where((doc) => doc.get('cycleId') == widget.cycleId)
        .toList();

    // Sort by timestamp descending (most recent first)
    filtered.sort((a, b) {
      final aTime = (a.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bTime = (b.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime(0);
      return bTime.compareTo(aTime);
    });

    return filtered;
  }
  
  List<String> _extractRecommendations(List<QueryDocumentSnapshot> reports) {
    final List<String> recs = [];
    for (final doc in reports) {
      final data = doc.data() as Map<String, dynamic>;
      final analysis = data['analysis'] as String?;
      final treatment = data['treatment'] as String?;
      final detection = data['detection'] as String?;
      final risk = data['risk'] as String?;

      if (analysis != null && analysis.isNotEmpty) {
        recs.add(analysis);
      } else if (treatment != null && treatment.isNotEmpty) {
        recs.add(treatment);
      } else {
        recs.add('${detection ?? 'Pest'} detected. Risk: ${risk ?? 'unknown'}.');
      }
    }
    return recs;
  }

  Widget _buildRecommendationsSection() {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _fetchReports(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B5E37)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not load recommendations: ${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }
        final reports = snapshot.data!;
        final recommendations = _extractRecommendations(reports);

        if (recommendations.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.grey.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No reports available yet. Recommendations will appear once pest/disease reports are recorded.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

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
          child: ExpansionTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF0C002).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFD4A002)),
            ),
            title: const Text(
              'Recommendations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${recommendations.length} actionable ${recommendations.length == 1 ? 'insight' : 'insights'}',
              style: TextStyle(fontSize: 12, color: const Color(0xFF5E6266).withValues(alpha: 0.7)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: recommendations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rec = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == recommendations.length - 1 ? 0 : 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1B5E37),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MarkdownBody(
                              data: rec,
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF2D3132)),
                                strong: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B5E37)),
                                em: const TextStyle(fontStyle: FontStyle.italic),
                                listBullet: const TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF2D3132)),
                                blockquote: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B), fontStyle: FontStyle.italic),
                                blockquoteDecoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: const Color(0xFF1B5E37).withValues(alpha: 0.4), width: 3)),
                                  color: const Color(0xFFF7F8F5),
                                ),
                              ),
                              selectable: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    return LatLng(
        lat / _fieldBoundaries.length, lng / _fieldBoundaries.length);
  }

  String _formatTimeAgo(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 7) return DateFormat('MMM d').format(dateTime);
    if (diff.inDays > 0)
      return '${diff.inDays}d ago';
    if (diff.inHours > 0)
      return '${diff.inHours}h ago';
    if (diff.inMinutes > 0)
      return '${diff.inMinutes}m ago';
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
    if (title.contains('Watering')) return const Color(0xFF3B82F6);
    if (title.contains('Field Scouting')) return const Color(0xFF8B5CF6);
    if (title.contains('Fertilizing')) return const Color(0xFFF59E0B);
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

    for (int offset = 0; offset < 5; offset++) {
      int dayNumber = daysSincePlanting - offset;
      if (dayNumber < 0) continue;

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
            .limit(3)
            .get();

        for (var doc in activitiesSnapshot.docs) {
          final data = doc.data();
          allActivities.add({
            'id': doc.id,
            'title': data['type'] ?? 'Activity',
            'subtitle': data['notes'] ?? '',
            'timestamp':
                data['timestamp'] as Timestamp? ?? Timestamp.now(),
            'completed': data['completed'] ?? false,
          });
        }
      } catch (e) {
        debugPrint('No activities for $dayId');
      }
    }

    allActivities.sort((a, b) => (b['timestamp'] as Timestamp)
        .toDate()
        .compareTo((a['timestamp'] as Timestamp).toDate()));

    return allActivities.take(5).toList();
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
          'Cycle Details',
          style: TextStyle(
            color: Color(0xFF1A1C1E),
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1B5E37)))
          : _error != null && _cycleData == null
              ? _buildErrorState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildGrowthProgress(),
                      const SizedBox(height: 16),
                      _buildActionButtons(context),
                      const SizedBox(height: 16),
                      _buildRiskAlert(),
                      const SizedBox(height: 16),
                      _buildRecommendationsSection(),
                      const SizedBox(height: 16),
                      _buildMapPreview(),
                      const SizedBox(height: 16),
                      _buildRecentActivity(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                cycleName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1C1E),
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 6,
                    height: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF1B5E37),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1B5E37),
                      letterSpacing: 0.5,
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
            Icon(Icons.location_on_outlined,
                size: 15,
                color: const Color(0xFF5E6266).withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              '$fieldName · $cropVariety',
              style: TextStyle(
                  color:
                      const Color(0xFF5E6266).withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
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
    final progressPercent = (_progress * 100).toInt();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Growth Progress',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E37).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B5E37),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day $_elapsedDays of $_totalDays',
                style: TextStyle(
                    color: const Color(0xFF1A1C1E)
                        .withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              Text(
                '$remainingDays days left',
                style: const TextStyle(
                  color: Color(0xFF1B5E37),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EAE5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1B5E37)),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAF8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DateInfo(
                  label: 'PLANTED',
                  date: plantingDate != null
                      ? _formatDate(plantingDate)
                      : 'N/A',
                ),
                Container(
                  width: 1, height: 32, color: const Color(0xFFE8EAE5)),
                _DateInfo(
                  label: 'EXPECTED HARVEST',
                  date: harvestDate != null
                      ? _formatDate(harvestDate)
                      : 'N/A',
                  alignEnd: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final now = DateTime.now();
    final harvestDate =
        (_cycleData?['harvestDate'] as Timestamp?)?.toDate();
    final isEarlyHarvest =
        harvestDate != null && now.isBefore(harvestDate);

    return Column(
      children: [
        _buildActionButton(
          icon: Icons.eco_outlined,
          title: 'Monitoring',
          subtitle: 'Weekly logs and trap records',
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MonitoringScreen(
                          cycleId: widget.cycleId,
                          userId: widget.uid,
                        )));
          },
        ),
        const SizedBox(height: 10),
        _buildActionButton(
          icon: Icons.shopping_basket_outlined,
          title: 'Record Harvest',
          subtitle: isEarlyHarvest
              ? 'Early harvest — confirmation needed'
              : 'Finalize yield and losses',
          isWarning: isEarlyHarvest,
          onTap: () {
            if (isEarlyHarvest) {
              _showEarlyHarvestConfirmation(context);
            } else {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => HarvestRecordingScreen(
                            cycleId: widget.cycleId,
                            userId: widget.uid,
                          )));
            }
          },
        ),
      ],
    );
  }


  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isWarning = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E37),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B5E37)
                  .withValues(alpha: isWarning ? 0.12 : 0.2),
              blurRadius: isWarning ? 6 : 12,
              offset: const Offset(0, 3),
            ),
          ],
          border: isWarning
              ? Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            if (isWarning)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'EARLY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF59E0B),
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              Icon(Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showEarlyHarvestConfirmation(BuildContext context) {
    final harvestDate =
        (_cycleData?['harvestDate'] as Timestamp?)?.toDate();
    final daysEarly = harvestDate != null
        ? harvestDate.difference(DateTime.now()).inDays
        : 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFBA1A1A), size: 36),
              ),
              const SizedBox(height: 24),
              const Text(
                'Early Harvest',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You\'re harvesting $daysEarly days before the expected date.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF5E6266)
                        .withValues(alpha: 0.8),
                    height: 1.4),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBF0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          const Color(0xFFFFE082).withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: const Color(0xFFD48806)),
                        const SizedBox(width: 6),
                        const Text(
                          'Keep in mind',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF9A6A00),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Yield may be lower than expected\n'
                      '• Grain quality might be affected\n'
                      '• Cycle will be marked completed\n'
                      '• A reason for early harvest is required',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF9A6A00)
                            .withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                HarvestRecordingScreen(
                                  cycleId: widget.cycleId,
                                  userId: widget.uid,
                                  isEarlyHarvest: true,
                                  daysEarly: daysEarly,
                                )));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E37),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Proceed with Harvest',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF3F5EE),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF5E6266),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskAlert() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFFECACA).withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFDC2626),
              borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'High Risk Detected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        Text(
                          'Immediate attention required for Plot 4B',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF991B1B)
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: const Color(0xFF991B1B)
                          .withValues(alpha: 0.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    final boundaries = _fieldBoundaries;
    final center = _fieldCenter;

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Field Location',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAF8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_outlined,
                          size: 14,
                          color: const Color(0xFF5E6266)
                              .withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text(
                        'Map View',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5E6266)
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 180,
                width: double.infinity,
                color: const Color(0xFFF1F3F1),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: 15.0,
                        interactionOptions:
                            const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                          userAgentPackageName: 'com.visaia.app',
                        ),
                        if (boundaries.length >= 3)
                          PolygonLayer(
                            polygons: [
                              Polygon(
                                points: boundaries,
                                color: const Color(0xFF1B5E37)
                                    .withValues(alpha: 0.15),
                                borderColor:
                                    const Color(0xFF1B5E37),
                                borderStrokeWidth: 2,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Navigate to full activity log
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E37)
                        .withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchRecentActivities(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF1B5E37)),
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500)),
                );
              }
              final activities = snapshot.data ?? [];
              if (activities.isEmpty) {
                return _buildEmptyActivity();
              }
              return Column(
                children: activities
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final act = entry.value;
                  final isLast =
                      index == activities.length - 1;
                  return _buildActivityItem(
                    icon:
                        _getIconForActivity(act['title']),
                    title: act['title'],
                    subtitle: act['subtitle'],
                    time: _formatTimeAgo(act['timestamp']),
                    iconColor:
                        _getColorForActivity(act['title']),
                    isLast: isLast,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1ED),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.history,
                size: 24,
                color: const Color(0xFF5E6266)
                    .withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 12),
          Text(
            'No recent activities',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF5E6266)
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Activities from daily logs will appear here',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF5E6266)
                  .withValues(alpha: 0.4),
            ),
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
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(icon, color: iconColor, size: 18),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(
                          vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EAE5),
                        borderRadius:
                            BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1A1C1E),
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF5E6266)
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: const Color(0xFF5E6266)
                            .withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateInfo extends StatelessWidget {
  final String label;
  final String date;
  final bool alignEnd;

  const _DateInfo(
      {required this.label, required this.date, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF5E6266).withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1C1E),
          ),
        ),
      ],
    );
  }
}