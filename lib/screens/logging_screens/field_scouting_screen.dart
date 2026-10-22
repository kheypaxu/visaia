import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:visaia/screens/monitoring_screens/monitoring.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

/// Quick Log entry point for the shared weekly scouting workflow.
class FieldScoutingFormScreen extends StatefulWidget {
  final String userId;
  final String? cycleId;
  final String? stationId;
  final int? weekIndex;

  const FieldScoutingFormScreen({
    super.key,
    required this.userId,
    this.cycleId,
    this.stationId,
    this.weekIndex,
  });

  @override
  State<FieldScoutingFormScreen> createState() =>
      _FieldScoutingFormScreenState();
}

class _FieldScoutingFormScreenState extends State<FieldScoutingFormScreen> {
  late Future<List<Map<String, dynamic>>> _cycles;

  @override
  void initState() {
    super.initState();
    _cycles = _fetchCycles();
  }

  Future<List<Map<String, dynamic>>> _fetchCycles() async {
    if (widget.cycleId?.trim().isNotEmpty == true) return [];
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cycles')
        .orderBy('createdAt', descending: true)
        .safeGet();
    return snapshot.docs
        .where(
          (doc) =>
              doc.data()['isCompleted'] != true &&
              doc.data()['plantingDate'] is Timestamp &&
              doc.data()['harvestDate'] is Timestamp,
        )
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();
  }

  MonitoringScreen _scouting(String cycleId) => MonitoringScreen(
    cycleId: cycleId,
    userId: widget.userId,
    initialWeekIndex: widget.weekIndex,
    initialStationIndex: widget.stationId == null
        ? null
        : (int.tryParse(widget.stationId!.split(' ').last) ?? 1) - 1,
  );

  @override
  Widget build(BuildContext context) {
    final cycleId = widget.cycleId?.trim();
    if (cycleId != null && cycleId.isNotEmpty) return _scouting(cycleId);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFA),
      appBar: AppBar(title: const Text('Field Scouting')),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _cycles,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to load growth cycles.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _cycles = _fetchCycles()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final cycles = snapshot.data ?? [];
            if (cycles.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Create an active growth cycle with planting and harvest dates to start field scouting.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Select Growth Cycle',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Inspect 5 stations with 10 plants each, verify observations, and submit your weekly scouting report.',
                ),
                const SizedBox(height: 16),
                for (final cycle in cycles)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.grass_rounded),
                      title: Text(
                        cycle['cycleName'] as String? ?? 'Unnamed Cycle',
                      ),
                      subtitle: Text(
                        cycle['fieldName'] as String? ?? 'Unknown Field',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _scouting(cycle['id'] as String),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
