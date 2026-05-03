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
// PIXEL-PERFECT BRAND COLORS
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

  // Tab state
  int _selectedTab = 1;

  // Daily state
  int _dailySelectedDay = 0;
  List<Map<String, dynamic>> _dailyActiveTasks = [];
  List<Map<String, dynamic>> _dailyCompletedTasks = [];

  // Weekly state
  int _selectedWeek = 0;
  int _expandedStationIndex = -1;
  List<Map<String, dynamic>> _stationData = [];

  // Locking
  bool get _isCurrentDayLocked =>
      _dailySelectedDay > _currentDayFromPlanting;

  bool get _isCurrentWeekLocked =>
      _selectedWeek + 1 > _currentWeekFromPlanting;

  DateTime _getDayDate(int dayIndex) =>
      _plantingDate!.add(Duration(days: dayIndex));

  DateTime _getWeekStartDate(int weekIndex) =>
      _plantingDate!.add(Duration(days: weekIndex * 7));

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
      final cycle =
          await _firestoreService.getCycle(widget.cycleId);
      if (cycle == null) {
        setState(() {
          _error = 'Cycle not found';
          _isInitialLoading = false;
        });
        return;
      }

      final planting =
          (cycle['plantingDate'] as Timestamp?)?.toDate();
      final harvest =
          (cycle['harvestDate'] as Timestamp?)?.toDate();

      if (planting == null || harvest == null) {
        setState(() {
          _error = 'Invalid cycle dates';
          _isInitialLoading = false;
        });
        return;
      }

      setState(() {
        _plantingDate = planting;
        _harvestDate = harvest;
        _cycleName = cycle['cycleName'] ?? 'Unknown Cycle';
        _fieldName = cycle['fieldName'] ?? 'Unknown Field';
        _selectedWeek = (_currentWeekFromPlanting - 1).clamp(0, _totalWeeks - 1);
        _dailySelectedDay = _currentDayFromPlanting.clamp(0, _totalDays - 1);
      });

      await _loadWeekData(_selectedWeek);
      await _loadDailyLogData(_dailySelectedDay);
    } catch (e) {
      setState(() {
        _error = 'Failed to load cycle data';
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
      final weekData =
          await _firestoreService.getWeek(widget.cycleId, weekId);

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
      final dayId = 'day_${(_dailySelectedDay + 1).toString().padLeft(2, '0')}';
      
      // Fetch activities from the activities subcollection
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
      _stationData[index][key] =
          (_stationData[index][key] as int) + 1;
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
      _stationData[index][key] =
          (_stationData[index][key] as int) - 1;
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

  Future<void> _toggleTaskCompletion(Map<String, dynamic> task, bool isCurrentlyCompleted) async {
    try {
      final dayId = 'day_${(_dailySelectedDay + 1).toString().padLeft(2, '0')}';
      final taskId = task['id'];
      
      // Update the completion status in Firestore
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
      
      // Reload the daily log data to reflect changes
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
                          // HEADER - stays fixed at top
                          _buildHeader(),
                          const SizedBox(height: 16),
                          _buildControlMethodsCard(),
                          const SizedBox(height: 24),
                          // SCROLLABLE CONTENT - everything below tabs
                          Expanded(
                            child: SingleChildScrollView(
                              physics: (_showControlModal || _showSuccessModal)
                                  ? const NeverScrollableScrollPhysics()
                                  : const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildActivityTabs(),
                                  if (_selectedTab == 0)
                                    _buildDailyActivityLog()
                                  else
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
              subtitle: 'Week ${_selectedWeek + 1} report has been saved successfully.',
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
            const Icon(Icons.error_outline,
                size: 48, color: kTextGrey),
            const SizedBox(height: 16),
            Text(_error ?? 'Something went wrong',
                style: GoogleFonts.inter(
                    fontSize: 16, color: kTextGrey),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: kActionGreen),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

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
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
        if (_isWeekLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: CircularProgressIndicator(
                    color: kActionGreen, strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLockedBanner(String type) {
    final unlockDate = type == 'week'
        ? _getWeekStartDate(_selectedWeek)
        : _getDayDate(_dailySelectedDay);
    final formattedDate = DateFormat('MMM d').format(unlockDate);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline,
              size: 18, color: Color(0xFFFFA000)),
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
  // HEADER
  // ========================
  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
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
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kTextGrey)),
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
          border: Border.all(
              color: kBorderColor.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Container(
                width: 4,
                height: 40,
                decoration: const BoxDecoration(
                    color: kActionGreen,
                    borderRadius:
                        BorderRadius.all(Radius.circular(2)))),
            const SizedBox(width: 12),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color:
                        Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.bug_report,
                    color: kActionGreen, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Control Methods',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                          fontSize: 11, color: kTextGrey),
                      children: const [
                        TextSpan(
                            text: 'Track potential outbreaks. '),
                        TextSpan(
                            text: 'Know more?',
                            style: TextStyle(
                                color: Color.fromARGB(
                                    255, 120, 168, 64),
                                decoration:
                                    TextDecoration.underline)),
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
  // TABS
  // ========================
  Widget _buildActivityTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                              color: const Color.fromARGB(
                                      255, 0, 0, 0)
                                  .withValues(alpha: 0.05),
                              blurRadius: 4)
                        ]
                      : [],
                ),
                child: Center(
                  child: Text('Daily Activity Log',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: _selectedTab == 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedTab == 0
                              ? const Color.fromARGB(
                                  255, 0, 99, 23)
                              : kTextGrey)),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding:
                    const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? Colors.white
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                              color: const Color.fromARGB(
                                      255, 0, 0, 0)
                                  .withValues(alpha: 0.05),
                              blurRadius: 4)
                        ]
                      : [],
                ),
                child: Center(
                  child: Text('Weekly Tasks',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: _selectedTab == 1
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: _selectedTab == 1
                              ? const Color.fromARGB(
                                  255, 0, 99, 23)
                              : kTextGrey)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // DAILY ACTIVITY LOG
  // ========================
  Widget _buildDailyActivityLog() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  DateFormat('MMM yyyy').format(
                      _plantingDate ?? DateTime.now()),
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 18)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: kLightGreenBg,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list,
                        size: 14, color: kActionGreen),
                    const SizedBox(width: 4),
                    Text('Filter',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kActionGreen)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('No. of Days',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: List.generate(_totalDays, (index) {
                bool isSelected = index == _dailySelectedDay;
                bool isLocked = index > _currentDayFromPlanting;
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _dailySelectedDay = index;
                    });
                    await _loadDailyLogData(index);
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
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text('Day',
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
          const SizedBox(height: 16),
          if (_isCurrentDayLocked) _buildLockedBanner('day'),
          const SizedBox(height: 20),
          Text('Active Tasks',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          if (_dailyActiveTasks.isEmpty)
            _buildEmptyTaskState('No active tasks for this day')
          else
            ...List.generate(
                _dailyActiveTasks.length, (index) {
              final task = _dailyActiveTasks[index];
              final images = task['images'] as List<String>? ?? [];
              return _buildActiveTaskTile(
                task: task, 
                title: task['title'] ?? '',
                subtitle: task['subtitle'] ?? '',
                images: images,
                isLocked: _isCurrentDayLocked,
              );
            }),
          const SizedBox(height: 28),
          Text('Completed Tasks',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          if (_dailyCompletedTasks.isEmpty)
            _buildEmptyTaskState(
                'No completed tasks for this day')
          else
            ...List.generate(
                _dailyCompletedTasks.length, (index) {
              final task = _dailyCompletedTasks[index];
              return _buildCompletedTaskTile(
                task: task, 
                title: task['title'] ?? '',
                subtitle: task['subtitle'] ?? '',
              );
            }),
          const SizedBox(height: 28),
          AbsorbPointer(
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
                    ).then((_) {
                      // Reload daily log data when returning
                      _loadDailyLogData(_dailySelectedDay);
                    });
                  },
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: kLightGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add,
                        size: 18, color: kActionGreen),
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
                        borderRadius:
                            BorderRadius.circular(26)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
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
            style: GoogleFonts.inter(
                fontSize: 13, color: kTextGrey)),
      ),
    );
  }

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
              // Image on the left (if exists)
              if (images.isNotEmpty)
                Container(
                  width: 72,
                  height: 72,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF90CAF9), width: 1),
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
              // Title, subtitle, and complete button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF0D47A1),
                        ),
                      ),
                      if (images.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '+${images.length - 1} more image${images.length > 2 ? 's' : ''}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF42A5F5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Complete Button
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
                              Text(
                                'Mark Complete',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                color: Color.fromARGB(255, 46, 125, 50),
                size: 22),
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
          // Revert button (mark as incomplete)
          GestureDetector(
            onTap: () => _toggleTaskCompletion(task, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 14, color: kTextGrey),
                  const SizedBox(width: 4),
                  Text(
                    'Undo',
                    style: GoogleFonts.inter(
                      color: kTextGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
  // WEEK SELECTOR
  // ========================
  Widget _buildWeekSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('No. of Weeks',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: List.generate(_totalWeeks, (index) {
              bool isSelected = index == _selectedWeek;
              bool isLocked =
                  index + 1 > _currentWeekFromPlanting;
              return GestureDetector(
                onTap: () async {
                  setState(() => _selectedWeek = index);
                  await _loadWeekData(index);
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
                        mainAxisAlignment:
                            MainAxisAlignment.center,
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
                              color: kTextGrey
                                  .withValues(alpha: 0.5)),
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
  // PROGRESS & INSPECTION
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
                    const AlwaysStoppedAnimation<Color>(
                        kActionGreen),
                minHeight: 6),
          ),
        ],
      ),
    );
  }

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
              style: GoogleFonts.inter(
                  fontSize: 12, color: kTextGrey),
              children: const [
                TextSpan(
                    text:
                        'Inspect 10 plants per point and record FAW signs\n'),
                TextSpan(
                    text: 'More info about field scouting? ',
                    style: TextStyle(
                        color: Color.fromARGB(
                            255, 76, 114, 33))),
                TextSpan(
                    text: 'Click here.',
                    style: TextStyle(
                        color: Color.fromARGB(
                            255, 76, 114, 33),
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
                              color: const Color.fromARGB(255, 49, 114, 51)))),
                if (isCompleted) const SizedBox(width: 8),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 300),
                  turns: isExpanded ? 0.5 : 0.0,
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: kTextGrey),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
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
                            onDecrement: () => _decrement(index, 'plantsInspected'),
                            onIncrement: () => _increment(index, 'plantsInspected'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCounterBox(
                            label: 'DAMAGED',
                            value: data['damaged'] as int? ?? 0,
                            onDecrement: () => _decrement(index, 'damaged'),
                            onIncrement: () => _increment(index, 'damaged'),
                            valueColor: (data['damaged'] as int? ?? 0) > 0
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSmallCounter(
                          label: 'EGG MASSES',
                          value: data['eggMasses'] as int? ?? 0,
                          valueColor: (data['eggMasses'] as int? ?? 0) > 0
                              ? kAccentRed
                              : kTextDark,
                          onDecrement: () => _decrement(index, 'eggMasses'),
                          onIncrement: () => _increment(index, 'eggMasses'),
                        ),
                        _buildSmallCounter(
                          label: 'LARVAE',
                          value: data['larvae'] as int? ?? 0,
                          valueColor: (data['larvae'] as int? ?? 0) > 0
                              ? kAccentRed
                              : kTextDark,
                          onDecrement: () => _decrement(index, 'larvae'),
                          onIncrement: () => _increment(index, 'larvae'),
                        ),
                        _buildSmallCounter(
                          label: 'PUPAE',
                          value: data['pupae'] as int? ?? 0,
                          valueColor: (data['pupae'] as int? ?? 0) > 0
                              ? kAccentRed
                              : kTextDark,
                          onDecrement: () => _decrement(index, 'pupae'),
                          onIncrement: () => _increment(index, 'pupae'),
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
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Upload Photo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isLocked ? kTextGrey : kTextDark,
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: isLocked ? kBorderColor : kBorderColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLocked ? null : () => _completeStation(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCompleted ? Colors.white : kActionGreen,
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                              side: isCompleted
                                  ? const BorderSide(color: kActionGreen)
                                  : BorderSide.none),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                isCompleted ? Icons.update_outlined : Icons.check_circle_outline,
                                color: isLocked
                                    ? kTextGrey
                                    : (isCompleted ? kActionGreen : Colors.white),
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              isCompleted ? 'Update Station' : 'Complete Station',
                              style: GoogleFonts.inter(
                                color: isLocked
                                    ? kTextGrey
                                    : (isCompleted ? kActionGreen : Colors.white),
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

  Widget _buildAnimatedFindingTile(
      String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: kBorderColor.withValues(alpha: 0.5))),
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
                  ScaleTransition(
                      scale: animation, child: child),
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

  Widget _buildSaveButton() {
    // Hide button completely for locked weeks
    if (_isCurrentWeekLocked) return const SizedBox.shrink();
    
    // For editable weeks, show a subtle indicator instead of a big button
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
                            color: Colors.black
                                .withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1))
                      ]),
                  child: const Icon(Icons.remove,
                      size: 14, color: kTextDark),
                ),
              ),
              AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 200),
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
                            color: Colors.black
                                .withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1))
                      ]),
                  child: const Icon(Icons.add,
                      size: 14, color: kTextDark),
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
      padding: const EdgeInsets.symmetric(
          vertical: 8, horizontal: 10),
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
                            color: Colors.black
                                .withValues(alpha: 0.06),
                            blurRadius: 3)
                      ]),
                  child: const Icon(Icons.remove,
                      size: 12, color: kTextDark),
                ),
              ),
              AnimatedSwitcher(
                duration:
                    const Duration(milliseconds: 200),
                child: Text('$value',
                    key: ValueKey<int>(value),
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        color: valueColor)),
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
                            color: Colors.black
                                .withValues(alpha: 0.06),
                            blurRadius: 3)
                      ]),
                  child: const Icon(Icons.add,
                      size: 12, color: kTextDark),
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
            style: GoogleFonts.inter(
                fontSize: 13, color: kTextDark),
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
                style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Explore detailed steps for each management strategy based on environmental impact.',
                style: GoogleFonts.inter(
                    fontSize: 14, color: kTextGrey)),
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
                onTap: () => setState(
                    () => _showControlModal = false),
                child: const Text(
                    'Continue with physical control? Back to monitoring',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        decoration:
                            TextDecoration.underline,
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
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10)
          ]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(
                  backgroundColor: kLightGreenBg,
                  radius: 18,
                  child: Icon(icon,
                      color: kActionGreen, size: 20)),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              if (rec)
                Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: kActionGreen,
                        borderRadius:
                            BorderRadius.circular(8)),
                    child: const Text('RECOMMENDED',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)))
            ]),
            const SizedBox(height: 8),
            Text(desc,
                style: GoogleFonts.inter(
                    fontSize: 12, color: kTextGrey)),
          ]),
    );
  }
}