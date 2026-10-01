import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/services/firestore_image_service.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

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
  int _selectedWeek = 1;
  int _selectedStation = 1;
  List<Map<String, dynamic>> _cycles = [];
  bool _isLoading = true;
  bool _isSaving = false;
  Set<int> _completedWeeks = {};
  Map<int, List<Map<String, dynamic>>> _weeksStationData = {};
  bool _isLoadingWeeks = false;

  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _bgColor = Color(0xFFF4F8F5);
  static const _mutedText = Color(0xFF9E9E9E);
  static const _borderColor = Color(0xFFDDEEE4);

  Map<String, dynamic>? get _selectedCycle {
    if (_selectedCycleId == null) return null;
    return _cycles.firstWhere(
      (c) => c['id'] == _selectedCycleId,
      orElse: () => {},
    );
  }

  int get _cycleTotalWeeks {
    final cycle = _selectedCycle;
    if (cycle == null || cycle.isEmpty) return 12;
    final plantingDate = cycle['plantingDate'] as DateTime?;
    final harvestDate = cycle['harvestDate'] as DateTime?;
    if (plantingDate != null && harvestDate != null) {
      final days = harvestDate.difference(plantingDate).inDays;
      final weeks = (days / 7).ceil();
      return weeks.clamp(1, 24);
    }
    return 12;
  }

  int get _cycleCurrentWeek {
    final cycle = _selectedCycle;
    if (cycle == null || cycle.isEmpty) return 1;
    final plantingDate = cycle['plantingDate'] as DateTime?;
    if (plantingDate != null) {
      final days = DateTime.now().difference(plantingDate).inDays;
      final week = (days / 7).floor() + 1;
      return week.clamp(1, _cycleTotalWeeks);
    }
    return 1;
  }

  bool _isWeekDone(int weekNum) {
    return _completedWeeks.contains(weekNum);
  }

  bool _isStationDone(int weekNum, int stationNum) {
    if (_isWeekDone(weekNum)) return true;
    final stations = _weeksStationData[weekNum];
    if (stations != null && stationNum - 1 >= 0 && stationNum - 1 < stations.length) {
      final s = stations[stationNum - 1];
      return s['completed'] == true || s['verificationCompleted'] == true;
    }
    return false;
  }

  void _autoAdjustWeekAndStation() {
    final totalWeeks = _cycleTotalWeeks;
    if (_isWeekDone(_selectedWeek)) {
      int candidateWeek = -1;
      final cur = _cycleCurrentWeek;
      if (cur <= totalWeeks && !_isWeekDone(cur)) {
        candidateWeek = cur;
      } else {
        for (int w = 1; w <= totalWeeks; w++) {
          if (!_isWeekDone(w)) {
            candidateWeek = w;
            break;
          }
        }
      }
      if (candidateWeek != -1) {
        _selectedWeek = candidateWeek;
      }
    }
    _autoAdjustStation();
  }

  void _autoAdjustStation() {
    if (_isStationDone(_selectedWeek, _selectedStation)) {
      for (int s = 1; s <= 5; s++) {
        if (!_isStationDone(_selectedWeek, s)) {
          _selectedStation = s;
          break;
        }
      }
    }
  }

  bool get _isCurrentSelectionLocked {
    return _isWeekDone(_selectedWeek) || _isStationDone(_selectedWeek, _selectedStation);
  }

  String? get _selectionLockedReason {
    if (_isWeekDone(_selectedWeek)) {
      return 'Week $_selectedWeek scouting has already been fully completed. Pests cannot be added to finished weeks.';
    }
    if (_isStationDone(_selectedWeek, _selectedStation)) {
      return 'Station $_selectedStation (Week $_selectedWeek) has already completed verification & scouting. Please select another station.';
    }
    return null;
  }

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
    if (ls.contains('egg')) {
      lifeStageKey = 'egg';
    } else if (ls.contains('larva') || ls.contains('caterpillar')) {
      lifeStageKey = 'larva';
    } else if (ls.contains('pupa')) {
      lifeStageKey = 'pupa';
    } else if (ls.contains('moth') || ls.contains('adult')) {
      lifeStageKey = 'moth';
    } else {
      lifeStageKey = 'none';
    }
    
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
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .safeGet();

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
        if (activeCycles.isNotEmpty && _selectedCycleId == null) {
          _selectedCycleId = activeCycles.first['id'] as String;
          _selectedWeek = _cycleCurrentWeek;
        }
        _isLoading = false;
      });

      if (_selectedCycleId != null) {
        _loadCycleWeeksData(_selectedCycleId!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error fetching cycles: $e');
    }
  }

  Future<void> _loadCycleWeeksData(String cycleId) async {
    setState(() => _isLoadingWeeks = true);
    try {
      final weeksSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(cycleId)
          .collection('weeks')
          .safeGet();

      final completedWeeks = <int>{};
      final weeksStationData = <int, List<Map<String, dynamic>>>{};

      for (final doc in weeksSnapshot.docs) {
        final docId = doc.id; // e.g. "week_1"
        final weekNum = int.tryParse(docId.replaceAll(RegExp(r'[^0-9]'), ''));
        if (weekNum == null) continue;

        final data = doc.data();
        final stationsList = data['stations'];
        if (stationsList is List) {
          final stations = List<Map<String, dynamic>>.from(
            stationsList.map((s) => Map<String, dynamic>.from(s as Map)),
          );
          weeksStationData[weekNum] = stations;

          final allStationsDone = stations.isNotEmpty &&
              stations.every((s) => s['completed'] == true || s['verificationCompleted'] == true);
          final completedStations = data['completedStations'] as int? ?? 0;
          final isWeekCompleted = data['status'] == 'completed' ||
              data['isCompleted'] == true ||
              completedStations >= 5 ||
              allStationsDone;

          if (isWeekCompleted) {
            completedWeeks.add(weekNum);
          }
        } else if (data['status'] == 'completed' || data['isCompleted'] == true) {
          completedWeeks.add(weekNum);
        }
      }

      if (mounted) {
        setState(() {
          _completedWeeks = completedWeeks;
          _weeksStationData = weeksStationData;
          _isLoadingWeeks = false;
          _autoAdjustWeekAndStation();
        });
      }
    } catch (e) {
      print('Error loading cycle weeks data: $e');
      if (mounted) {
        setState(() => _isLoadingWeeks = false);
      }
    }
  }

  Future<void> _savePestRecord() async {
    if (_selectedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cropping cycle')),
      );
      return;
    }

    if (_isCurrentSelectionLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectionLockedReason ?? 'This station or week is already completed.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    print('🔵 Starting pest record save...');
    print('  Cycle: $_selectedCycleId');
    print('  Week: $_selectedWeek');
    print('  Station: $_selectedStation');
    print('  Pest: ${widget.pestName}');
    print('  Stage: ${widget.detectedStage}');

    try {
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .safeGet();

      final plantingDate = (cycleDoc.data()?['plantingDate'] as Timestamp?)?.toDate();
      final weekNumber = _selectedWeek;
      final weekId = 'week_$weekNumber';

      // ─── Calculate Risk Level ──────────────────────────────────────────
      final daysSincePlanting = plantingDate != null
          ? DateTime.now().difference(plantingDate).inDays
          : ((weekNumber - 1) * 7 + 1);
      final dap = daysSincePlanting < 0 ? 0 : daysSincePlanting;
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
      print('    Week: $weekNumber ($weekId)');

      final weekRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .collection('weeks')
          .doc(weekId);

      final weekSnap = await weekRef.safeGet();

      if (weekSnap.exists) {
        final weekData = weekSnap.data();
        final isWeekAlreadyDone = weekData?['status'] == 'completed' ||
            weekData?['isCompleted'] == true ||
            (weekData?['completedStations'] as int? ?? 0) >= 5;
        if (isWeekAlreadyDone) {
          if (mounted) {
            setState(() {
              _completedWeeks.add(_selectedWeek);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Week $_selectedWeek scouting has already been completed.'),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
          return;
        }
      }

      List<Map<String, dynamic>> stations;
      if (weekSnap.exists && weekSnap.data()?['stations'] != null) {
        stations = List<Map<String, dynamic>>.from(
          (weekSnap.data()!['stations'] as List).map((s) {
            var station = Map<String, dynamic>.from(s as Map);
            station.putIfAbsent('eggMasses', () => 0);
            station.putIfAbsent('larvae', () => 0);
            station.putIfAbsent('pupae', () => 0);
            station.putIfAbsent('moths', () => 0);
            station.putIfAbsent('damaged', () => 0);
            station.putIfAbsent('fawObserved', () => false);
            station.putIfAbsent('completed', () => false);
            final plantsInspected = station['plantsInspected'];
            if (plantsInspected is! num || plantsInspected.toInt() <= 0) {
              station['plantsInspected'] = 10;
            } else {
              station['plantsInspected'] = plantsInspected.toInt();
            }
            station.putIfAbsent('notes', () => '');
            station.putIfAbsent('verificationRequired', () => false);
            station.putIfAbsent('verificationCompleted', () => false);
            station.putIfAbsent('damageAssessmentChoice', () => null);
            station.putIfAbsent('plantDamageScores', () => <Map<String, dynamic>>[]);
            station.putIfAbsent('damagePhotos', () => <String>[]);
            station.putIfAbsent('capturedImages', () => {
              'eggMasses': [],
              'larvae': [],
              'pupae': [],
              'moths': [],
              'damage': [],
            });
            return station;
          }),
        );
      } else {
        // Create default 5 stations matching monitoring structure
        stations = List.generate(5, (i) => {
          'title': 'Station ${i + 1}',
          'completed': false,
          'plantsInspected': 10,
          'damaged': 0,
          'fawObserved': false,
          'eggMasses': 0,
          'larvae': 0,
          'pupae': 0,
          'moths': 0,
          'notes': '',
          'verificationRequired': false,
          'verificationCompleted': false,
          'damageAssessmentChoice': null,
          'plantDamageScores': <Map<String, dynamic>>[],
          'damagePhotos': <String>[],
          'capturedImages': {
            'eggMasses': [],
            'larvae': [],
            'pupae': [],
            'moths': [],
            'damage': [],
          },
        });
      }

      final stationIndex = _selectedStation - 1;

      if (stationIndex >= 0 && stationIndex < stations.length) {
        final stationMap = stations[stationIndex];
        if (stationMap['completed'] == true || stationMap['verificationCompleted'] == true) {
          setState(() {
            _weeksStationData[_selectedWeek] = stations;
            _autoAdjustStation();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Station $_selectedStation has already completed verification in Week $_selectedWeek.'),
                backgroundColor: Colors.orange.shade800,
              ),
            );
          }
          return;
        }

        // Map detected stage to Firestore field name
        String stageKey;
        final stageLower = widget.detectedStage.toLowerCase().trim();
        if (stageLower.contains('egg')) {
          stageKey = 'eggMasses';
        } else if (stageLower.contains('larva') || stageLower.contains('caterpillar')) {
          stageKey = 'larvae';
        } else if (stageLower.contains('pupa')) {
          stageKey = 'pupae';
        } else if (stageLower.contains('moth') || stageLower.contains('adult')) {
          stageKey = 'moths';
        } else if (stageLower.contains('damage') || stageLower.contains('leaf') || stageLower.contains('cob')) {
          stageKey = 'damaged';
        } else {
          stageKey = 'moths'; // Default fallback
        }
        
        if (stageKey == 'damaged') {
          stations[stationIndex]['damaged'] =
              (stations[stationIndex]['damaged'] as int? ?? 0) + 1;
          
          final rows = List<Map<String, dynamic>>.from(
            ((stations[stationIndex]['plantDamageScores'] as List?) ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)),
          );
          final currentDamaged = stations[stationIndex]['damaged'] as int;
          while (rows.length < currentDamaged) {
            rows.add({'plantNumber': rows.length + 1, 'whorlScore': null, 'cobScore': null});
          }
          stations[stationIndex]['plantDamageScores'] = rows;
        } else {
          if (!stations[stationIndex].containsKey(stageKey)) {
            stations[stationIndex][stageKey] = 0;
          }
          stations[stationIndex][stageKey] =
              (stations[stationIndex][stageKey] as int) + 1;
        }

        stations[stationIndex]['fawObserved'] = true;

        // Upload and attach the quick log image if provided
        if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
          try {
            final imageFile = File(widget.imagePath!);
            if (await imageFile.exists()) {
              Uint8List? compressedBytes;
              try {
                compressedBytes = await FlutterImageCompress.compressWithFile(
                  imageFile.path,
                  minWidth: 640,
                  minHeight: 640,
                  quality: 45,
                  format: CompressFormat.jpeg,
                );
              } catch (e) {
                print('Compression fallback: $e');
                compressedBytes = await imageFile.readAsBytes();
              }
              compressedBytes ??= await imageFile.readAsBytes();

              final imageRef = await FirestoreImageService.upload(
                bytes: compressedBytes,
                userId: widget.userId,
                cycleId: _selectedCycleId!,
                category: stageKey == 'damaged' ? 'damage' : stageKey,
                stationIndex: stationIndex,
              );

              final rawCaptured = stations[stationIndex]['capturedImages'];
              final capturedImages = rawCaptured is Map
                  ? Map<String, dynamic>.from(rawCaptured)
                  : <String, dynamic>{
                      'eggMasses': [],
                      'larvae': [],
                      'pupae': [],
                      'moths': [],
                      'damage': [],
                    };

              if (stageKey == 'damaged') {
                final damagePhotos = List<String>.from(
                  (stations[stationIndex]['damagePhotos'] as List?) ?? [],
                );
                damagePhotos.add(imageRef);
                stations[stationIndex]['damagePhotos'] = damagePhotos;

                final damageList = List<String>.from(
                  (capturedImages['damage'] as List?) ?? [],
                );
                damageList.add(imageRef);
                capturedImages['damage'] = damageList;
              } else {
                final list = List<String>.from(
                  (capturedImages[stageKey] as List?) ?? [],
                );
                list.add(imageRef);
                capturedImages[stageKey] = list;
              }
              stations[stationIndex]['capturedImages'] = capturedImages;
            }
          } catch (imgError) {
            print('⚠️ Error attaching image to station verification: $imgError');
          }
        }

        // Calculate verification status
        final capImgs = stations[stationIndex]['capturedImages'] as Map<String, dynamic>? ?? {};
        final eggsCount = stations[stationIndex]['eggMasses'] as int? ?? 0;
        final larvaeCount = stations[stationIndex]['larvae'] as int? ?? 0;
        final pupaeCount = stations[stationIndex]['pupae'] as int? ?? 0;
        final mothsCount = stations[stationIndex]['moths'] as int? ?? 0;
        final damagedCount = stations[stationIndex]['damaged'] as int? ?? 0;

        final eggsPhotos = (capImgs['eggMasses'] as List?)?.length ?? 0;
        final larvaePhotos = (capImgs['larvae'] as List?)?.length ?? 0;
        final pupaePhotos = (capImgs['pupae'] as List?)?.length ?? 0;
        final mothsPhotos = (capImgs['moths'] as List?)?.length ?? 0;
        final damagePhotosCount = (stations[stationIndex]['damagePhotos'] as List?)?.length ?? 0;

        final hasAny = eggsCount > 0 || larvaeCount > 0 || pupaeCount > 0 || mothsCount > 0 || damagedCount > 0;
        final isVerified = hasAny &&
            (eggsCount == 0 || eggsPhotos >= eggsCount) &&
            (larvaeCount == 0 || larvaePhotos >= larvaeCount) &&
            (pupaeCount == 0 || pupaePhotos >= pupaeCount) &&
            (mothsCount == 0 || mothsPhotos >= mothsCount) &&
            (damagedCount == 0 || damagePhotosCount >= damagedCount);

        stations[stationIndex]['verificationCompleted'] = isVerified;
        stations[stationIndex]['verificationRequired'] = hasAny && !isVerified;
      }

      final totalDamaged = stations.fold<int>(0, (int total, s) => total + (s['damaged'] as int? ?? 0));
      final totalEggs = stations.fold<int>(0, (int total, s) => total + (s['eggMasses'] as int? ?? 0));
      final totalLarvae = stations.fold<int>(0, (int total, s) => total + (s['larvae'] as int? ?? 0));
      final totalPupae = stations.fold<int>(0, (int total, s) => total + (s['pupae'] as int? ?? 0));
      final totalMoths = stations.fold<int>(0, (int total, s) => total + (s['moths'] as int? ?? 0));
      final completedStations = stations.where((s) => s['completed'] as bool? ?? false).length;

      print('📊 Totals: eggs=$totalEggs, larvae=$totalLarvae, pupae=$totalPupae, moths=$totalMoths, damaged=$totalDamaged');

      print('📝 Saving to: users/${widget.userId}/cycles/$_selectedCycleId/weeks/$weekId');

      await weekRef.set({
        'stations': stations,
        'totals': {
          'damaged': totalDamaged,
          'eggs': totalEggs,
          'larvae': totalLarvae,
          'pupae': totalPupae,
          'moths': totalMoths,
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
        final savedMoths = verifySnapshot.data()?['totals']?['moths'] ?? 0;
        final savedRisk = verifySnapshot.data()?['riskAssessment']?['overallRisk'] ?? 'N/A';
        print('✓✓ VERIFIED: Week data exists with ${savedStations?.length} stations, larvae count: $savedLarvae, moths count: $savedMoths, risk: $savedRisk');
      } else {
        print('❌ VERIFICATION FAILED: Week document not found after save!');
      }

      print('✓ Daily activity saved');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added 1 ${widget.detectedStage} to Station $_selectedStation (Week $_selectedWeek)'),
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
          'weekNumber': _selectedWeek,
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
                            color: _green.withValues(alpha: 0.1),
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

                  // Week selection
                  if (_selectedCycleId != null) ...[
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SCOUTING WEEK',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _mutedText,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isLoadingWeeks) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _green,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    'Week $_selectedWeek of $_cycleTotalWeeks',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildWeekSelector(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

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
                  const SizedBox(height: 24),

                  // Selection locked notice banner
                  if (_isCurrentSelectionLocked) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFFB74D), width: 1.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_rounded, color: Color(0xFFE65100), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isWeekDone(_selectedWeek) ? 'Week Already Completed' : 'Station Verification Completed',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBF360C),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _selectionLockedReason ?? 'Cannot assign pests to completed scouting weeks or stations.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFFE65100),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isSaving || _isCurrentSelectionLocked) ? null : _savePestRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        disabledBackgroundColor: Colors.grey.shade400,
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
                              _isCurrentSelectionLocked
                                  ? (_isWeekDone(_selectedWeek)
                                      ? 'Week $_selectedWeek Completed'
                                      : 'Station $_selectedStation Completed')
                                  : 'Save to Cycle',
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
      onChanged: (value) {
        setState(() {
          _selectedCycleId = value;
          _selectedWeek = _cycleCurrentWeek;
        });
        if (value != null) {
          _loadCycleWeeksData(value);
        }
      },
      hint: Text('Select cropping cycle', style: GoogleFonts.inter(color: _mutedText)),
    );
  }

  Widget _buildWeekSelector() {
    final totalWeeks = _cycleTotalWeeks;
    final currentWeek = _cycleCurrentWeek;

    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalWeeks,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final weekNum = index + 1;
          final isSelected = _selectedWeek == weekNum;
          final isCurrent = weekNum == currentWeek;
          final isDone = _isWeekDone(weekNum);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedWeek = weekNum;
                _autoAdjustStation();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _green
                    : (isDone ? const Color(0xFFE8F5E9) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _green
                      : (isDone ? const Color(0xFFA5D6A7) : _borderColor),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: _green.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))]
                    : null,
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Week $weekNum',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isDone ? const Color(0xFF1B5E20) : _darkGreen),
                      ),
                    ),
                    if (isDone) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFC8E6C9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check,
                              size: 10,
                              color: isSelected ? Colors.white : const Color(0xFF1B5E20),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Done',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isCurrent) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withValues(alpha: 0.25) : _green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Now',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : _green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(5, (index) {
        final stationNum = index + 1;
        final isSelected = _selectedStation == stationNum;
        final isDone = _isStationDone(_selectedWeek, stationNum);

        return GestureDetector(
          onTap: () {
            setState(() => _selectedStation = stationNum);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDone ? const Color(0xFF2E7D32) : _green)
                          : (isDone ? const Color(0xFFE8F5E9) : Colors.white),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? _green
                            : (isDone ? const Color(0xFFA5D6A7) : _borderColor),
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: _green.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$stationNum',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDone ? const Color(0xFF1B5E20) : _darkGreen),
                        ),
                      ),
                    ),
                  ),
                  if (isDone)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _green : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check,
                          size: 10,
                          color: isSelected ? _green : Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isDone ? 'Done' : 'Open',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDone ? const Color(0xFF2E7D32) : _mutedText,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}