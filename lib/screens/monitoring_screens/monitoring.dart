import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/widgets/success_modal.dart';
import 'package:visaia/services/firestore_service.dart';
import 'package:visaia/screens/logging_screens/daily_log_screen.dart';

// ==========================================
// BRAND COLORS
// ==========================================
const Color kPrimaryGreen = Color(0xFF004D40);
const Color kActionGreen = Color(0xFF1B5E20);
const Color kLightGreenBg = Color(0xFFF1F8F1);
const Color kTextDark = Color(0xFF1A1A1A);
const Color kTextGrey = Color(0xFF666666);
const Color kAccentRed = Color(0xFFB71C1C);
const Color kBorderColor = Color(0xFFE0E0E0);
const Color kSoftGreenLabel = Color(0xFFC8E6C9);
const Color kActiveTaskBlue = Color(0xFF1565C0);
const Color kActiveTaskBg = Color(0xFFE3F2FD);

class MonitoringScreen extends StatefulWidget {
  final String cycleId;
  final String? userId;

  const MonitoringScreen({super.key, required this.cycleId, this.userId});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  late final MonitoringFirestoreService _firestoreService;
  late final String _userId;
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    final userId = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _error = 'User not authenticated';
        _isInitialLoading = false;
      });
      return;
    }
    _userId = userId;
    _firestoreService = MonitoringFirestoreService(userId: userId);
    _loadCycleData();
  }

  // Loading & Error
  bool _isInitialLoading = true;
  bool _isWeekLoading = false;
  String? _error;

  // Cycle metadata
  String _cycleName = '';
  String _fieldName = '';
  DateTime? _plantingDate;
  DateTime? _harvestDate;

  // Computed dates
  int get _totalDays =>
      (_plantingDate != null && _harvestDate != null)
          ? _harvestDate!.difference(_plantingDate!).inDays
          : 0;

  int get _totalWeeks => (_totalDays / 7).ceil().clamp(1, 52);

  int get _currentDayFromPlanting =>
      _plantingDate != null
          ? DateTime.now().difference(_plantingDate!).inDays.clamp(0, _totalDays)
          : 0;

  int get _currentWeekFromPlanting =>
      (_currentDayFromPlanting / 7).ceil().clamp(1, _totalWeeks);

  // Weekly state
  int _selectedWeek = 0;
  int _expandedStationIndex = -1;
  List<Map<String, dynamic>> _stationData = [];

  // Daily state — now derived from selected week
  int _dailySelectedDay = 0;
  List<Map<String, dynamic>> _dailyActiveTasks = [];
  List<Map<String, dynamic>> _dailyCompletedTasks = [];

  // Locking
  bool get _isCurrentDayLocked =>
      _dailySelectedDay > _currentDayFromPlanting;

  bool get _isCurrentWeekLocked =>
      _selectedWeek + 1 > _currentWeekFromPlanting;

  DateTime _getDayDate(int dayIndex) =>
      _plantingDate!.add(Duration(days: dayIndex));

  DateTime _getWeekStartDate(int weekIndex) =>
      _plantingDate!.add(Duration(days: weekIndex * 7));

  // Days within the selected week (0-indexed global day indices)
  List<int> get _daysInSelectedWeek {
    final start = _selectedWeek * 7;
    final end = (start + 7).clamp(0, _totalDays);
    return List.generate(end - start, (i) => start + i);
  }

  // Live totals
  int get _completedCount =>
      _stationData.where((s) => s['completed'] as bool? ?? false).length;

  int get _totalDamaged =>
      _stationData.fold(0, (sum, s) => sum + (s['damaged'] as int? ?? 0));

  int get _totalEggs =>
      _stationData.fold(0, (sum, s) => sum + (s['eggMasses'] as int? ?? 0));

  int get _totalLarvae =>
      _stationData.fold(0, (sum, s) => sum + (s['larvae'] as int? ?? 0));

  int get _totalPupae =>
      _stationData.fold(0, (sum, s) => sum + (s['pupae'] as int? ?? 0));

  // UI state
  bool _showControlModal = false;
  bool _showSuccessModal = false;

  List<Map<String, dynamic>> _getDefaultStations(int count) {
    return List.generate(count, (i) => {
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

  final Map<int, Map<int, String>> _recommendedTaskState = {};

  // ========================
  // RECOMMENDED TASKS PER WEEK (weeks 1–8)
  // Edit each week's list freely. Each task needs: title, description, icon, category.
  // ========================
  static const Map<int, List<Map<String, dynamic>>> _weeklyRecommendedTasks = {
    1: [
      {
        'title': 'Land Preparation (Araro)',
        'description': 'Plow the field using a tractor or carabao to loosen soil and bury crop residues.',
        'icon': Icons.agriculture,
        'category': 'Soil Prep',
      },
      {
        'title': 'Soil Solarization',
        'description': 'Cover moist soil with clear plastic to trap heat and kill weed seeds and pathogens.',
        'icon': Icons.wb_sunny_outlined,
        'category': 'Soil Prep',
      },
      {
        'title': 'Herbicide Spraying',
        'description': 'Apply pre-emergence herbicide evenly across the field to suppress early weed growth.',
        'icon': Icons.water_drop,
        'category': 'Weed Control',
      },
      {
        'title': 'Idasan (Residue Clearing)',
        'description': 'Remove leftover stems, roots, and crop debris from the previous harvest.',
        'icon': Icons.cleaning_services_outlined,
        'category': 'Field Cleanup',
      },
      {
        'title': 'Dry Direct Seeding / Irrigation',
        'description': 'Sow corn seeds directly if soil is dry. If no rain, irrigate before seeding (patubig).',
        'icon': Icons.grass,
        'category': 'Planting',
      },
    ],
    2: [
      {
        'title': 'Basal Fertilizer Application',
        'description': 'Apply complete fertilizer (14-14-14 or similar) at the base of each seedling row.',
        'icon': Icons.science_outlined,
        'category': 'Fertilization',
      },
      {
        'title': 'Seed Coverage Check',
        'description': 'Ensure seeds are properly covered with soil to encourage even germination.',
        'icon': Icons.check_circle_outline,
        'category': 'Planting',
      },
      {
        'title': 'Side Dressing',
        'description': 'Apply urea or nitrogen fertilizer along the sides of seedling rows.',
        'icon': Icons.line_axis_outlined,
        'category': 'Fertilization',
      },
      {
        'title': 'Early Pest Monitoring',
        'description': 'Scout for signs of early pest attacks — cutworms, aphids, or armyworm egg masses.',
        'icon': Icons.pest_control,
        'category': 'Monitoring',
      },
      {
        'title': 'Weed Re-inspection',
        'description': 'Check for weed regrowth between rows and spot-spray or manually remove as needed.',
        'icon': Icons.remove_circle_outline,
        'category': 'Weed Control',
      },
    ],
    3: [
      {
        'title': 'Second Side Dressing',
        'description': 'Apply another round of urea fertilizer to support vegetative growth.',
        'icon': Icons.science_outlined,
        'category': 'Fertilization',
      },
      {
        'title': 'Tudling (Hilling Up)',
        'description': 'Mound soil around the base of corn stalks to improve root anchorage and drainage.',
        'icon': Icons.terrain_outlined,
        'category': 'Cultivation',
      },
      {
        'title': 'FAW Trap Check',
        'description': 'Count and record moths caught in pheromone traps. Replace lure if count is high.',
        'icon': Icons.bug_report_outlined,
        'category': 'Pest Control',
      },
      {
        'title': 'Spray if Moths Observed',
        'description': 'If butterflies or moths are sighted in large numbers, apply recommended insecticide.',
        'icon': Icons.bug_report,
        'category': 'Pest Control',
      },
      {
        'title': 'Crop Stand Assessment',
        'description': 'Count plant population per meter row and note any gaps or stunted plants.',
        'icon': Icons.format_list_numbered,
        'category': 'Monitoring',
      },
    ],
    4: [
      {
        'title': 'Third Side Dressing',
        'description': 'Final fertilizer application before tasseling — use urea or potassium-rich mix.',
        'icon': Icons.science_outlined,
        'category': 'Fertilization',
      },
      {
        'title': 'Final Hilling Up (Tudling)',
        'description': 'Do the last round of hilling up to support stalks ahead of tasseling and silking.',
        'icon': Icons.terrain_outlined,
        'category': 'Cultivation',
      },
      {
        'title': 'Check for Stalk Borers',
        'description': 'Inspect base of stalks for entry holes or frass indicating stalk borer infestation.',
        'icon': Icons.search,
        'category': 'Pest Control',
      },
      {
        'title': 'Irrigation if Dry',
        'description': 'If no significant rainfall in the past week, irrigate to maintain soil moisture.',
        'icon': Icons.water_drop,
        'category': 'Irrigation',
      },
      {
        'title': 'Field Photo Documentation',
        'description': 'Take photos at 3 representative spots to document crop height and canopy coverage.',
        'icon': Icons.photo_camera_outlined,
        'category': 'Documentation',
      },
    ],
    5: [
      {
        'title': 'Tasseling Stage Monitoring',
        'description': 'Confirm that crops have entered tasseling. Note percentage of plants showing tassels.',
        'icon': Icons.eco,
        'category': 'Monitoring',
      },
      {
        'title': 'Pest Scouting — Silks & Ears',
        'description': 'Inspect silks and developing ears for FAW larvae, aphids, or thrips damage.',
        'icon': Icons.pest_control,
        'category': 'Pest Control',
      },
      {
        'title': 'Check for Foliar Disease',
        'description': 'Look for signs of northern leaf blight, rust, or gray leaf spot on lower leaves.',
        'icon': Icons.local_florist_outlined,
        'category': 'Disease Check',
      },
      {
        'title': 'Spray if Pest Threshold Met',
        'description': 'If pest damage exceeds economic threshold (>20% leaf damage), apply insecticide.',
        'icon': Icons.bug_report,
        'category': 'Pest Control',
      },
      {
        'title': 'Irrigation Check',
        'description': 'Tasseling is a critical moisture period — irrigate if soil is dry at 5cm depth.',
        'icon': Icons.water_drop,
        'category': 'Irrigation',
      },
    ],
    6: [
      {
        'title': 'Silking Stage Monitoring',
        'description': 'Check percentage of plants at silking stage. Note uniformity across the field.',
        'icon': Icons.monitor_heart_outlined,
        'category': 'Monitoring',
      },
      {
        'title': 'Ear Development Check',
        'description': 'Inspect developing ears for proper husk coverage and early signs of rot or damage.',
        'icon': Icons.search,
        'category': 'Monitoring',
      },
      {
        'title': 'FAW Late-Stage Scouting',
        'description': 'Continue FAW scouting in ears and husks — larvae may be feeding inside ear tip.',
        'icon': Icons.bug_report_outlined,
        'category': 'Pest Control',
      },
      {
        'title': 'Weed Final Check',
        'description': 'Remove any remaining weeds before canopy fully closes to prevent seed set.',
        'icon': Icons.remove_circle_outline,
        'category': 'Weed Control',
      },
      {
        'title': 'Record Crop Status',
        'description': 'Log crop height, canopy color, and any abnormalities observed across all zones.',
        'icon': Icons.note_alt_outlined,
        'category': 'Documentation',
      },
    ],
    7: [
      {
        'title': 'Grain Fill Monitoring',
        'description': 'Check ears for grain fill progress — feel husks for kernel development firmness.',
        'icon': Icons.monitor_heart_outlined,
        'category': 'Monitoring',
      },
      {
        'title': 'Check for Ear Rots',
        'description': 'Peel back husks on sample ears to inspect for mold, discoloration, or fungal growth.',
        'icon': Icons.warning_amber_outlined,
        'category': 'Disease Check',
      },
      {
        'title': 'Bird and Rat Damage Check',
        'description': 'Inspect field perimeter and ears for bird peck marks or rodent damage signs.',
        'icon': Icons.pest_control_rodent_outlined,
        'category': 'Pest Control',
      },
      {
        'title': 'Harvest Readiness Planning',
        'description': 'Estimate days to harvest. Arrange for labor, equipment, and storage in advance.',
        'icon': Icons.calendar_month_outlined,
        'category': 'Planning',
      },
      {
        'title': 'Final Field Documentation',
        'description': 'Take photos and note estimated yield per plot in preparation for harvest report.',
        'icon': Icons.photo_camera_outlined,
        'category': 'Documentation',
      },
    ],
    8: [
      {
        'title': 'Check Harvest Maturity',
        'description': 'Confirm black layer formation at kernel tip and husk dryness — signs of maturity.',
        'icon': Icons.check_circle_outline,
        'category': 'Harvest',
      },
      {
        'title': 'Moisture Check',
        'description': 'Use a moisture meter to confirm grain moisture is at or below 25% before harvest.',
        'icon': Icons.water_drop,
        'category': 'Harvest',
      },
      {
        'title': 'Harvest Operations',
        'description': 'Begin mechanical or manual harvest. Ensure proper handling to minimize grain loss.',
        'icon': Icons.agriculture,
        'category': 'Harvest',
      },
      {
        'title': 'Post-Harvest Field Clearing',
        'description': 'Remove stalks and leftover crop material from the field after harvest is complete.',
        'icon': Icons.cleaning_services_outlined,
        'category': 'Post-Harvest',
      },
      {
        'title': 'Yield Recording',
        'description': 'Weigh and record total yield per plot. Compare against target and prior cycle.',
        'icon': Icons.bar_chart,
        'category': 'Documentation',
      },
    ],
  };

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  // ========================
  // DATA LOADING
  // ========================
  Future<void> _loadCycleData() async {
    try {
      final cycle = await _firestoreService.getCycle(widget.cycleId);
      if (cycle == null) {
        setState(() {
          _error = 'Cycle not found';
          _isInitialLoading = false;
        });
        return;
      }

      debugPrint('Cycle data: $cycle');
      debugPrint('plantingData: ${cycle['plantingDate']}');
      debugPrint('harvestData: ${cycle['harvestDate']}');

      final planting = (cycle['plantingDate'] as Timestamp?)?.toDate();
      final harvest = (cycle['harvestDate'] as Timestamp?)?.toDate();

      debugPrint('Parsed planting: $planting');
      debugPrint('Parsed harvest: $harvest');

      if (planting == null || harvest == null) {
        setState(() {
          _error = 'Invalid cycle dates: planting=$planting, harvest=$harvest';
          _isInitialLoading = false;
        });
        return;
      }

      // Validate that harvest is after planting
      if (harvest.isBefore(planting) || harvest.isAtSameMomentAs(planting)) {
        setState(() {
          _error = 'Harvest date must be after planting date';
          _isInitialLoading = false;
        });
        return;
      }

      setState(() {
        _plantingDate = planting;
        _harvestDate = harvest;
        _cycleName = cycle['cycleName'] ?? 'Unknown Cycle';
        _fieldName = cycle['fieldName'] ?? 'Unknown Field';
        debugPrint('Total days: $_totalDays, Total weeks: $_totalWeeks');
        debugPrint('Current day: $_currentDayFromPlanting, Current week: $_currentWeekFromPlanting');
        _selectedWeek = (_currentWeekFromPlanting - 1).clamp(0, _totalWeeks - 1);
        _dailySelectedDay = _currentDayFromPlanting.clamp(
          _selectedWeek * 7,
          ((_selectedWeek * 7 + 6).clamp(0, _totalDays - 1)),
        );
      });

      await _loadWeekData(_selectedWeek);
      await _loadDailyLogData(_dailySelectedDay);
    } catch (e) {
      debugPrint('Error loading cycle data: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      setState(() {
        _error = 'Failed to load cycle data: $e';
      });
    } finally {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadWeekData(int weekIndex) async {
    if (weekIndex < 0 || weekIndex >= _totalWeeks) return;
    setState(() => _isWeekLoading = true);

    try {
      final weekId = 'week_${weekIndex + 1}';
      final weekData = await _firestoreService.getWeek(widget.cycleId, weekId);

      if (weekData != null && weekData['stations'] != null) {
        final stations = List<Map<String, dynamic>>.from(
            (weekData['stations'] as List)
                .map((s) => Map<String, dynamic>.from(s)));
        setState(() {
          _stationData = stations;
          _expandedStationIndex = -1;
        });
      } else {
        setState(() {
          _stationData = _getDefaultStations(5);
          _expandedStationIndex = -1;
        });
      }
    } catch (e) {
      setState(() {
        _stationData = _getDefaultStations(5);
        _expandedStationIndex = -1;
      });
    } finally {
      setState(() => _isWeekLoading = false);
    }
  }

  Future<void> _loadDailyLogData(int dayIndex) async {
    if (dayIndex < 0 || dayIndex >= _totalDays) return;
    try {
      final dayId = 'day_${(dayIndex + 1).toString().padLeft(2, '0')}';

      final activitiesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .collection('dailyLogs')
          .doc(dayId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .get();

      final activities = activitiesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['type'] ?? 'Activity',
          'subtitle': data['notes'] ?? 'No notes',
          'images': List<String>.from(data['images'] as List? ?? []),
          'completed': data['completed'] as bool? ?? false,
          'timestamp': data['timestamp'],
        };
      }).toList();

      setState(() {
        _dailyActiveTasks =
            activities.where((a) => !(a['completed'] as bool)).toList();
        _dailyCompletedTasks =
            activities.where((a) => a['completed'] as bool).toList();
      });
    } catch (e) {
      debugPrint('Error loading daily log: $e');
      setState(() {
        _dailyActiveTasks = [];
        _dailyCompletedTasks = [];
      });
    }
  }

  // ========================
  // STATE MUTATIONS
  // ========================
  void _toggleStation(int index) {
    setState(() {
      _expandedStationIndex =
          _expandedStationIndex == index ? -1 : index;
    });
  }

  void _increment(int index, String key) {
    if (_isCurrentWeekLocked) return;
    setState(() {
      _stationData[index][key] = (_stationData[index][key] as int) + 1;
      if (key == 'damaged' && _stationData[index][key] > 0) {
        _stationData[index]['fawObserved'] = true;
      }
    });
    _scheduleAutoSave();
  }

  void _decrement(int index, String key) {
    if (_isCurrentWeekLocked) return;
    if (_stationData[index][key] as int <= 0) return;
    setState(() {
      _stationData[index][key] = (_stationData[index][key] as int) - 1;
      if (key == 'damaged' && _stationData[index][key] == 0) {
        final hasOtherSigns =
            (_stationData[index]['eggMasses'] as int) > 0 ||
                (_stationData[index]['larvae'] as int) > 0 ||
                (_stationData[index]['pupae'] as int) > 0;
        if (!hasOtherSigns) _stationData[index]['fawObserved'] = false;
      }
    });
    _scheduleAutoSave();
  }

  void _completeStation(int index) {
    if (_isCurrentWeekLocked) return;
    setState(() {
      _stationData[index]['completed'] = true;
      _expandedStationIndex = -1;
    });
    _scheduleAutoSave();
  }

  void _updateNotes(int index, String value) {
    if (_isCurrentWeekLocked) return;
    setState(() {
      _stationData[index]['notes'] = value;
    });
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      _saveCurrentWeekData(silent: true);
    });
  }

  Future<void> _saveCurrentWeekData({bool silent = false}) async {
    final weekId = 'week_${_selectedWeek + 1}';
    final data = {
      'stations': _stationData,
      'totals': {
        'damaged': _totalDamaged,
        'eggs': _totalEggs,
        'larvae': _totalLarvae,
        'pupae': _totalPupae,
      },
      'timestamp': FieldValue.serverTimestamp(),
      'completedStations': _completedCount,
    };
    try {
      await _firestoreService.saveWeek(widget.cycleId, weekId, data);
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-save failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleTaskCompletion(
      Map<String, dynamic> task, bool isCurrentlyCompleted) async {
    try {
      final dayId = 'day_${(_dailySelectedDay + 1).toString().padLeft(2, '0')}';
      final taskId = task['id'];

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .collection('dailyLogs')
          .doc(dayId)
          .collection('activities')
          .doc(taskId)
          .update({
        'completed': !isCurrentlyCompleted,
        'completedAt': FieldValue.serverTimestamp(),
      });

      await _loadDailyLogData(_dailySelectedDay);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!isCurrentlyCompleted
                ? 'Task marked as completed'
                : 'Task marked as active'),
            backgroundColor: kActionGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling task completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update task status')),
        );
      }
    }
  }

  // ========================
  // BUILD
  // ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFA),
      body: Stack(
        children: [
          SafeArea(
            child: _isInitialLoading
                ? const Center(
                    child: CircularProgressIndicator(color: kActionGreen))
                : _error != null
                    ? _buildErrorState()
                    : Column(
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 12),
                          _buildControlMethodsCard(),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: (_showControlModal || _showSuccessModal)
                                  ? const NeverScrollableScrollPhysics()
                                  : const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildWeeklyContent(),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
          if (_showControlModal) _buildControlMethodModal(),
          if (_showSuccessModal)
            SuccessModal(
              title: 'Scouting Saved',
              subtitle:
                  'Week ${_selectedWeek + 1} report has been saved successfully.',
              buttonText: 'Back to Monitoring',
              onClose: () => setState(() => _showSuccessModal = false),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: kTextGrey),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                style: GoogleFonts.inter(fontSize: 16, color: kTextGrey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _isInitialLoading = true;
                });
                _loadCycleData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: kActionGreen),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ========================
  // HEADER
  // ========================
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.arrow_back, color: kTextDark),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Monitoring',
                    style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kActionGreen)),
                Text('$_cycleName • $_fieldName',
                    style: GoogleFonts.inter(fontSize: 12, color: kTextGrey)),
              ],
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  // ========================
  // CONTROL METHODS CARD
  // ========================
  Widget _buildControlMethodsCard() {
    return GestureDetector(
      onTap: () => setState(() => _showControlModal = true),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Container(
                width: 4,
                height: 40,
                decoration: const BoxDecoration(
                    color: kActionGreen,
                    borderRadius: BorderRadius.all(Radius.circular(2)))),
            const SizedBox(width: 12),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child:
                    const Icon(Icons.bug_report, color: kActionGreen, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Control Methods',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  RichText(
                    text: TextSpan(
                      style:
                          GoogleFonts.inter(fontSize: 11, color: kTextGrey),
                      children: const [
                        TextSpan(text: 'Track potential outbreaks. '),
                        TextSpan(
                            text: 'Know more?',
                            style: TextStyle(
                                color: Color.fromARGB(255, 120, 168, 64),
                                decoration: TextDecoration.underline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_circle_right_outlined,
                color: kTextGrey, size: 22),
          ],
        ),
      ),
    );
  }

  // ========================
  // WEEKLY CONTENT (main body — no tabs)
  // ========================
  Widget _buildWeeklyContent() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWeekSelector(),
            _buildScoutingProgress(),
            if (_isCurrentWeekLocked) _buildLockedBanner('week'),
            _buildInspectionPoints(),
            _buildTotalFindings(),
            const SizedBox(height: 24),
            // ---- Daily Activity Log inline, scoped to this week ----
            _buildDailyActivitySection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
        if (_isWeekLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child:
                    CircularProgressIndicator(color: kActionGreen, strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  // ========================
  // WEEK SELECTOR
  // ========================
  Widget _buildWeekSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('No. of Weeks',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: List.generate(_totalWeeks, (index) {
              bool isSelected = index == _selectedWeek;
              bool isLocked = index + 1 > _currentWeekFromPlanting;
              return GestureDetector(
                onTap: () async {
                  // When switching weeks, default day to first unlocked day in that week
                  final weekFirstDay = index * 7;
                  final weekLastDay =
                      (weekFirstDay + 6).clamp(0, _totalDays - 1);
                  final defaultDay =
                      _currentDayFromPlanting.clamp(weekFirstDay, weekLastDay);
                  setState(() {
                    _selectedWeek = index;
                    _dailySelectedDay = defaultDay;
                  });
                  await Future.wait([
                    _loadWeekData(index),
                    _loadDailyLogData(defaultDay),
                  ]);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kActionGreen
                        : const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Week',
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  color: isSelected
                                      ? Colors.white70
                                      : kTextGrey)),
                          Text('${index + 1}',
                              style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : kTextDark)),
                        ],
                      ),
                      if (isLocked && !isSelected)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Icon(Icons.lock,
                              size: 10,
                              color: kTextGrey.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Field Scouting',
                  style: TextStyle(
                      color: kActionGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 4),
              Container(width: 90, height: 2, color: kActionGreen),
            ],
          ),
        )
      ],
    );
  }

  // ========================
  // SCOUTING PROGRESS
  // ========================
  Widget _buildScoutingProgress() {
    final progress =
        _stationData.isEmpty ? 0.0 : _completedCount / _stationData.length;
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scouting Progress',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              Text(
                  '$_completedCount of ${_stationData.length} stations completed',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: kActionGreen,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE0E0E0),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(kActionGreen),
                minHeight: 6),
          ),
        ],
      ),
    );
  }

  // ========================
  // LOCKED BANNER
  // ========================
  Widget _buildLockedBanner(String type) {
    final unlockDate = type == 'week'
        ? _getWeekStartDate(_selectedWeek)
        : _getDayDate(_dailySelectedDay);
    final formattedDate = DateFormat('MMM d').format(unlockDate);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 18, color: Color(0xFFFFA000)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Locked until $formattedDate',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF795548),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // INSPECTION POINTS
  // ========================
  Widget _buildInspectionPoints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inspection Points',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 18)),
          RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 12, color: kTextGrey),
              children: const [
                TextSpan(
                    text:
                        'Inspect 10 plants per point and record FAW signs\n'),
                TextSpan(
                    text: 'More info about field scouting? ',
                    style: TextStyle(
                        color: Color.fromARGB(255, 76, 114, 33))),
                TextSpan(
                    text: 'Click here.',
                    style: TextStyle(
                        color: Color.fromARGB(255, 76, 114, 33),
                        decoration: TextDecoration.underline,
                        fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_stationData.length, (index) {
            final station = _stationData[index];
            return _buildExpandableStationTile(
              index: index,
              title: station['title'],
              isExpanded: _expandedStationIndex == index,
              data: station,
              stationNumber: '${index + 1}',
              isLocked: _isCurrentWeekLocked,
            );
          }),
        ],
      ),
    );
  }

  // ========================
  // TOTAL FINDINGS
  // ========================
  Widget _buildTotalFindings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kBorderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Findings',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildAnimatedFindingTile(
                      'DAMAGED', _totalDamaged, kTextDark)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildAnimatedFindingTile(
                      'EGGS', _totalEggs, kTextDark)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildAnimatedFindingTile(
                      'LARVAE', _totalLarvae, kAccentRed)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildAnimatedFindingTile(
                      'PUPAE', _totalPupae, kTextDark)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedFindingTile(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorderColor.withValues(alpha: 0.5))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9,
                    color: kTextGrey,
                    fontWeight: FontWeight.bold)),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Text('$count',
                  key: ValueKey<int>(count),
                  style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ]),
    );
  }

  // ========================
  // RECOMMENDED TASKS SECTION
  // ========================
  Widget _buildRecommendedTasksSection() {
    // Only show for weeks 1–8
    final weekNumber = _selectedWeek + 1;
    if (weekNumber > 8) return const SizedBox.shrink();

    final tasks = _weeklyRecommendedTasks[weekNumber] ?? [];
    final stateMap = _recommendedTaskState[_selectedWeek] ?? {};

    // Separate into active and completed (not deleted)
    final activeTasks = <MapEntry<int, Map<String, dynamic>>>[];
    final completedTasks = <MapEntry<int, Map<String, dynamic>>>[];

    for (int i = 0; i < tasks.length; i++) {
      final status = stateMap[i];
      if (status == 'deleted') continue;
      if (status == 'completed') {
        completedTasks.add(MapEntry(i, tasks[i]));
      } else {
        activeTasks.add(MapEntry(i, tasks[i]));
      }
    }

    final visibleCount = activeTasks.length + completedTasks.length;
    if (visibleCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A825),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Recommended for Week $weekNumber',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: kTextDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${completedTasks.length}/${visibleCount}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFF57F17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'System recommendations — mark done or remove as needed',
            style: GoogleFonts.inter(fontSize: 12, color: kTextGrey),
          ),
        ),
        const SizedBox(height: 12),

        // Active recommended tasks
        if (activeTasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: activeTasks.map((entry) {
                return _buildRecommendedTaskCard(
                  taskIndex: entry.key,
                  task: entry.value,
                  isCompleted: false,
                );
              }).toList(),
            ),
          ),

        // Completed recommended tasks (collapsible feel — shown below)
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: completedTasks.map((entry) {
                return _buildRecommendedTaskCard(
                  taskIndex: entry.key,
                  task: entry.value,
                  isCompleted: true,
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRecommendedTaskCard({
    required int taskIndex,
    required Map<String, dynamic> task,
    required bool isCompleted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFF9FDF9)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFFF9C4),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFFDE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              task['icon'] as IconData,
              color: isCompleted
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFF9A825),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task['title'] as String,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isCompleted
                              ? kTextDark.withValues(alpha: 0.5)
                              : kTextDark,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFE8F5E9)
                            : kLightGreenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task['category'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: isCompleted
                              ? const Color(0xFF2E7D32).withValues(alpha: 0.6)
                              : kActionGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isCompleted) ...[
                  const SizedBox(height: 4),
                  Text(
                    task['description'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: kTextGrey,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Action buttons
                Row(
                  children: [
                    // Mark complete / Undo button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _recommendedTaskState[_selectedWeek] ??= {};
                          _recommendedTaskState[_selectedWeek]![taskIndex] =
                              isCompleted ? 'active' : 'completed';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.grey.shade200
                              : kActionGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? Icons.refresh
                                  : Icons.check_circle_outline,
                              color: isCompleted ? kTextGrey : Colors.white,
                              size: 13,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isCompleted ? 'Undo' : 'Mark Done',
                              style: GoogleFonts.inter(
                                color: isCompleted ? kTextGrey : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Delete button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _recommendedTaskState[_selectedWeek] ??= {};
                          _recommendedTaskState[_selectedWeek]![taskIndex] =
                              'deleted';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline,
                                color: kAccentRed, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'Remove',
                              style: GoogleFonts.inter(
                                color: kAccentRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // DAILY ACTIVITY SECTION (integrated within weekly view)
  // ========================
  Widget _buildDailyActivitySection() {
    final weekDays = _daysInSelectedWeek;
    if (weekDays.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section divider with label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: kActionGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Daily Activity Log',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: kTextDark),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kLightGreenBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Week ${_selectedWeek + 1}',
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: kActionGreen,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Track your field activities day by day',
            style: GoogleFonts.inter(fontSize: 12, color: kTextGrey),
          ),
        ),
        const SizedBox(height: 16),

        // Day selector — scoped to days within this week
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: weekDays.map((globalDayIndex) {
              final isSelected = globalDayIndex == _dailySelectedDay;
              final isLocked = globalDayIndex > _currentDayFromPlanting;
              final dayNumber = globalDayIndex + 1; // 1-based
              final dayDate = _getDayDate(globalDayIndex);
              final dayLabel = DateFormat('EEE').format(dayDate); // e.g. Mon

              return GestureDetector(
                onTap: () async {
                  setState(() => _dailySelectedDay = globalDayIndex);
                  await _loadDailyLogData(globalDayIndex);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 62,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kActionGreen
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: kBorderColor.withValues(alpha: 0.5)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dayLabel,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white70
                                    : kTextGrey,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Day $dayNumber',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : kTextDark),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('d MMM').format(dayDate),
                            style: GoogleFonts.inter(
                                fontSize: 9,
                                color: isSelected
                                    ? Colors.white60
                                    : kTextGrey),
                          ),
                        ],
                      ),
                      if (isLocked && !isSelected)
                        Positioned(
                          top: 4,
                          right: 6,
                          child: Icon(Icons.lock,
                              size: 10,
                              color: kTextGrey.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),
        if (_isCurrentDayLocked)
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
            child: _buildLockedBanner('day'),
          ),

        // Selected day info bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kLightGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: kActionGreen),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMM d yyyy')
                      .format(_getDayDate(_dailySelectedDay)),
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kActionGreen,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_dailyActiveTasks.length + _dailyCompletedTasks.length} activit${(_dailyActiveTasks.length + _dailyCompletedTasks.length) == 1 ? 'y' : 'ies'}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: kTextGrey),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        _buildRecommendedTasksSection(),
        const SizedBox(height: 16),

        // Active tasks
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Active Tasks',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 8),
              if (_dailyActiveTasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kActiveTaskBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_dailyActiveTasks.length}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: kActiveTaskBlue,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _dailyActiveTasks.isEmpty
              ? _buildEmptyTaskState('No active tasks for this day')
              : Column(
                  children: _dailyActiveTasks.map((task) {
                    final images =
                        task['images'] as List<String>? ?? [];
                    return _buildActiveTaskTile(
                      task: task,
                      title: task['title'] ?? '',
                      subtitle: task['subtitle'] ?? '',
                      images: images,
                      isLocked: _isCurrentDayLocked,
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 24),

        // Completed tasks
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text('Completed Tasks',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 8),
              if (_dailyCompletedTasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${_dailyCompletedTasks.length}',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: kActionGreen,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _dailyCompletedTasks.isEmpty
              ? _buildEmptyTaskState(
                  'No completed tasks for this day')
              : Column(
                  children: _dailyCompletedTasks.map((task) {
                    return _buildCompletedTaskTile(
                      task: task,
                      title: task['title'] ?? '',
                      subtitle: task['subtitle'] ?? '',
                    );
                  }).toList(),
                ),
        ),

        const SizedBox(height: 24),

        // Add Activity button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AbsorbPointer(
            absorbing: _isCurrentDayLocked,
            child: Opacity(
              opacity: _isCurrentDayLocked ? 0.4 : 1.0,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DailyLogFormScreen(
                          userId: _userId,
                          cycleId: widget.cycleId,
                          shouldAssignCycle: false,
                        ),
                      ),
                    ).then((_) => _loadDailyLogData(_dailySelectedDay));
                  },
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: kLightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.add, size: 18, color: kActionGreen),
                  ),
                  label: Text('Add Activity',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: kActionGreen)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: kActionGreen.withValues(alpha: 0.3),
                        width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTaskState(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(message,
            style: GoogleFonts.inter(fontSize: 13, color: kTextGrey)),
      ),
    );
  }

  // ========================
  // TASK TILES
  // ========================
  Widget _buildActiveTaskTile({
    required Map<String, dynamic> task,
    required String title,
    required String subtitle,
    List<String> images = const [],
    bool isLocked = false,
  }) {
    return AbsorbPointer(
      absorbing: isLocked,
      child: Opacity(
        opacity: isLocked ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: kActiveTaskBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBDEFB), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (images.isNotEmpty)
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF90CAF9), width: 1),
                    image: DecorationImage(
                      image: NetworkImage(images.first),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFE3F2FD),
                  ),
                  child: const Icon(Icons.image_not_supported,
                      color: Color(0xFF90CAF9)),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 12, right: 12, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1565C0))),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF0D47A1))),
                      if (images.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${images.length - 1} more image${images.length > 2 ? 's' : ''}',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF42A5F5),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _toggleTaskCompletion(task, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: kActionGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text('Mark Complete',
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedTaskTile({
    required Map<String, dynamic> task,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FDF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFE8F5E9).withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle,
                color: Color.fromARGB(255, 46, 125, 50), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: kTextDark.withValues(alpha: 0.7))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: kTextGrey.withValues(alpha: 0.7))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleTaskCompletion(task, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: kTextGrey),
                  const SizedBox(width: 4),
                  Text('Undo',
                      style: GoogleFonts.inter(
                          color: kTextGrey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right,
              color: Color(0xFFBDBDBD), size: 20),
        ],
      ),
    );
  }

  // ========================
  // EXPANDABLE STATION TILE
  // ========================
  Widget _buildExpandableStationTile({
    required int index,
    required String title,
    required bool isExpanded,
    required Map<String, dynamic> data,
    required String stationNumber,
    bool isLocked = false,
  }) {
    final isCompleted = data['completed'] as bool? ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: isExpanded
          ? const EdgeInsets.all(20)
          : const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isExpanded ? 20 : 16),
        border: Border.all(
          color: isExpanded
              ? kActionGreen
              : kBorderColor.withValues(alpha: 0.6),
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _toggleStation(index),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                    radius: 14,
                    backgroundColor: isCompleted
                        ? const Color.fromARGB(255, 155, 228, 61)
                        : (isExpanded
                            ? kPrimaryGreen
                            : const Color(0xFFE0E0E0)),
                    child: isCompleted
                        ? const Icon(Icons.check,
                            size: 14,
                            color: Color.fromARGB(255, 23, 94, 27))
                        : Text(stationNumber,
                            style: TextStyle(
                                color: isExpanded
                                    ? Colors.white
                                    : kTextGrey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: GoogleFonts.inter(
                          fontWeight: isExpanded
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: isExpanded ? 15 : 14)),
                ),
                if (isCompleted)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('COMPLETED',
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(
                                  255, 49, 114, 51)))),
                if (isCompleted) const SizedBox(width: 8),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: isExpanded ? 0.5 : 0.0,
                  child:
                      const Icon(Icons.keyboard_arrow_down, color: kTextGrey),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild:
                const SizedBox(width: double.infinity, height: 0),
            secondChild: AbsorbPointer(
              absorbing: isLocked,
              child: Opacity(
                opacity: isLocked ? 0.45 : 1.0,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCounterBox(
                            label: 'PLANTS INSPECTED',
                            value: data['plantsInspected'] as int? ?? 0,
                            onDecrement: () =>
                                _decrement(index, 'plantsInspected'),
                            onIncrement: () =>
                                _increment(index, 'plantsInspected'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCounterBox(
                            label: 'DAMAGED',
                            value: data['damaged'] as int? ?? 0,
                            onDecrement: () =>
                                _decrement(index, 'damaged'),
                            onIncrement: () =>
                                _increment(index, 'damaged'),
                            valueColor:
                                (data['damaged'] as int? ?? 0) > 0
                                    ? kAccentRed
                                    : kTextDark,
                          ),
                        ),
                      ],
                    ),
                    if (data['fawObserved'] as bool? ?? false) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                    color: kAccentRed,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.check,
                                    color: Colors.white, size: 10)),
                            const SizedBox(width: 8),
                            Text('FAW damage observed',
                                style: GoogleFonts.inter(
                                    color: kAccentRed,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13))
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSmallCounter(
                          label: 'EGG MASSES',
                          value: data['eggMasses'] as int? ?? 0,
                          valueColor:
                              (data['eggMasses'] as int? ?? 0) > 0
                                  ? kAccentRed
                                  : kTextDark,
                          onDecrement: () =>
                              _decrement(index, 'eggMasses'),
                          onIncrement: () =>
                              _increment(index, 'eggMasses'),
                        ),
                        _buildSmallCounter(
                          label: 'LARVAE',
                          value: data['larvae'] as int? ?? 0,
                          valueColor:
                              (data['larvae'] as int? ?? 0) > 0
                                  ? kAccentRed
                                  : kTextDark,
                          onDecrement: () =>
                              _decrement(index, 'larvae'),
                          onIncrement: () =>
                              _increment(index, 'larvae'),
                        ),
                        _buildSmallCounter(
                          label: 'PUPAE',
                          value: data['pupae'] as int? ?? 0,
                          valueColor:
                              (data['pupae'] as int? ?? 0) > 0
                                  ? kAccentRed
                                  : kTextDark,
                          onDecrement: () =>
                              _decrement(index, 'pupae'),
                          onIncrement: () =>
                              _increment(index, 'pupae'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildEditableNotesBox(
                      notes: data['notes'] as String? ?? '',
                      onChanged: (val) => _updateNotes(index, val),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isLocked ? null : () {},
                      icon: const Icon(Icons.photo_camera_outlined,
                          size: 18),
                      label: const Text('Upload Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isLocked ? kTextGrey : kTextDark,
                        minimumSize:
                            const Size(double.infinity, 50),
                        side: BorderSide(
                            color: isLocked
                                ? kBorderColor
                                : kBorderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(25)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLocked
                            ? null
                            : () => _completeStation(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted
                              ? Colors.white
                              : kActionGreen,
                          disabledBackgroundColor:
                              const Color(0xFFE0E0E0),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(26),
                              side: isCompleted
                                  ? const BorderSide(
                                      color: kActionGreen)
                                  : BorderSide.none),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                                isCompleted
                                    ? Icons.update_outlined
                                    : Icons.check_circle_outline,
                                color: isLocked
                                    ? kTextGrey
                                    : (isCompleted
                                        ? kActionGreen
                                        : Colors.white),
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isCompleted
                                  ? 'Update Station'
                                  : 'Complete Station',
                              style: GoogleFonts.inter(
                                color: isLocked
                                    ? kTextGrey
                                    : (isCompleted
                                        ? kActionGreen
                                        : Colors.white),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  // ========================
  // SAVE BUTTON
  // ========================
  Widget _buildSaveButton() {
    if (_isCurrentWeekLocked) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_outlined, color: kActionGreen, size: 16),
            const SizedBox(width: 6),
            Text(
              'Auto-saving...',
              style: GoogleFonts.inter(
                color: kTextGrey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================
  // REUSABLE INPUT COMPONENTS
  // ========================
  Widget _buildCounterBox({
    required String label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    Color? valueColor,
  }) {
    final color = valueColor ?? kTextDark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 9,
                  color: kTextGrey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1))
                      ]),
                  child:
                      const Icon(Icons.remove, size: 14, color: kTextDark),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text('$value',
                    key: ValueKey<int>(value),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: color)),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1))
                      ]),
                  child: const Icon(Icons.add, size: 14, color: kTextDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCounter({
    required String label,
    required int value,
    required Color valueColor,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(25)),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 8,
                  color: kTextGrey,
                  fontWeight: FontWeight.bold)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 3)
                      ]),
                  child:
                      const Icon(Icons.remove, size: 12, color: kTextDark),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text('$value',
                    key: ValueKey<int>(value),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold, color: valueColor)),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 3)
                      ]),
                  child: const Icon(Icons.add, size: 12, color: kTextDark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableNotesBox({
    required String notes,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NOTES',
              style: GoogleFonts.inter(
                  fontSize: 9,
                  color: kTextGrey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey<String>(notes),
            initialValue: notes,
            onChanged: onChanged,
            style: GoogleFonts.inter(fontSize: 13, color: kTextDark),
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Tap to add notes...',
              hintStyle: TextStyle(
                  color: Color(0xFF999999),
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // MODALS
  // ========================
  Widget _buildControlMethodModal() {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: const Color(0xFFF4F7F4),
            borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose Your Control Method',
                style:
                    GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Explore detailed steps for each management strategy based on environmental impact.',
                style: GoogleFonts.inter(fontSize: 14, color: kTextGrey)),
            const SizedBox(height: 24),
            _modalOption(
                Icons.bug_report,
                'Biological Control',
                'Utilize natural predators and parasitoids to manage pests with zero chemical footprint.',
                true),
            const SizedBox(height: 16),
            _modalOption(
                Icons.science_outlined,
                'Chemical Control',
                'Targeted synthetic applications. Recommended only as a last resort for acute infestations.',
                false),
            const SizedBox(height: 32),
            Center(
              child: InkWell(
                onTap: () => setState(() => _showControlModal = false),
                child: const Text(
                    'Continue with physical control? Back to monitoring',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: kTextGrey,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalOption(
      IconData icon, String title, String desc, bool rec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                  backgroundColor: kLightGreenBg,
                  radius: 18,
                  child: Icon(icon, color: kActionGreen, size: 20)),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (rec)
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: kActionGreen,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('RECOMMENDED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)))
            ]),
            const SizedBox(height: 8),
            Text(desc,
                style: GoogleFonts.inter(fontSize: 12, color: kTextGrey)),
          ]),
    );
  }
}