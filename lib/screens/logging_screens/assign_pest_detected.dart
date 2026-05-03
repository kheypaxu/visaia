import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AssignPestScreen extends StatefulWidget {
  final String userId;
  final String pestName;
  final String detectedStage; // "larvae", "eggs", "pupae"
  final String? imagePath; // optional, to store later

  const AssignPestScreen({
    super.key,
    required this.userId,
    required this.pestName,
    required this.detectedStage,
    this.imagePath,
  });

  @override
  State<AssignPestScreen> createState() => _AssignPestScreenState();
}

class _AssignPestScreenState extends State<AssignPestScreen> {
  String? _selectedCycleId;
  int _selectedStation = 1;
  List<Map<String, dynamic>> _cycles = [];
  bool _isLoading = true;
  bool _isSaving = false;

  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _bgColor = Color(0xFFF4F8F5);
  static const _mutedText = Color(0xFF9E9E9E);
  static const _borderColor = Color(0xFFDDEEE4);

  @override
  void initState() {
    super.initState();
    _fetchCycles();
  }

  Future<void> _fetchCycles() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .where('isCompleted', isEqualTo: false)
          .get();

      setState(() {
        _cycles = snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            'name': doc['cycleName'] ?? 'Unnamed',
            'fieldName': doc['fieldName'] ?? '',
            'plantingDate': (doc['plantingDate'] as Timestamp?)?.toDate(),
            'harvestDate': (doc['harvestDate'] as Timestamp?)?.toDate(),
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePestRecord() async {
    if (_selectedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cropping cycle')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .get();

      final plantingDate = (cycleDoc.data()?['plantingDate'] as Timestamp?)?.toDate();
      if (plantingDate == null) throw Exception('Invalid cycle planting date');

      final daysSincePlanting = DateTime.now().difference(plantingDate).inDays;
      final weekNumber = (daysSincePlanting / 7).floor() + 1;
      final weekId = 'week_$weekNumber';

      final weekRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .collection('weeks')
          .doc(weekId);

      final weekSnap = await weekRef.get();

      List<Map<String, dynamic>> stations = [];
      if (weekSnap.exists && weekSnap.data()?['stations'] != null) {
        stations = List<Map<String, dynamic>>.from(
            (weekSnap.data()!['stations'] as List).map((s) => Map<String, dynamic>.from(s)));
      } else {
        stations = List.generate(5, (i) => {
          'title': 'Station ${i + 1}',
          'completed': false,
          'plantsInspected': 0,
          'damaged': 0,
          'fawObserved': false,
          'eggMasses': 0,
          'larvae': 0,
          'pupae': 0,
          'notes': '',
        });
      }

      final stationIndex = _selectedStation - 1;
      if (stationIndex >= 0 && stationIndex < stations.length) {
        final stageKey = widget.detectedStage; // 'eggs', 'larvae', 'pupae'
        if (stations[stationIndex].containsKey(stageKey)) {
          stations[stationIndex][stageKey] = (stations[stationIndex][stageKey] as int) + 1;
          if (widget.pestName.toLowerCase().contains('armyworm')) {
            stations[stationIndex]['fawObserved'] = true;
          }
        }
      }

      final totalDamaged = stations.fold<int>(0, (int total, s) => total + (s['damaged'] as int? ?? 0));
      final totalEggs = stations.fold<int>(0, (int total, s) => total + (s['eggMasses'] as int? ?? 0));
      final totalLarvae = stations.fold<int>(0, (int total, s) => total + (s['larvae'] as int? ?? 0));
      final totalPupae = stations.fold<int>(0, (int total, s) => total + (s['pupae'] as int? ?? 0));
      final completedStations = stations.where((s) => s['completed'] as bool? ?? false).length;

      await weekRef.set({
        'stations': stations,
        'totals': {
          'damaged': totalDamaged,
          'eggs': totalEggs,
          'larvae': totalLarvae,
          'pupae': totalPupae,
        },
        'completedStations': completedStations,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save as daily activity
      final dayNumber = daysSincePlanting + 1;
      final dayId = 'day_${dayNumber.toString().padLeft(2, '0')}';
      final activityId = 'pest_ai_${DateTime.now().millisecondsSinceEpoch}';
      final activityData = {
        'type': 'AI Pest Detection - ${widget.pestName} (${widget.detectedStage})',
        'notes': 'Added via AI image recognition to Station $_selectedStation.',
        'images': widget.imagePath != null ? [widget.imagePath!] : [],
        'completed': true,
        'completedAt': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'pestData': {
          'pest': widget.pestName,
          'stage': widget.detectedStage,
          'station': _selectedStation,
          'source': 'AI',
        }
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .collection('dailyLogs')
          .doc(dayId)
          .collection('activities')
          .doc(activityId)
          .set(activityData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added 1 ${widget.detectedStage} to Station $_selectedStation'),
            backgroundColor: _green,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Assign Pest',
          style: GoogleFonts.inter(
            color: _darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pest summary card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _green.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bug_report, color: _green, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detected Pest',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: _mutedText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                widget.pestName,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _darkGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Life Stage: ${widget.detectedStage}',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cycle selection
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CROPPING CYCLE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _mutedText,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildCycleSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Station selection
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STATION',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _mutedText,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStationSelector(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePestRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Save to Cycle',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCycleSelector() {
    if (_cycles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No active cropping cycles found.\nPlease create a cycle first.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _mutedText, fontSize: 14),
          ),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedCycleId,
      decoration: InputDecoration(
        filled: true,
        fillColor: _bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: _cycles.map<DropdownMenuItem<String>>((cycle) {
        return DropdownMenuItem<String>(
          value: cycle['id'] as String,
          child: Text(
            '${cycle['name']} • ${cycle['fieldName']}',
            style: GoogleFonts.inter(fontSize: 14),
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedCycleId = value),
      hint: Text('Select cropping cycle', style: GoogleFonts.inter(color: _mutedText)),
    );
  }

  Widget _buildStationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final stationNum = index + 1;
        final isSelected = _selectedStation == stationNum;
        return GestureDetector(
          onTap: () => setState(() => _selectedStation = stationNum),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSelected ? _green : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? _green : _borderColor,
                width: 2,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: _green.withOpacity(0.3), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Text(
                '$stationNum',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : _darkGreen,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}