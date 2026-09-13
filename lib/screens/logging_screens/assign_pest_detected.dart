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

  // ─── Risk Level System (5 Levels based on Life Stage + DAP) ────────────
  
  /// Get growth stage from DAP (Days After Planting)
  String _getGrowthStageFromDAP(int dap) {
    if (dap <= 14) return 'SEEDLING';
    if (dap <= 30) return 'EARLY_WHORL';
    if (dap <= 45) return 'LATE_WHORL';
    if (dap <= 55) return 'TASSELING_SILKING';
    if (dap <= 75) return 'GRAIN_FILLING';
    return 'MATURITY';
  }

  /// Get display name for growth stage
  String _getGrowthStageDisplay(int dap) {
    if (dap <= 14) return 'Seedling (0-14 DAP)';
    if (dap <= 30) return 'Early Whorl (14-30 DAP)';
    if (dap <= 45) return 'Late Whorl (30-45 DAP)';
    if (dap <= 55) return 'Tasseling-Silking (45-55 DAP)';
    if (dap <= 75) return 'Grain Filling (55-75 DAP)';
    return 'Maturity (75+ DAP)';
  }

  /// Calculate risk level based on life stage and DAP
  String _calculateRiskLevel({
    required String lifeStage,
    required int dap,
  }) {
    // Map life stage to key
    String ls = lifeStage.toLowerCase();
    String lifeStageKey;
    if (ls.contains('egg')) lifeStageKey = 'egg';
    else if (ls.contains('larva') || ls.contains('caterpillar')) lifeStageKey = 'larva';
    else if (ls.contains('pupa')) lifeStageKey = 'pupa';
    else if (ls.contains('moth') || ls.contains('adult')) lifeStageKey = 'moth';
    else lifeStageKey = 'none';
    
    // Get growth stage from DAP
    String growthStageKey = _getGrowthStageFromDAP(dap);
    
    // Risk matrix based on FAW Life Stage + Crop Growth Stage
    // From the MitigationNew.pdf document
    final riskMatrix = {
      'egg': {
        'SEEDLING': 'Low',
        'EARLY_WHORL': 'Moderate',
        'LATE_WHORL': 'Moderate',
        'TASSELING_SILKING': 'Moderate',
        'GRAIN_FILLING': 'Low',
        'MATURITY': 'Very Low',
      },
      'larva': {
        'SEEDLING': 'Moderate',
        'EARLY_WHORL': 'Moderate',
        'LATE_WHORL': 'High',
        'TASSELING_SILKING': 'Very High',
        'GRAIN_FILLING': 'High',
        'MATURITY': 'Low',
      },
      'pupa': {
        'SEEDLING': 'Very Low',
        'EARLY_WHORL': 'Very Low',
        'LATE_WHORL': 'Low',
        'TASSELING_SILKING': 'Low',
        'GRAIN_FILLING': 'Low',
        'MATURITY': 'Low',
      },
      'moth': {
        'SEEDLING': 'Low',
        'EARLY_WHORL': 'Moderate',
        'LATE_WHORL': 'High',
        'TASSELING_SILKING': 'Moderate',
        'GRAIN_FILLING': 'Low',
        'MATURITY': 'Low',
      },
      'none': {
        'SEEDLING': 'Very Low',
        'EARLY_WHORL': 'Very Low',
        'LATE_WHORL': 'Very Low',
        'TASSELING_SILKING': 'Very Low',
        'GRAIN_FILLING': 'Very Low',
        'MATURITY': 'Very Low',
      },
    };
    
    return riskMatrix[lifeStageKey]?[growthStageKey] ?? 'Low';
  }

  @override
  void initState() {
    super.initState();
    _fetchCycles();
  }

  Future<void> _fetchCycles() async {
    try {
      // Get all cycles (with offline cache fallback)
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .get();
      } catch (_) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .get(const GetOptions(source: Source.cache));
      }

      print('✓ Fetched ${snapshot.docs.length} cycles for userId: ${widget.userId}');

      // Filter in memory: only cycles that are NOT completed
      // A cycle is considered completed if:
      // - isCompleted == true, OR
      // - isPreviousCycle == true, OR
      // - status == 'completed'
      final activeCycles = snapshot.docs.where((doc) {
        final data = doc.data();
        final isCompleted = data['isCompleted'] == true;
        final isPrevious = data['isPreviousCycle'] == true;
        final statusCompleted = data['status'] == 'completed';
        final isActive = !isCompleted && !isPrevious && !statusCompleted;
        if (!isActive) {
          print('  ✗ Skipped: ${data['cycleName']} (completed=$isCompleted, previous=$isPrevious, status=$statusCompleted)');
        }
        return isActive;
      }).map((doc) {
        final data = doc.data();
        print('  ✓ Added: ${data['cycleName']}');
        return {
          'id': doc.id,
          'name': data['cycleName'] ?? 'Unnamed',
          'fieldName': data['fieldName'] ?? '',
          'plantingDate': (data['plantingDate'] as Timestamp?)?.toDate(),
          'harvestDate': (data['harvestDate'] as Timestamp?)?.toDate(),
        };
      }).toList();

      print('✓ Active cycles after filtering: ${activeCycles.length}');
      setState(() {
        _cycles = activeCycles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching cycles: $e');
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
    print('🔵 Starting pest record save...');
    print('  Cycle: $_selectedCycleId');
    print('  Station: $_selectedStation');
    print('  Pest: ${widget.pestName}');
    print('  Stage: ${widget.detectedStage}');

    try {
      DocumentSnapshot<Map<String, dynamic>> cycleDoc;
      try {
        cycleDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .doc(_selectedCycleId)
            .get();
      } catch (_) {
        cycleDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('cycles')
            .doc(_selectedCycleId)
            .get(const GetOptions(source: Source.cache));
      }

      final plantingDate = (cycleDoc.data()?['plantingDate'] as Timestamp?)?.toDate();
      if (plantingDate == null) throw Exception('Invalid cycle planting date');

      final daysSincePlanting = DateTime.now().difference(plantingDate).inDays;
      final weekNumber = (daysSincePlanting / 7).floor() + 1;
      final weekId = 'week_$weekNumber';

      // ─── Calculate Risk Level ──────────────────────────────────────────
      final dap = daysSincePlanting;
      final riskLevel = _calculateRiskLevel(
        lifeStage: widget.detectedStage,
        dap: dap,
      );
      final growthStage = _getGrowthStageFromDAP(dap);
      final growthStageDisplay = _getGrowthStageDisplay(dap);

      print('  📊 Risk Assessment:');
      print('    DAP: $dap days');
      print('    Growth Stage: $growthStage ($growthStageDisplay)');
      print('    Risk Level: $riskLevel');

      print('  Days since planting: $daysSincePlanting');
      print('  Week: $weekNumber ($weekId)');

      final weekRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .collection('weeks')
          .doc(weekId);

      DocumentSnapshot<Map<String, dynamic>> weekSnap;
      try {
        weekSnap = await weekRef.get();
      } catch (_) {
        weekSnap = await weekRef.get(const GetOptions(source: Source.cache));
      }

      List<Map<String, dynamic>> stations;
        if (weekSnap.exists && weekSnap.data()?['stations'] != null) {
          stations = List<Map<String, dynamic>>.from(
            (weekSnap.data()!['stations'] as List).map((s) {
              var station = Map<String, dynamic>.from(s);
              // Ensure all required fields exist
              station.putIfAbsent('eggMasses', () => 0);
              station.putIfAbsent('larvae', () => 0);
              station.putIfAbsent('pupae', () => 0);
              station.putIfAbsent('moths', () => 0);
              station.putIfAbsent('damaged', () => 0);
              station.putIfAbsent('fawObserved', () => false);
              station.putIfAbsent('completed', () => false);
              station.putIfAbsent('plantsInspected', () => 0);
              station.putIfAbsent('notes', () => '');
              station.putIfAbsent('verificationRequired', () => false);
              station.putIfAbsent('verificationCompleted', () => false);
              return station;
            }),
          );
        } else {
          // Create default 5 stations when week does not exist
          stations = List.generate(5, (i) => {
            'title': 'Station ${i + 1}',
            'completed': false,
            'plantsInspected': 0,
            'damaged': 0,
            'fawObserved': false,
            'eggMasses': 0,
            'larvae': 0,
            'pupae': 0,
            'moths': 0,
            'notes': '',
            'verificationRequired': false,
            'verificationCompleted': false,
          });
        }

      final stationIndex = _selectedStation - 1;

      // Inside _savePestRecord, after getting stationIndex
      if (stationIndex >= 0 && stationIndex < stations.length) {
        // Map detected stage to Firestore field name
        String stageKey;
        switch (widget.detectedStage.toLowerCase()) {
          case 'egg':
          case 'eggs':
            stageKey = 'eggMasses';
            break;
          case 'larva':
          case 'larvae':
            stageKey = 'larvae';
            break;
          case 'pupa':
          case 'pupae':
            stageKey = 'pupae';
            break;
          default:
            stageKey = widget.detectedStage;
        }
        
        if (!stations[stationIndex].containsKey(stageKey)) {
          stations[stationIndex][stageKey] = 0;
        }

        stations[stationIndex][stageKey] =
            (stations[stationIndex][stageKey] as int) + 1;

        if (widget.pestName.toLowerCase().contains('armyworm')) {
          stations[stationIndex]['fawObserved'] = true;
        }
      }

      final totalDamaged = stations.fold<int>(0, (int total, s) => total + (s['damaged'] as int? ?? 0));
      final totalEggs = stations.fold<int>(0, (int total, s) => total + (s['eggMasses'] as int? ?? 0));
      final totalLarvae = stations.fold<int>(0, (int total, s) => total + (s['larvae'] as int? ?? 0));
      final totalPupae = stations.fold<int>(0, (int total, s) => total + (s['pupae'] as int? ?? 0));
      final completedStations = stations.where((s) => s['completed'] as bool? ?? false).length;

      print('📊 Totals: eggs=$totalEggs, larvae=$totalLarvae, pupae=$totalPupae');

      print('📝 Saving to: users/${widget.userId}/cycles/$_selectedCycleId/weeks/$weekId');
      print('📝 Data to save: stations=${stations.length}, totals={eggs: $totalEggs, larvae: $totalLarvae, pupae: $totalPupae}');

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
        // ─── Add risk assessment data ──────────────────────────────────
        'riskAssessment': {
          'overallRisk': riskLevel,
          'growthStage': growthStage,
          'growthStageDisplay': growthStageDisplay,
          'dap': dap,
          'weekNumber': weekNumber,
          'lifeStage': widget.detectedStage,
          'calculatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      print('✓ Week data saved to Firestore with risk assessment: $riskLevel');

      // Verify the save was successful by reading it back
      final verifySnapshot = await weekRef.get();
      if (verifySnapshot.exists) {
        final savedStations = verifySnapshot.data()?['stations'] as List?;
        final savedLarvae = verifySnapshot.data()?['totals']?['larvae'] ?? 0;
        final savedRisk = verifySnapshot.data()?['riskAssessment']?['overallRisk'] ?? 'N/A';
        print('✓✓ VERIFIED: Week data exists with ${savedStations?.length} stations, larvae count: $savedLarvae, risk: $savedRisk');
      } else {
        print('❌ VERIFICATION FAILED: Week document not found after save!');
      }

      print('✓ Daily activity saved');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added 1 ${widget.detectedStage} to Station $_selectedStation'),
            backgroundColor: _green,
            duration: const Duration(seconds: 1),
          ),
        );

        // Return the cycleId along with DAP and growth stage to AIResultScreen
        Navigator.pop(context, {
          'cycleId': _selectedCycleId,
          'dap': dap,
          'growthStage': growthStage,
          'growthStageDisplay': growthStageDisplay,
          'riskLevel': riskLevel,
        });
      }
    } catch (e) {
      print('❌ Error saving pest record: $e');
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