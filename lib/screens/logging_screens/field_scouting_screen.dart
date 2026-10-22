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
  String? _selectedCycleId;
  List<Map<String, dynamic>> _loadedCycles = [];

  @override
  void initState() {
    super.initState();
    _selectedCycleId = widget.cycleId?.trim();
    _cycles = _fetchCycles();
    _cycles.then(
      (_) {
        if (mounted) setState(() {});
      },
      onError: (Object error) {
        // FutureBuilder displays fetch errors when selecting a cycle.
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchCycles() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cycles')
        .orderBy('createdAt', descending: true)
        .safeGet();
    _loadedCycles = snapshot.docs
        .where(
          (doc) =>
              doc.data()['isCompleted'] != true &&
              doc.data()['plantingDate'] is Timestamp &&
              doc.data()['harvestDate'] is Timestamp,
        )
        .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
        .toList();
    return _loadedCycles;
  }

  MonitoringScreen _scouting(String cycleId) => MonitoringScreen(
    key: ValueKey(cycleId),
    cycleId: cycleId,
    quickLog: true,
    cycleSelector: (saveDraft) => _cycleSelector(cycleId, saveDraft: saveDraft),
    userId: widget.userId,
    initialWeekIndex: widget.weekIndex,
    initialStationIndex: widget.stationId == null
        ? null
        : (int.tryParse(widget.stationId!.split(' ').last) ?? 1) - 1,
  );

  Widget _cycleSelector(
    String? selected, {
    Future<bool> Function()? saveDraft,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: DropdownButtonFormField<String>(
        initialValue: selected,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Growth Cycle',
          border: InputBorder.none,
        ),
        items: [
          for (final cycle in _loadedCycles)
            DropdownMenuItem(
              value: cycle['id'] as String,
              child: Text(
                '${cycle['cycleName'] ?? 'Unnamed Cycle'} - ${cycle['fieldName'] ?? 'Unknown Field'}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (selected != null &&
              !_loadedCycles.any((cycle) => cycle['id'] == selected))
            DropdownMenuItem(
              value: selected,
              child: const Text('Selected growth cycle'),
            ),
        ],
        onChanged: (value) async {
          if (value == null || value == _selectedCycleId) return;
          if (saveDraft != null && !await saveDraft()) return;
          if (mounted) setState(() => _selectedCycleId = value);
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cycleId = _selectedCycleId;
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
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Weekly crop inspection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                _cycleSelector(null),
                const SizedBox(height: 20),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Select a growth cycle to choose a week and station, record observations, and assess damaged plants.',
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
