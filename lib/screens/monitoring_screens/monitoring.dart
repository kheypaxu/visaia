import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/widgets/success_modal.dart';
import 'package:visaia/services/firestore_service.dart';
import 'package:visaia/screens/logging_screens/daily_log_screen.dart';
import 'package:visaia/screens/logging_screens/pest_verification.dart';
import 'package:flutter/gestures.dart';
import 'package:visaia/screens/logging_screens/field_scouting_demo.dart';
import 'package:visaia/screens/logging_screens/trap_lists.dart';
import 'package:visaia/screens/logging_screens/trap_guide.dart';
import 'package:visaia/utils/growth_stage.dart';
import 'package:visaia/utils/scouting_report_date.dart';
import 'package:visaia/utils/chemical_task_policy.dart';
import 'package:visaia/widgets/database_image.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

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

// ==========================================
// FAW DAMAGE ASSESSMENT (TNAU 1-5 SCALES)
// Basis: Srinivasan et al. (2022), Madras Agricultural Journal 109:69-75
// ==========================================
enum FAWAssessmentType { whorl, cob, transitional }

/// Determines which TNAU scoring guide applies based on Days After Planting.
/// Seedling/Early Whorl/Late Whorl (0-45 DAP) -> Whorl Leaf scale
/// Tasseling-Silking (45-55 DAP) -> transitional, farmer selects part
/// Grain Filling/Maturity (55+ DAP) -> Cob scale
FAWAssessmentType getFAWAssessmentType(int dap) {
  if (dap <= 45) return FAWAssessmentType.whorl;
  if (dap <= 55) return FAWAssessmentType.transitional;
  return FAWAssessmentType.cob;
}

const List<Map<String, String>> kWhorlLeafDamageScale = [
  {
    'score': '1',
    'label': 'No damage / pinhole',
    'desc': 'No visible damage or only very small pinhole-like feeding marks.',
  },
  {
    'score': '2',
    'label': '< 1 inch holes',
    'desc': 'Small circular or elongated feeding holes less than ~1 inch.',
  },
  {
    'score': '3',
    'label': '> 1 inch holes',
    'desc': 'Clearly visible elongated feeding holes greater than ~1 inch.',
  },
  {
    'score': '4',
    'label': 'Mild shredding',
    'desc': 'Elongated holes (1-2 in) with mild shredding/tearing of whorl leaves.',
  },
  {
    'score': '5',
    'label': 'Severe shredding/defoliation',
    'desc': 'Extensive feeding damage with severe shredding and substantial leaf loss.',
  },
];

const List<Map<String, String>> kCobDamageScale = [
  {
    'score': '1',
    'label': 'Nil to slight tip damage',
    'desc': 'No visible cob damage or only slight damage at the tip.',
  },
  {
    'score': '2',
    'label': '< 25% cob area',
    'desc': 'FAW damage visible on less than one-fourth of the cob area.',
  },
  {
    'score': '3',
    'label': '26-50% cob area',
    'desc': 'Approximately one-fourth to one-half of the cob area is damaged.',
  },
  {
    'score': '4',
    'label': '51-75% cob area',
    'desc': 'More than half and up to approximately three-fourths of the cob area is damaged.',
  },
  {
    'score': '5',
    'label': 'Extensive cob damage',
    'desc': 'Extensive FAW-associated cob damage (pending RCPC clarification on exact percentage).',
  },
];

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
  bool _isCalculatingThreshold = false;
  String? _selectedControlMethod;
  bool _wasThresholdTriggered = false;
  int? _chemicalControlStartWeek;
  int? _loadedWeekIndex;
  bool _trapsInstalled = false;
  String _fieldId = '';
  String _farmId = '';
  String _farmName = '';
  String _farmerId = '';
  String _farmerName = '';

  @override
  void initState() {
    super.initState();
    final userId = widget.userId ??
        FirebaseAuth.instance.currentUser?.uid ??
        AuthCacheService().cachedUid;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh daily log when returning from child screens
    if (!_isInitialLoading) {
      _loadDailyLogData(_dailySelectedDay);
    }
  }

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

  int get _selectedDayDap {
    if (_plantingDate == null) return 0;
    final dayDate = _getDayDate(_dailySelectedDay);
    return dayDate.difference(_plantingDate!).inDays.clamp(0, _totalDays);
  }

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
      _stationData.fold(0, (sum, item) => sum + (item['damaged'] as int? ?? 0));

  int get _totalEggs =>
      _stationData.fold(0, (sum, item) => sum + (item['eggMasses'] as int? ?? 0));

  int get _totalLarvae =>
      _stationData.fold(0, (sum, item) => sum + (item['larvae'] as int? ?? 0));

  int get _totalPupae =>
      _stationData.fold(0, (sum, item) => sum + (item['pupae'] as int? ?? 0));

  int get _totalMoths =>
      _stationData.fold(0, (sum, item) => sum + (item['moths'] as int? ?? 0));

  // UI state
  bool _showControlModal = false;
  bool _showSuccessModal = false;
  // Clustered report UI state
  bool _showClusteredReportButton = false;
  bool _isSavingReport = false;

  List<Map<String, dynamic>> _getDefaultStations(int count) {
    return List.generate(count, (i) => {
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

  List<Map<String, dynamic>> _normalizeLoadedStations(dynamic rawStations) {
    if (rawStations is! List) return [];

    return rawStations.map<Map<String, dynamic>>((rawStation) {
      final station = Map<String, dynamic>.from(rawStation as Map);
      final plantsInspected = station['plantsInspected'];

      // Older saved weeks may not contain the fixed 10-plant sample count.
      if (plantsInspected is! num || plantsInspected.toInt() != 10) {
        station['plantsInspected'] = 10;
      } else {
        station['plantsInspected'] = plantsInspected.toInt();
      }

      return station;
    }).toList();
  }

  final Map<int, Map<int, String>> _recommendedTaskState = {};

  // ========================
  // RECOMMENDED TASKS PER WEEK (weeks 1–8)
  // ========================
  static const Map<int, List<Map<String, dynamic>>> _weeklyRecommendedTasks = {
    // ... (keep existing weeklyRecommendedTasks) ...
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
        'requiresChemicalEligibility': true,
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
        'requiresChemicalEligibility': true,
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

  Future<void> _verifyPestObservations(int stationIndex, Map<String, dynamic> station) async {
    final hasEggMasses = (station['eggMasses'] as int? ?? 0) > 0;
    final hasLarvae = (station['larvae'] as int? ?? 0) > 0;
    final hasPupae = (station['pupae'] as int? ?? 0) > 0;
    final hasMoths = (station['moths'] as int? ?? 0) > 0;
    
    if (!hasEggMasses && !hasLarvae && !hasPupae && !hasMoths) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pests to verify. Add pest observations first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PestVerificationScreen(
          userId: _userId,
          cycleId: widget.cycleId,
          stationIndex: stationIndex,
          station: station,
          onVerificationComplete: (updatedStation) {
            setState(() {
              _stationData[stationIndex] = updatedStation;
            });
            _scheduleAutoSave();
          },
        ),
      ),
    );
  }

  void _increment(int index, String key) => _incrementPestCount(index, key);
  void _decrement(int index, String key) => _decrementPestCount(index, key);
  void _completeStation(int index) => _completeStationItem(index);


  void _incrementPestCount(int index, String key) {
    if (_isCurrentWeekLocked) return;
    setState(() {
      _stationData[index][key] = (_stationData[index][key] as int) + 1;
      
      if (key == 'eggMasses' || key == 'larvae' || key == 'pupae' || key == 'moths') {
        final newCount = _stationData[index][key] as int;
        if (newCount > 0 && !(_stationData[index]['verificationRequired'] as bool? ?? false)) {
          _stationData[index]['verificationRequired'] = true;
          _stationData[index]['verificationCompleted'] = false;
        }
      }
      
      if (key == 'damaged' && _stationData[index][key] > 0) {
        _stationData[index]['fawObserved'] = true;
      }
    });
    _scheduleAutoSave();
  }

  void _decrementPestCount(int index, String key) {
    if (_isCurrentWeekLocked) return;
    if (_stationData[index][key] as int <= 0) return;
    setState(() {
      _stationData[index][key] = (_stationData[index][key] as int) - 1;
      
      if (key == 'eggMasses' || key == 'larvae' || key == 'pupae' || key == 'moths') {
        final hasEggs = (_stationData[index]['eggMasses'] as int) > 0;
        final hasLarvae = (_stationData[index]['larvae'] as int) > 0;
        final hasPupae = (_stationData[index]['pupae'] as int) > 0;
        final hasMoths = (_stationData[index]['moths'] as int) > 0;
        
        if (!hasEggs && !hasLarvae && !hasPupae && !hasMoths) {
          _stationData[index]['verificationRequired'] = false;
          _stationData[index]['verificationCompleted'] = false;
        }
      }
      
      if (key == 'damaged' && _stationData[index][key] == 0) {
        final hasOtherSigns = (_stationData[index]['eggMasses'] as int) > 0 ||
            (_stationData[index]['larvae'] as int) > 0 ||
            (_stationData[index]['pupae'] as int) > 0 ||
            (_stationData[index]['moths'] as int) > 0;
        if (!hasOtherSigns) _stationData[index]['fawObserved'] = false;
      }
    });
    _scheduleAutoSave();
  }


Future<void> _checkThresholdAfterCompletion() async {
  setState(() {
    _isCalculatingThreshold = true;
  });
  
  await Future.delayed(const Duration(milliseconds: 500));
  
  int totalDamaged = 0;
  int totalInspected = 0;
  for (var station in _stationData) {
    totalDamaged += station['damaged'] as int? ?? 0;
    totalInspected += station['plantsInspected'] as int? ?? 0;
  }
  
  setState(() => _isCalculatingThreshold = false);
  double damagePercent = (totalInspected > 0) ? (totalDamaged / totalInspected) * 100 : 0.0;
  
  if (damagePercent >= 10.0) {
    _wasThresholdTriggered = true;
    _showControlMethodModalWithResult(damagePercent, totalDamaged, totalInspected);
    setState(() {
      _showClusteredReportButton = true;
    });
  } else {
    _wasThresholdTriggered = false;
    _showSafeModal(damagePercent, totalDamaged, totalInspected);
    setState(() {
      _showClusteredReportButton = true;
    });
  }
}

void _showControlMethodModalWithResult(double percent, int damaged, int inspected) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: kAccentRed, size: 28),
          const SizedBox(width: 10),
          const Text('Action Required', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Damage threshold exceeded! (High Level Report)',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: kAccentRed),
          ),
          const SizedBox(height: 12),
          Text(
            'Damaged plants: $damaged out of $inspected inspected (${percent.toStringAsFixed(1)}%).',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            'Immediate control measures are strongly recommended to prevent yield loss.',
            style: GoogleFonts.inter(fontSize: 13, color: kTextGrey),
          ),
          const SizedBox(height: 20),
          Text(
            'Select a control method:',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later', style: TextStyle(color: kTextGrey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            setState(() => _showControlModal = true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
          child: const Text('View Control Methods'),
        ),
      ],
    ),
  );
}

void _showSafeModal(double percent, int damaged, int inspected) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.check_circle, color: kActionGreen, size: 28),
          const SizedBox(width: 10),
          const Text('All Good!', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Damage is under control (Low Level).',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: kActionGreen),
          ),
          const SizedBox(height: 8),
          Text(
            'Damaged plants: $damaged out of $inspected inspected (${percent.toStringAsFixed(1)}%).',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'No immediate control action required. You can create your low-level weekly clustered report.',
            style: GoogleFonts.inter(fontSize: 13, color: kTextGrey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Later', style: TextStyle(color: kTextGrey)),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            _createClusteredReport();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kActionGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save Report'),
        ),
      ],
    ),
  );
}

  void _completeStationItem(int index) async {
    if (_isCurrentWeekLocked) return;
    
    final station = _stationData[index];
    final plantsInspected = station['plantsInspected'] as int? ?? 0;
    final needsVerification = station['verificationRequired'] as bool? ?? false;
    final isVerificationCompleted = station['verificationCompleted'] as bool? ?? false;
    
    // Check for exactly 10 plants inspected (changed from minimum 10)
    if (plantsInspected < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please inspect all 10 plants before completing this station'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    if (needsVerification && !isVerificationCompleted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please verify all observed pests before completing this station'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Check FAW damage assessment completeness (per Damaged-Plant Guideline)
    final damageIncomplete = _isDamageAssessmentIncomplete(index);
    if (damageIncomplete != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(damageIncomplete),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    setState(() {
      _stationData[index]['completed'] = true;
      _expandedStationIndex = -1;
    });
    _scheduleAutoSave();
    
    // Check if all stations are now completed
    final totalStations = _stationData.length;
    final completedCount = _stationData.where((s) => s['completed'] as bool? ?? false).length;
    if (completedCount == totalStations && totalStations > 0) {
      await _updateCycleGrowthStage();
      _checkThresholdAfterCompletion();
    }
  }

  // ========================
  // FAW DAMAGE ASSESSMENT HELPERS
  // ========================

  /// FAW presence per the guideline: egg masses, larvae, pupae, moths, or a
  /// positive FAW detection (fawObserved) recorded at the station.
  bool _hasFAWPresence(Map<String, dynamic> station) {
    final eggs = station['eggMasses'] as int? ?? 0;
    final larvae = station['larvae'] as int? ?? 0;
    final pupae = station['pupae'] as int? ?? 0;
    final moths = station['moths'] as int? ?? 0;
    final fawObserved = station['fawObserved'] as bool? ?? false;
    return eggs > 0 || larvae > 0 || pupae > 0 || moths > 0 || fawObserved;
  }

  /// Keeps plantDamageScores rows in sync with the current "damaged" count,
  /// so the per-plant scoring table always matches the number of damaged
  /// plants recorded at the station.
  List<Map<String, dynamic>> _ensureDamageScoreRows(int stationIndex) {
    final station = _stationData[stationIndex];
    final damaged = station['damaged'] as int? ?? 0;
    final rows = List<Map<String, dynamic>>.from(
      ((station['plantDamageScores'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );
    if (rows.length < damaged) {
      for (int i = rows.length; i < damaged; i++) {
        rows.add({'plantNumber': i + 1, 'whorlScore': null, 'cobScore': null});
      }
    } else if (rows.length > damaged) {
      rows.removeRange(damaged, rows.length);
    }
    station['plantDamageScores'] = rows;
    return rows;
  }

  void _setDamageAssessmentChoice(int stationIndex, String? choice) {
    if (_isCurrentWeekLocked) return;
    setState(() {
      _stationData[stationIndex]['damageAssessmentChoice'] = choice;
    });
    _scheduleAutoSave();
  }

  void _setPlantDamageScore(int stationIndex, int plantIndex, String key, int score) {
    if (_isCurrentWeekLocked) return;
    setState(() {
      final rows = _ensureDamageScoreRows(stationIndex);
      rows[plantIndex][key] = score;
      _stationData[stationIndex]['plantDamageScores'] = rows;
    });
    _scheduleAutoSave();
  }

  /// Returns a user-facing message if the damage assessment for [stationIndex]
  /// is required but incomplete, otherwise null.
  String? _isDamageAssessmentIncomplete(int stationIndex) {
    final station = _stationData[stationIndex];
    if (!_hasFAWPresence(station)) return null;

    final damaged = station['damaged'] as int? ?? 0;
    if (damaged <= 0) return null;

    final assessmentType = getFAWAssessmentType(_selectedDayDap);

    String? choice;
    if (assessmentType == FAWAssessmentType.transitional) {
      choice = station['damageAssessmentChoice'] as String?;
      if (choice == null) {
        return 'Please select where the fresh FAW damage is observed (Whorl/Leaves, Cob/Ear, or Both)';
      }
    } else {
      choice = assessmentType == FAWAssessmentType.whorl ? 'whorl' : 'cob';
    }

    final needsWhorl = choice == 'whorl' || choice == 'both';
    final needsCob = choice == 'cob' || choice == 'both';

    final rows = _ensureDamageScoreRows(stationIndex);
    final incomplete = rows.length < damaged ||
        rows.any((r) =>
            (needsWhorl && r['whorlScore'] == null) ||
            (needsCob && r['cobScore'] == null));

    if (incomplete) {
      return 'Please complete the damage score for all $damaged damaged plant(s)';
    }

    final photos = (station['damagePhotos'] as List?) ?? [];
    if (photos.isEmpty) {
      return 'Please attach a photo showing the visible FAW damage';
    }

    return null;
  }

  // ========================
  // DATA LOADING
  // ========================
Future<void> _loadCycleData() async {
  try {
    final cycle = await _firestoreService
        .getCycle(widget.cycleId)
        .timeout(const Duration(seconds: 15));
    if (cycle == null) {
      setState(() {
        _error = 'Cycle not found';
        _isInitialLoading = false;
      });
      return;
    }

    final planting = (cycle['plantingDate'] as Timestamp?)?.toDate();
    final harvest = (cycle['harvestDate'] as Timestamp?)?.toDate();

    if (planting == null || harvest == null) {
      setState(() {
        _error = 'Invalid cycle dates';
        _isInitialLoading = false;
      });
      return;
    }

    if (harvest.isBefore(planting) || harvest.isAtSameMomentAs(planting)) {
      setState(() {
        _error = 'Harvest date must be after planting date';
        _isInitialLoading = false;
      });
      return;
    }

    final controlMethod = cycle['controlMethod'] as String?;
    final selectedAt = (cycle['controlMethodSelectedAt'] as Timestamp?)?.toDate();
    final savedStartWeek = cycle['chemicalControlStartWeek'] as int?;

    // Fetch farmer ID from cycle or from the farm
    String farmerId = cycle['farmerId'] as String? ?? '';
    String farmerName = '';

    // If farmerId is not in cycle, try to get it from the farm
    if (farmerId.isEmpty) {
      final farmId = cycle['farmId'] as String? ?? '';
      if (farmId.isNotEmpty) {
        DocumentSnapshot<Map<String, dynamic>>? farmDoc;
        try {
          farmDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .collection('farms')
              .doc(farmId)
              .safeGet();
        } catch (_) {}
        if (farmDoc != null && farmDoc.exists) {
          farmerId = _userId; // The farm belongs to this user
        }
      }
    }

    // Fetch farmer name from cache or farmers collection
    farmerName = AuthCacheService().cachedName ?? '';
    if (farmerName.isEmpty && farmerId.isNotEmpty) {
      DocumentSnapshot<Map<String, dynamic>>? farmerDoc;
      try {
        farmerDoc = await FirebaseFirestore.instance
            .collection('farmers')
            .doc(farmerId)
            .safeGet();
      } catch (_) {}
      if (farmerDoc != null && farmerDoc.exists) {
        final data = farmerDoc.data();
        farmerName = data?['fullName'] as String? ?? data?['name'] as String? ?? '';
      } else {
        // Fallback to users collection
        DocumentSnapshot<Map<String, dynamic>>? userDoc;
        try {
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(farmerId)
              .safeGet();
        } catch (_) {}
        if (userDoc != null && userDoc.exists) {
          final data = userDoc.data();
          farmerName = data?['fullName'] as String? ?? data?['name'] as String? ?? '';
        }
      }

      // Add a fallback for farmer name if it's still empty after the fetch
      if (farmerName.isEmpty) {
        // Try to get from users collection as a fallback
        DocumentSnapshot<Map<String, dynamic>>? userDoc;
        try {
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_userId)
              .safeGet();
        } catch (_) {}
        if (userDoc != null && userDoc.exists) {
          final data = userDoc.data();
          farmerName = data?['fullName'] as String? ?? data?['name'] as String? ?? 'Unknown Farmer';
        }
      }
    }

    setState(() {
      _plantingDate = planting;
      _harvestDate = harvest;
      _cycleName = cycle['cycleName'] ?? 'Unknown Cycle';
      _fieldName = cycle['fieldName'] ?? 'Unknown Field';
      _fieldId = cycle['fieldId'] ?? '';
      _farmId = cycle['farmId'] ?? '';
      _farmName = cycle['farmName'] ?? '';
      _farmerId = farmerId;
      _farmerName = farmerName;
      _selectedWeek = (_currentWeekFromPlanting - 1).clamp(0, _totalWeeks - 1);
      _dailySelectedDay = _currentDayFromPlanting.clamp(
        _selectedWeek * 7,
        ((_selectedWeek * 7 + 6).clamp(0, _totalDays - 1)),
      );
      _selectedControlMethod = controlMethod;
      _chemicalControlStartWeek = savedStartWeek ??
          (controlMethod == 'chemical' && selectedAt != null
              ? (selectedAt.difference(planting).inDays ~/ 7 + 1).clamp(1, 52)
              : null);
      _trapsInstalled = cycle['trapsInstalled'] == true;
    });

    await _loadWeekData(_selectedWeek);
    await _loadDailyLogData(_dailySelectedDay);
    await _updateCycleGrowthStage();
  } on TimeoutException {
    setState(() {
      _error = 'Loading cycle data timed out. Check your connection.';
    });
  } catch (e) {
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
    setState(() {
      _isWeekLoading = true;
      _loadedWeekIndex = null;
    });

    try {
      final weekId = 'week_${weekIndex + 1}';
      final weekData = await _firestoreService
          .getWeek(widget.cycleId, weekId)
          .timeout(const Duration(seconds: 15));
      if (!mounted || weekIndex != _selectedWeek) return;

      final loadedTaskState = <int, String>{};
      if (weekData != null && weekData['recommendedTaskState'] != null) {
        final rawMap = Map<String, dynamic>.from(weekData['recommendedTaskState'] as Map);
        rawMap.forEach((k, v) {
          final intKey = int.tryParse(k.toString());
          if (intKey != null && v is String) {
            loadedTaskState[intKey] = v;
          }
        });
      }

      if (weekData != null && weekData['stations'] != null) {
        final stations = _normalizeLoadedStations(weekData['stations']);
        final allCompleted = stations.isNotEmpty &&
            stations.every((s) => s['completed'] == true);
        int totalDamaged = stations.fold(0, (sum, item) => sum + (item['damaged'] as int? ?? 0));
        int totalInspected = stations.fold(0, (sum, item) => sum + (item['plantsInspected'] as int? ?? 0));
        double damagePercent = totalInspected > 0 ? (totalDamaged / totalInspected) * 100 : 0.0;
        setState(() {
          _stationData = stations;
          _expandedStationIndex = -1;
          _showClusteredReportButton = allCompleted;
          _wasThresholdTriggered = damagePercent >= 10.0;
          _recommendedTaskState[weekIndex] = loadedTaskState;
          _loadedWeekIndex = weekIndex;
        });
      } else {
        setState(() {
          _stationData = _getDefaultStations(5);
          _expandedStationIndex = -1;
          _showClusteredReportButton = false;
          _wasThresholdTriggered = false;
          _recommendedTaskState[weekIndex] = loadedTaskState;
          _loadedWeekIndex = weekIndex;
        });
      }
    } on TimeoutException {
      if (!mounted || weekIndex != _selectedWeek) return;
      setState(() {
        _stationData = _getDefaultStations(5);
        _expandedStationIndex = -1;
      });
    } catch (e) {
      if (!mounted || weekIndex != _selectedWeek) return;
      setState(() {
        _stationData = _getDefaultStations(5);
        _expandedStationIndex = -1;
      });
    } finally {
      if (mounted && weekIndex == _selectedWeek) {
        setState(() => _isWeekLoading = false);
      }
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
          .safeGet();

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
    final stateMap = _recommendedTaskState[_selectedWeek] ?? {};
    final firestoreTaskMap = stateMap.map((k, v) => MapEntry(k.toString(), v));
    final data = {
      'stations': _stationData,
      'totals': {
        'damaged': _totalDamaged,
        'eggs': _totalEggs,
        'larvae': _totalLarvae,
        'pupae': _totalPupae,
        'moths': _totalMoths,
      },
      'recommendedTaskState': firestoreTaskMap,
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

  Future<void> _saveRecommendedTaskState(int weekIndex) async {
    try {
      final weekId = 'week_${weekIndex + 1}';
      final stateMap = _recommendedTaskState[weekIndex] ?? {};
      final firestoreMap = stateMap.map((k, v) => MapEntry(k.toString(), v));
      await _firestoreService.saveWeek(widget.cycleId, weekId, {
        'recommendedTaskState': firestoreMap,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving recommended task state: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task state: $e')),
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

  Future<void> _logChemicalApplicationToDailyLog(Map<String, dynamic> task) async {
  try {
    final dayId = 'day_${(_dailySelectedDay + 1).toString().padLeft(2, '0')}';
    final chemicalName = task['title'] ?? 'Chemical Application';
    final details = task['details'] ?? task['description'] ?? '';
    
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .collection('dailyLogs')
        .doc(dayId)
        .collection('activities')
        .doc();
    
    await docRef.set({
      'type': 'Chemical Application: $chemicalName',
      'notes': details,
      'images': [],
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'isChemicalApplication': true,
      'chemicalName': chemicalName,
    });
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .collection('chemicalApplications')
        .add({
      'chemicalName': chemicalName,
      'weekApplied': _selectedWeek + 1,
      'dayApplied': _dailySelectedDay + 1,
      'stage': task['stage'] ?? 'Unknown',
      'appliedAt': FieldValue.serverTimestamp(),
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $chemicalName logged to daily activities'),
          backgroundColor: kActionGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
    await _loadDailyLogData(_dailySelectedDay);
    
  } catch (e) {
    debugPrint('Error logging chemical application: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log chemical application: $e'),
          backgroundColor: Colors.red,
        ),
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
                          const SizedBox(height: 12),
                          _buildGrowthStageCard(),
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
            if (_isCalculatingThreshold)
            Container(
              color: Colors.black.withValues(alpha:0.5),
              child: const Center(
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: kActionGreen),
                        SizedBox(height: 16),
                        Text(
                          'Analyzing field data...',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      )
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
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
          child: const Icon(Icons.arrow_back, color: kTextDark),
          ),
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
  bool isBiological = _selectedControlMethod == "biological";
  bool isChemical = _selectedControlMethod == "chemical";

  if (isChemical) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFC62828),
              borderRadius: BorderRadius.all(Radius.circular(2))
            )
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.science, color: Color(0xFFC62828), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chemical Control Active',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFFC62828),
                  )
                ),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 11, color: kTextGrey),
                    children: [
                      const TextSpan(text: 'Using chemical control - '),
                      TextSpan(
                        text: 'View options',
                        style: const TextStyle(
                          color: Color(0xFFC62828),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showChemicalInfoDialog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showChemicalInfoDialog(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC62828), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Info',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: Color(0xFFC62828), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

if (isBiological) {
  bool trapsInstalled = _trapsInstalled;
  
  return GestureDetector(
    onTap: () async {
      if (trapsInstalled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrapSetupScreen(
              cycleId: widget.cycleId,
              userId: _userId,
              initialStep: 2,
              viewOnly: true,
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrapSetupScreen(
              cycleId: widget.cycleId,
              userId: _userId,
              initialStep: 0,
            ),
          ),
        );
      }
      await _loadDailyLogData(_dailySelectedDay);
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .safeGet();
      if (cycleDoc.exists) {
        setState(() {
          _trapsInstalled = cycleDoc.data()?['trapsInstalled'] == true;
        });
      }
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: trapsInstalled 
              ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
              : const Color(0xFF2E7D32).withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02), 
            blurRadius: 10
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: trapsInstalled 
                  ? const Color(0xFF0F5234)
                  : const Color(0xFF2E7D32),
              borderRadius: const BorderRadius.all(Radius.circular(2))
            )
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: trapsInstalled 
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              trapsInstalled ? Icons.visibility : Icons.ads_click, 
              color: const Color(0xFF2E7D32), 
              size: 20
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trapsInstalled ? 'View Traps' : 'Install Traps?',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600, 
                    fontSize: 14,
                    color: const Color(0xFF2E7D32)
                  )
                ),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(fontSize: 11, color: kTextGrey),
                    children: [
                      TextSpan(
                        text: trapsInstalled 
                            ? '${_trapsInstalled ? 'View existing traps' : 'No traps installed'}. '
                            : 'Track potential outbreaks. '
                      ),
                      TextSpan(
                        text: trapsInstalled ? 'Manage traps?' : 'Know more?',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 120, 168, 64),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TrapGuideScreen(),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            trapsInstalled ? Icons.arrow_forward : Icons.arrow_forward,
            color: const Color(0xFF2E7D32), 
            size: 22
          ),
        ],
      ),
    ),
  );
}

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
              child: const Icon(Icons.bug_report, color: kActionGreen, size: 20)),
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
                    style: GoogleFonts.inter(fontSize: 11, color: kTextGrey),
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

  Future<void> _selectControlMethod(String method) async {
  if (_isCurrentWeekLocked || _isWeekLoading) return;
  final startWeek = _chemicalControlStartWeek ?? _selectedWeek + 1;

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .update({
      'controlMethod': method,
      'controlMethodSelectedAt': FieldValue.serverTimestamp(),
      if (method == 'chemical') 'chemicalControlStartWeek': startWeek,
    });
    if (!mounted) return;
    setState(() {
      _selectedControlMethod = method;
      if (method == 'chemical') _chemicalControlStartWeek = startWeek;
      _showControlModal = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            method == 'biological'
                ? 'Biological control selected. Install traps to start monitoring.'
                : 'Chemical control selected. Application tasks appear only for weeks with qualifying scouting results.',
          ),
          backgroundColor: method == 'biological' 
              ? const Color(0xFF2E7D32)
              : const Color(0xFFC62828),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (method == 'chemical' && mounted) {
      _addChemicalRecommendationsToTasks();
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save control method: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Helper to get field location
Future<GeoPoint?> _getFieldLocation() async {
  try {
    final cycleDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .safeGet();
    
    if (cycleDoc.exists) {
      final data = cycleDoc.data();
      final fieldId = data?['fieldId'] as String?;
      if (fieldId != null) {
        final fieldDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('fields')
            .doc(fieldId)
            .safeGet();
        
        if (fieldDoc.exists) {
          final fieldData = fieldDoc.data();
          final boundaries = fieldData?['boundaries'] as List?;
          if (boundaries != null && boundaries.isNotEmpty) {
            double latSum = 0;
            double lngSum = 0;
            for (final point in boundaries) {
              latSum += (point['lat'] as num).toDouble();
              lngSum += (point['lng'] as num).toDouble();
            }
            final lat = latSum / boundaries.length;
            final lng = lngSum / boundaries.length;
            return GeoPoint(lat, lng);
          }
        }
      }
    }
    return null;
  } catch (e) {
    print('Error getting field location: $e');
    return null;
  }
}

void _showChemicalInfoDialog() {
  final recommendation = _getChemicalRecommendation();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.science, color: const Color(0xFFC62828), size: 28),
          const SizedBox(width: 10),
          const Text('Chemical Control Info', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: const Color(0xFFC62828), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Always follow safety guidelines and wear protective equipment.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFC62828),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Current Recommendation:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation['title'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation['description'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: kTextGrey,
                    ),
                  ),
                  if (recommendation['details'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        recommendation['details']!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chemical Options:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...(recommendation['chemicals'] as List<String>).map((chemical) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFFC62828), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      chemical,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _addChemicalRecommendationsToTasks();
          },
          icon: const Icon(Icons.add_task, color: Colors.white),
          label: const Text('Add to Tasks'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
        ),
      ],
    ),
  );
}

GrowthStageInfo _getCurrentGrowthStage() {
  final dap = _selectedDayDap;
  return getGrowthStage(dap);
}

Map<String, dynamic> _getChemicalRecommendation() {
  final weekNumber = _selectedWeek + 1;
  final hasThresholdTriggered = _wasThresholdTriggered;
  
  bool hasHighEggs = _totalEggs > 5;
  bool hasHighLarvae = _totalLarvae > 3;
  bool hasHighMoths = _totalMoths > 2;
  
  Map<String, dynamic> recommendation = {};
  
  if (weekNumber <= 2) {
    recommendation = {
      'title': 'Apply Prevathon 5SC or Exalt',
      'description': 'Early vegetative stage - best for small larvae. Protects emerging growing point.',
      'chemicals': ['Prevathon 5SC', 'Exalt 60 SC'],
      'stage': 'Early Vegetative (V1-V5)',
      'icon': Icons.agriculture,
    };
  } else if (weekNumber <= 4) {
    recommendation = {
      'title': 'Apply Exalt or Atabron',
      'description': 'Late vegetative - fast kill (Exalt) or molting prevention (Atabron).',
      'chemicals': ['Exalt 60 SC', 'Atabron 5E'],
      'stage': 'Late Vegetative (V6-VT)',
      'icon': Icons.science,
    };
  } else if (weekNumber <= 6) {
    recommendation = {
      'title': 'Apply Prevathon',
      'description': 'Tasseling/Silking stage - safer for pollinators compared to others.',
      'chemicals': ['Prevathon 5SC'],
      'stage': 'Tasseling/Silking (VT-R1)',
      'icon': Icons.eco,
    };
  } else {
    recommendation = {
      'title': 'Scout & Spot-treat Only',
      'description': 'Ear stage - observe PHI before harvest. Spot-treat if needed.',
      'chemicals': ['Prevathon 5SC', 'Atabron 5E'],
      'stage': 'Ear Stage (R2+)',
      'icon': Icons.search,
    };
  }
  
  if (hasThresholdTriggered) {
    if (hasHighEggs) {
      recommendation['details'] = '⚠️ High egg masses detected. Consider Atabron (IGR) to prevent larval development.';
      recommendation['priority'] = 'high';
    } else if (hasHighLarvae) {
      recommendation['details'] = '⚠️ Larvae detected. Use Exalt for quick knockdown or Prevathon for residual control.';
      recommendation['priority'] = 'high';
    } else if (hasHighMoths) {
      recommendation['details'] = '⚠️ High moth activity. Apply contact insecticide for immediate control.';
      recommendation['priority'] = 'medium';
    } else {
      recommendation['details'] = '⚠️ Damage threshold exceeded. Apply recommended chemical control immediately.';
      recommendation['priority'] = 'high';
    }
  }
  
  return recommendation;
}

void _addChemicalRecommendationsToTasks() {
  final eligible = _isChemicalEligibleForSelectedWeek;
  setState(() {});
  
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(eligible
            ? 'Chemical recommendations added for this week.'
            : 'No chemical application task: this week must have completed scouting that meets the damage threshold.'),
        backgroundColor: eligible ? const Color(0xFFC62828) : kActionGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

Widget _buildGrowthStageCard() {
  final info = _getCurrentGrowthStage();
  final color = info.vulnerabilityScore >= 0.7 ? kAccentRed : kActionGreen;
  
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.3)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
    ),
    child: Row(
      children: [
        Icon(Icons.eco, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Growth Stage',
                style: GoogleFonts.inter(fontSize: 12, color: kTextGrey),
              ),
              Text(
                info.name,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                'DAP $_selectedDayDap • ${info.riskLabel} vulnerability',
                style: GoogleFonts.inter(fontSize: 12, color: kTextGrey),
              ),
            ],
          ),
        ),
      ],
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
            _buildDailyActivitySection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
        if (_isWeekLoading)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha:0.7),
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
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
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
              children: [
                const TextSpan(
                  text: 'Inspect 10 plants per point and record FAW signs\n',
                ),
                const TextSpan(
                  text: 'More info about field scouting? ',
                  style: TextStyle(color: Color.fromARGB(255, 76, 114, 33)),
                ),
                TextSpan(
                  text: 'Click here.',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 76, 114, 33),
                    decoration: TextDecoration.underline,
                    fontStyle: FontStyle.italic,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FieldScoutingScreen(),
                        ),
                      );
                    },
                ),
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
          if (_showClusteredReportButton)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: _isSavingReport ? null : _createClusteredReport,
                icon: _isSavingReport
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _wasThresholdTriggered
                            ? Icons.warning_amber_rounded
                            : Icons.assignment_turned_in_rounded,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSavingReport
                      ? 'Saving Clustered Report...'
                      : (_wasThresholdTriggered
                          ? 'Create High-Level Clustered Report'
                          : 'Create Low-Level Clustered Report'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _wasThresholdTriggered
                      ? const Color(0xFFC62828)
                      : kActionGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  minimumSize: const Size(double.infinity, 54),
                ),
              ),
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

  bool get _isChemicalEligibleForSelectedWeek =>
      !_isWeekLoading && _loadedWeekIndex == _selectedWeek &&
      isChemicalTaskEligible(
        controlMethod: _selectedControlMethod,
        startWeek: _chemicalControlStartWeek,
        weekNumber: _selectedWeek + 1,
        isFutureWeek: _isCurrentWeekLocked,
        stations: _stationData,
      );

  List<Map<String, dynamic>> _getChemicalTasksForWeek(int weekNumber) {
  if (_isWeekLoading || _loadedWeekIndex != _selectedWeek ||
      weekNumber != _selectedWeek + 1) {
    return [];
  }
  final chemicalIndex = (_weeklyRecommendedTasks[weekNumber] ?? []).length;
  final completed = _recommendedTaskState[_selectedWeek]?[chemicalIndex] == 'completed';
  if (!_isChemicalEligibleForSelectedWeek && !completed) return [];
  
  final recommendation = _getChemicalRecommendation();
  return [{
      'title': recommendation['title'] ?? 'Apply Chemical Control',
      'description': recommendation['description'] ?? 'Apply recommended chemical treatment.',
      'icon': Icons.science,
      'category': 'Chemical Control',
      'isChemical': true,
      'details': recommendation['details'],
      'chemicals': recommendation['chemicals'],
      'stage': recommendation['stage'],
    }];
}

  // ========================
  // RECOMMENDED TASKS SECTION
  // ========================
Widget _buildRecommendedTasksSection() {
  final weekNumber = _selectedWeek + 1;
  if (weekNumber > 8) return const SizedBox.shrink();

  final regularTasks = _weeklyRecommendedTasks[weekNumber] ?? [];
  final chemicalTasks = _getChemicalTasksForWeek(weekNumber);
  final allTasks = [...regularTasks, ...chemicalTasks];
  
  final stateMap = _recommendedTaskState[_selectedWeek] ?? {};

  final activeTasks = <MapEntry<int, Map<String, dynamic>>>[];
  final completedTasks = <MapEntry<int, Map<String, dynamic>>>[];

  for (int i = 0; i < allTasks.length; i++) {
    final status = stateMap[i];
    // Keep original indices so saved completion/removal states remain valid.
    if (allTasks[i]['requiresChemicalEligibility'] == true &&
        !_isChemicalEligibleForSelectedWeek && status != 'completed') {
      continue;
    }
    if (status == 'deleted') continue;
    if (status == 'completed') {
      completedTasks.add(MapEntry(i, allTasks[i]));
    } else {
      activeTasks.add(MapEntry(i, allTasks[i]));
    }
  }

  final visibleCount = activeTasks.length + completedTasks.length;
  if (visibleCount == 0) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: _selectedControlMethod == 'chemical' 
                    ? const Color(0xFFC62828)
                    : const Color(0xFFF9A825),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _selectedControlMethod == 'chemical'
                  ? 'Chemical Control Tasks'
                  : 'Recommended for Week $weekNumber',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: _selectedControlMethod == 'chemical'
                    ? const Color(0xFFC62828)
                    : kTextDark,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _selectedControlMethod == 'chemical'
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${completedTasks.length}/${visibleCount}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _selectedControlMethod == 'chemical'
                      ? const Color(0xFFC62828)
                      : const Color(0xFFF57F17),
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
          _selectedControlMethod == 'chemical'
              ? 'System-recommended chemical applications based on current crop stage'
              : 'System recommendations — mark done or remove as needed',
          style: GoogleFonts.inter(fontSize: 12, color: kTextGrey),
        ),
      ),
      const SizedBox(height: 12),

      if (activeTasks.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: activeTasks.map((entry) {
              final isChemical = entry.value['isChemical'] == true;
              return _buildRecommendedTaskCard(
                taskIndex: entry.key,
                task: entry.value,
                isCompleted: false,
                isChemical: isChemical,
              );
            }).toList(),
          ),
        ),

      if (completedTasks.isNotEmpty) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: completedTasks.map((entry) {
              final isChemical = entry.value['isChemical'] == true;
              return _buildRecommendedTaskCard(
                taskIndex: entry.key,
                task: entry.value,
                isCompleted: true,
                isChemical: isChemical,
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
  bool isChemical = false,
}) {
  final isChemicalTask = isChemical || task['isChemical'] == true;
  
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
            : isChemicalTask
                ? const Color(0xFFFFCDD2)
                : const Color(0xFFFFF9C4),
        width: isChemicalTask ? 2 : 1.5,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFFE8F5E9)
                : isChemicalTask
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFFFFDE7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isChemicalTask ? Icons.science : (task['icon'] as IconData? ?? Icons.task),
            color: isCompleted
                ? const Color(0xFF2E7D32)
                : isChemicalTask
                    ? const Color(0xFFC62828)
                    : const Color(0xFFF9A825),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),

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
                            : isChemicalTask
                                ? const Color(0xFFC62828)
                                : kTextDark,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFE8F5E9)
                          : isChemicalTask
                              ? const Color(0xFFFFEBEE)
                              : kLightGreenBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task['category'] as String? ?? 
                          (isChemicalTask ? 'Chemical Control' : 'General'),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isCompleted
                            ? const Color(0xFF2E7D32).withValues(alpha: 0.6)
                            : isChemicalTask
                                ? const Color(0xFFC62828)
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
                if (isChemicalTask && task['details'] != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task['details']!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
                if (isChemicalTask && task['chemicals'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Options: ${(task['chemicals'] as List).join(', ')}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFC62828),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),

              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final newStatus =
                          isCompleted ? 'active' : 'completed';
                      setState(() {
                        _recommendedTaskState[_selectedWeek] ??= {};
                        _recommendedTaskState[_selectedWeek]![taskIndex] =
                            newStatus;
                      });
                      await _saveRecommendedTaskState(_selectedWeek);
                      if (!isCompleted && isChemicalTask) {
                        _logChemicalApplicationToDailyLog(task);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.grey.shade200
                            : isChemicalTask
                                ? const Color(0xFFC62828)
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
                            isCompleted ? 'Undo' : 'Apply & Complete',
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

                  GestureDetector(
                    onTap: () async {
                      setState(() {
                        _recommendedTaskState[_selectedWeek] ??= {};
                        _recommendedTaskState[_selectedWeek]![taskIndex] =
                            'deleted';
                      });
                      await _saveRecommendedTaskState(_selectedWeek);
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

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            children: weekDays.map((globalDayIndex) {
              final isSelected = globalDayIndex == _dailySelectedDay;
              final isLocked = globalDayIndex > _currentDayFromPlanting;
              final dayNumber = globalDayIndex + 1;
              final dayDate = _getDayDate(globalDayIndex);
              final dayLabel = DateFormat('EEE').format(dayDate);

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
                          currentDayIndex: _dailySelectedDay,
                          plantingDate: _plantingDate,
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
                    child: const Icon(Icons.add, size: 18, color: kActionGreen),
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
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF90CAF9), width: 1),
                  ),
                  child: DatabaseImage(source: images.first),
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
  final plantsInspected = data['plantsInspected'] as int? ?? 0;
  final needsVerification = data['verificationRequired'] as bool? ?? false;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    margin: const EdgeInsets.only(bottom: 12),
    padding: isExpanded ? const EdgeInsets.all(20) : const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(isExpanded ? 20 : 16),
      border: Border.all(
        color: isExpanded ? const Color(0xFF1B4332) : kBorderColor.withValues(alpha: 0.6),
        width: isExpanded ? 1.5 : 1,
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
                    : (isExpanded ? const Color(0xFF1B4332) : const Color(0xFFE0E0E0)),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Color.fromARGB(255, 23, 94, 27))
                    : Text(
                        stationNumber,
                        style: TextStyle(
                          color: isExpanded ? Colors.white : kTextGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: isExpanded ? FontWeight.w700 : FontWeight.w600,
                    fontSize: isExpanded ? 16 : 14,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'COMPLETED',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 49, 114, 51),
                    ),
                  ),
                ),
              if (isCompleted) const SizedBox(width: 8),
              AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: isExpanded ? 0.5 : 0.0,
                child: const Icon(Icons.keyboard_arrow_down, color: kTextGrey),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: AbsorbPointer(
            absorbing: isLocked || isCompleted,
            child: Opacity(
              opacity: isLocked || isCompleted ? 0.45 : 1.0,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // PLANTS INSPECTED
                  _buildPlantsInspectedSection(
                    plantsInspected: plantsInspected,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // PESTS FOUND
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PESTS FOUND',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPestCounterCard(
                              label: 'EGG MASSES',
                              value: data['eggMasses'] as int? ?? 0,
                              onDecrement: () => _decrement(index, 'eggMasses'),
                              onIncrement: () => _increment(index, 'eggMasses'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPestCounterCard(
                              label: 'LARVAE',
                              value: data['larvae'] as int? ?? 0,
                              onDecrement: () => _decrement(index, 'larvae'),
                              onIncrement: () => _increment(index, 'larvae'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPestCounterCard(
                              label: 'PUPAE',
                              value: data['pupae'] as int? ?? 0,
                              onDecrement: () => _decrement(index, 'pupae'),
                              onIncrement: () => _increment(index, 'pupae'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPestCounterCard(
                              label: 'MOTHS',
                              value: data['moths'] as int? ?? 0,
                              onDecrement: () => _decrement(index, 'moths'),
                              onIncrement: () => _increment(index, 'moths'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // DAMAGED PLANT
                  _buildDamagedPlantSection(
                    damagedCount: data['damaged'] as int? ?? 0,
                    onDecrement: () => _decrement(index, 'damaged'),
                    onIncrement: () => _increment(index, 'damaged'),
                  ),
                  
                  const SizedBox(height: 16),

                  _buildDamageAssessmentSection(index, data),

                  const SizedBox(height: 16),
                  
                  _buildEditableNotesBox(
                    notes: data['notes'] as String? ?? '',
                    onChanged: (val) => _updateNotes(index, val),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Verify button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isLocked ? null : () => _verifyPestObservations(index, data),
                          icon: Icon(
                            Icons.verified_outlined, 
                            size: 18,
                            color: needsVerification ? Colors.white : Colors.white,
                          ),
                          label: Text(
                            needsVerification ? 'Verify Now' : 'Verify',
                            style: TextStyle(
                              color: needsVerification ? Colors.white : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: needsVerification ? Colors.orange : kActionGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Warning: Needs verification
                  if (needsVerification && !(data['verificationCompleted'] as bool? ?? false))
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verification required: Please verify observed pests before completing',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Show warning if plants inspected < 10 (not at max)
                  if (plantsInspected < 10 && !isCompleted)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please inspect all 10 plants (${10 - plantsInspected} remaining)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (isLocked || 
                          plantsInspected < 10 ||
                          (needsVerification && !(data['verificationCompleted'] as bool? ?? false)))
                          ? null
                          : () => _completeStation(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCompleted ? Colors.white : kActionGreen,
                        disabledBackgroundColor: const Color(0xFFE0E0E0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: isCompleted ? const BorderSide(color: kActionGreen) : BorderSide.none,
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCompleted ? Icons.update_outlined : Icons.check_circle_outline,
                            color: isLocked ? kTextGrey : (isCompleted ? kActionGreen : Colors.white),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isCompleted ? 'Update Station' : 'Complete Station',
                            style: GoogleFonts.inter(
                              color: isLocked ? kTextGrey : (isCompleted ? kActionGreen : Colors.white),
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
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    ),
  );
}

  // ========================
  // FAW DAMAGE ASSESSMENT UI (per TNAU 1-5 Guideline)
  // ========================

Widget _buildDamageAssessmentSection(int stationIndex, Map<String, dynamic> station) {
  if (!_hasFAWPresence(station)) return const SizedBox.shrink();
  final damaged = station['damaged'] as int? ?? 0;
  if (damaged <= 0) return const SizedBox.shrink();

  final assessmentType = getFAWAssessmentType(_selectedDayDap);
  final choice = station['damageAssessmentChoice'] as String?;

  Widget content;
  if (assessmentType == FAWAssessmentType.transitional && choice == null) {
    content = _buildTasselingChoicePrompt(stationIndex);
  } else {
    final effectiveChoice = assessmentType == FAWAssessmentType.transitional
        ? choice!
        : (assessmentType == FAWAssessmentType.whorl ? 'whorl' : 'cob');
    final rows = _ensureDamageScoreRows(stationIndex);
    content = _buildPlantScoringTable(stationIndex, rows, effectiveChoice, assessmentType);
  }

  return Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F0FA),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD1C4E9), width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.grading_outlined, color: Color(0xFF6A1B9A), size: 16),
            const SizedBox(width: 6),
            Text(
              'Plant Damage Assessment',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: const Color(0xFF6A1B9A),
              ),
            ),
            if (damaged > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$damaged plants',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC62828),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Score each damaged plant (1-5)',
          style: GoogleFonts.inter(fontSize: 10, color: kTextGrey),
        ),
        const SizedBox(height: 8),
        content,
      ],
    ),
  );
}

Widget _buildTasselingChoicePrompt(int stationIndex) {
  Widget optionChip(String label, String value) {
    return GestureDetector(
      onTap: () => _setDamageAssessmentChoice(stationIndex, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.only(right: 6, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6A1B9A)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF6A1B9A),
          ),
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Where is the fresh FAW damage observed?',
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Wrap(children: [
        optionChip('Whorl / Leaves', 'whorl'),
        optionChip('Cob / Ear', 'cob'),
        optionChip('Both', 'both'),
      ]),
    ],
  );
}

Widget _buildPlantScoringTable(
  int stationIndex,
  List<Map<String, dynamic>> rows,
  String type,
  FAWAssessmentType assessmentType,
) {
  final showWhorl = type == 'whorl' || type == 'both';
  final showCob = type == 'cob' || type == 'both';

  int scoredCount = rows.where((r) =>
      (!showWhorl || r['whorlScore'] != null) &&
      (!showCob || r['cobScore'] != null)).length;

  final allScores = <int>[];
  for (final r in rows) {
    if (showWhorl && r['whorlScore'] != null) allScores.add(r['whorlScore'] as int);
    if (showCob && r['cobScore'] != null) allScores.add(r['cobScore'] as int);
  }
  final avg = allScores.isEmpty
      ? 0.0
      : allScores.reduce((a, b) => a + b) / allScores.length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (assessmentType == FAWAssessmentType.transitional)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _setDamageAssessmentChoice(stationIndex, null),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Change selection', style: TextStyle(fontSize: 11)),
          ),
        ),
      // Use a ListView.builder with shrinkWrap for better space management
      ...rows.asMap().entries.map((entry) {
        final i = entry.key;
        final row = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorderColor, width: 0.5),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'Plant ${row['plantNumber']}',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: kTextDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showWhorl) ...[
                if (type == 'both')
                  SizedBox(
                    width: 36,
                    child: Text(
                      'Whorl',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: kTextGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: _buildCompactScoreSelector(
                    value: row['whorlScore'] as int?,
                    onSelect: (v) => _setPlantDamageScore(stationIndex, i, 'whorlScore', v),
                  ),
                ),
                if (showCob && type == 'both') const SizedBox(width: 8),
              ],
              if (showCob) ...[
                if (type == 'both')
                  SizedBox(
                    width: 32,
                    child: Text(
                      'Cob',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: kTextGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Expanded(
                  flex: 2,
                  child: _buildCompactScoreSelector(
                    value: row['cobScore'] as int?,
                    onSelect: (v) => _setPlantDamageScore(stationIndex, i, 'cobScore', v),
                  ),
                ),
              ],
            ],
          ),
        );
      }),
      const SizedBox(height: 6),
      // Compact stats row
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _damageStatChipCompact('Damaged', '${rows.length}'),
          _damageStatChipCompact('Scored', '$scoredCount'),
          _damageStatChipCompact('Avg', avg > 0 ? avg.toStringAsFixed(1) : '-',
              color: const Color(0xFFC62828)),
        ],
      ),
      const SizedBox(height: 8),
      // Scoring guide with compact layout
      if (showWhorl) _buildCompactScoringGuide('WHORL', kWhorlLeafDamageScale),
      if (showWhorl && showCob) const SizedBox(height: 4),
      if (showCob) _buildCompactScoringGuide('EAR COB', kCobDamageScale),
    ],
  );
}

Widget _buildCompactScoreSelector({
  required int? value,
  required ValueChanged<int> onSelect,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(5, (i) {
      final score = i + 1;
      final selected = value == score;
      return GestureDetector(
        onTap: () => onSelect(score),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFC62828) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? const Color(0xFFC62828) : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            '$score',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: selected ? Colors.white : kTextDark,
            ),
          ),
        ),
      );
    }),
  );
}

Widget _damageStatChipCompact(String label, String value, {Color? color}) {
  return Row(
    children: [
      Text(
        '$label: ',
        style: GoogleFonts.inter(
          fontSize: 10,
          color: kTextGrey,
          fontWeight: FontWeight.w500,
        ),
      ),
      Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color ?? kTextDark,
        ),
      ),
    ],
  );
}

Widget _buildCompactScoringGuide(String title, List<Map<String, String>> scale) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.info_outline, size: 12, color: kTextGrey),
            const SizedBox(width: 4),
            Text(
              'FAW DAMAGE SCORING GUIDE ($title)',
              style: GoogleFonts.inter(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: kTextGrey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 2,
          runSpacing: 0,
          children: scale.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 0.5),
            child: Text(
              '${s['score']}: ${s['label']}',
              style: GoogleFonts.inter(
                fontSize: 9,
                color: kTextDark,
                height: 1.2,
              ),
            ),
          )).toList(),
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
  Widget _buildPlantsInspectedSection({
    required int plantsInspected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLANTS INSPECTED',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF0FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD6E4F0), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            '$plantsInspected',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPestCounterCard({
    required String label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E4F0), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onDecrement,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(Icons.remove, size: 16, color: Color(0xFF64748B)),
                ),
              ),
              Text(
                '$value',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: onIncrement,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Icon(Icons.add, size: 16, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDamagedPlantSection({
    required int damagedCount,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAMAGED PLANT',
          style: GoogleFonts.inter(
            fontSize: 10,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD6E4F0), width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF0FA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 18, color: Color(0xFF334155)),
                ),
              ),
              Text(
                '$damagedCount',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF0FA),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 18, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),
        ),
      ],
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
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
                'Explore detailed steps for each management strategy based on environmental impact.',
                style: GoogleFonts.inter(fontSize: 14, color: kTextGrey)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _selectControlMethod('biological'),
              child: _modalOption(
                  Icons.bug_report,
                  'Biological Control',
                  'Utilize natural predators and parasitoids to manage pests with zero chemical footprint.',
                  false,
                  const Color(0xFF2E7D32)),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _selectControlMethod('chemical'),
              child: _modalOption(
                  Icons.science_outlined,
                  'Chemical Control',
                  'Targeted synthetic applications. Recommended only as a last resort for acute infestations.',
                  true,
                  const Color(0xFFC62828)),
            ),
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
      IconData icon, String title, String desc, bool rec, Color accentColor) {
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
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  radius: 18,
                  child: Icon(icon, color: accentColor, size: 20)),
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
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('RECOMMENDED',
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

  Future<void> _updateCycleGrowthStage() async {
  try {
    final currentDap = _currentDayFromPlanting;
    final growthInfo = getGrowthStage(currentDap);
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .update({
      'currentDap': currentDap,
      'currentGrowthStage': growthInfo.name,
      'currentGrowthStageScore': growthInfo.vulnerabilityScore,
      'currentRiskLabel': growthInfo.riskLabel,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    print('Error updating growth stage: $e');
  }
}

double? _averageScore(Iterable<int> values) {
  final list = values.toList();
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

// Add this method to get all captured images from stations
Map<String, List<String>> _getAllCapturedImages() {
  final allImages = <String, List<String>>{};
  
  for (final station in _stationData) {
    final stationTitle = station['title'] as String? ?? 'Unknown';
    final capturedImages = station['capturedImages'] as Map<String, dynamic>? ?? {};
    
    // Get pest images
    final eggImages = List<String>.from(capturedImages['eggMasses'] ?? []);
    final larvaeImages = List<String>.from(capturedImages['larvae'] ?? []);
    final pupaeImages = List<String>.from(capturedImages['pupae'] ?? []);
    final mothImages = List<String>.from(capturedImages['moths'] ?? []);
    final damageImages = List<String>.from(capturedImages['damage'] ?? []);
    
    // Also check direct damagePhotos field
    final directDamagePhotos = List<String>.from(station['damagePhotos'] ?? []);
    final allDamagePhotos = [...damageImages, ...directDamagePhotos];
    
    // Store images with station context
    allImages['${stationTitle}_eggMasses'] = eggImages;
    allImages['${stationTitle}_larvae'] = larvaeImages;
    allImages['${stationTitle}_pupae'] = pupaeImages;
    allImages['${stationTitle}_moths'] = mothImages;
    allImages['${stationTitle}_damage'] = allDamagePhotos;
  }
  
  return allImages;
}

// ─── Plant Damage Report ─────────────────────────────────────────────
Future<void> _createPlantDamageReport(DateTime reportDate, int weekNumber) async {
  final dap = scoutingReportDap(_plantingDate!, reportDate);
  final growthInfo = getGrowthStage(dap);

  int totalInspected = _stationData.fold(0, (sum, s) => sum + (s['plantsInspected'] as int? ?? 0));
  double damagePercent = totalInspected > 0 ? (_totalDamaged / totalInspected) * 100 : 0.0;

  // Collect per-plant damage scores and damage photos across all stations
  final allPlantScores = <Map<String, dynamic>>[];
  final allDamagePhotos = <String>[];
  final stationBreakdown = <Map<String, dynamic>>[];

  for (final station in _stationData) {
    final scores = (station['plantDamageScores'] as List?) ?? [];
    for (final sc in scores) {
      final whorlScore = sc['whorlScore'];
      final cobScore = sc['cobScore'];
      if (whorlScore != null || cobScore != null) {
        allPlantScores.add({
          'station': station['title'],
          'plantNumber': sc['plantNumber'],
          'whorlScore': whorlScore,
          'cobScore': cobScore,
        });
      }
    }

    // Aggregate damage photos from capturedImages['damage'] and damagePhotos
    final capturedDamage = List<String>.from(station['capturedImages']?['damage'] ?? []);
    final directDamagePhotos = List<String>.from(station['damagePhotos'] ?? []);
    final stationPhotos = [...capturedDamage, ...directDamagePhotos];
    allDamagePhotos.addAll(stationPhotos);

    final stationDamaged = station['damaged'] as int? ?? 0;
    final stationInspected = station['plantsInspected'] as int? ?? 0;
    if (stationDamaged > 0 || stationInspected > 0) {
      stationBreakdown.add({
        'station': station['title'],
        'damaged': stationDamaged,
        'plantsInspected': stationInspected,
        'damagePhotos': stationPhotos,
        'plantDamageScores': scores,
        'notes': station['notes'] ?? '',
      });
    }
  }

  final avgWhorlScore = _averageScore(
      allPlantScores.where((e) => e['whorlScore'] != null).map((e) => e['whorlScore'] as int));
  final avgCobScore = _averageScore(
      allPlantScores.where((e) => e['cobScore'] != null).map((e) => e['cobScore'] as int));

  final reportData = {
    'userId': _userId,
    'cycleId': widget.cycleId,
    'cycleName': _cycleName,
    'farmId': _farmId,
    'fieldId': _fieldId,
    'farmerId': _farmerId,
    'farmName': _farmName,
    'fieldName': _fieldName,
    'farmerName': _farmerName,
    'weekNumber': weekNumber,
    'dap': dap,
    'growthStage': growthInfo.name,
    'totalDamaged': _totalDamaged,
    'totalInspected': totalInspected,
    'damagePercentage': damagePercent,
    'allDamagePhotos': allDamagePhotos,
    'plantDamageScores': allPlantScores,
    'averageWhorlScore': avgWhorlScore,
    'averageCobScore': avgCobScore,
    'stationBreakdown': stationBreakdown,
    'status': 'pending',
    'reportDate': Timestamp.fromDate(reportDate),
    'timestamp': Timestamp.fromDate(reportDate),
    'createdAt': Timestamp.fromDate(reportDate),
    'submittedAt': FieldValue.serverTimestamp(),
  };

  await FirebaseFirestore.instance
      .collection('plant_damage_reports')
      .add(reportData);
}

// ─── Clustered Report ────────────────────────────────────────────────
Future<void> _createClusteredReport() async {
  if (_isSavingReport) return;
  setState(() => _isSavingReport = true);

  try {
    int totalInspected = _stationData.fold(0, (sum, s) => sum + (s['plantsInspected'] as int? ?? 0));
    double damagePercent = totalInspected > 0 ? (_totalDamaged / totalInspected) * 100 : 0.0;
    final bool exceedsThreshold = damagePercent >= 10.0;
    final String reportLevel = exceedsThreshold ? 'High' : 'Low';
    final String severityLevel = exceedsThreshold ? 'High Level' : 'Low Level';

    final weekNumber = _selectedWeek + 1;
    final reportDate = scoutingReportDate(
      plantingDate: _plantingDate!,
      weekIndex: _selectedWeek,
      submittedAt: DateTime.now(),
    );
    final reportDap = scoutingReportDap(_plantingDate!, reportDate);
    final growthInfo = getGrowthStage(reportDap);

    String larvaRiskLevel = 'None';
    if (_totalLarvae > 0) {
      if (growthInfo.stage == GrowthStage.seedling) {
        larvaRiskLevel = 'Low';
      } else if (growthInfo.stage == GrowthStage.earlyVegetative) {
        larvaRiskLevel = 'Medium';
      } else {
        larvaRiskLevel = 'High';
      }
    }

    String mothRiskLevel = _totalMoths > 0 ? 'High' : 'None';

    final fieldLocation = await _getFieldLocation();

    // ─── FAW Damage Assessment summary ──────────────────────────────────
    final allPlantScores = <Map<String, dynamic>>[];
    for (final s in _stationData) {
      final scores = (s['plantDamageScores'] as List?) ?? [];
      for (final sc in scores) {
        final whorlScore = sc['whorlScore'];
        final cobScore = sc['cobScore'];
        if (whorlScore != null || cobScore != null) {
          allPlantScores.add({
            'station': s['title'],
            'plantNumber': sc['plantNumber'],
            'damageType': s['damageAssessmentChoice'] ?? _damageTypeLabelForDap(),
            'whorlScore': whorlScore,
            'cobScore': cobScore,
          });
        }
      }
    }
    final avgWhorlScore = _averageScore(
        allPlantScores.where((e) => e['whorlScore'] != null).map((e) => e['whorlScore'] as int));
    final avgCobScore = _averageScore(
        allPlantScores.where((e) => e['cobScore'] != null).map((e) => e['cobScore'] as int));

    // ─── Get all captured images ────────────────────────────────────────
    final allCapturedImages = _getAllCapturedImages();

    // ─── Build report data ──────────────────────────────────────────────
    Map<String, dynamic> reportData = {
      // IDs to connect to other collections
      'userId': _userId,
      'cycleId': widget.cycleId,
      'farmId': _farmId,
      'fieldId': _fieldId,
      'farmerId': _farmerId,
      
      // Names for display
      'farmName': _farmName,
      'fieldName': _fieldName,
      'farmerName': _farmerName,
      'cycleName': _cycleName,
      
      // Report data
      'timestamp': Timestamp.fromDate(reportDate),
      'reportDate': Timestamp.fromDate(reportDate),
      'submittedAt': FieldValue.serverTimestamp(),
      'plantingDate': Timestamp.fromDate(_plantingDate!),
      'weekNumber': weekNumber, 
      'dap': reportDap,
      'growthStage': growthInfo.name,
      'growthStageScore': growthInfo.vulnerabilityScore,
      'totalDamaged': _totalDamaged,
      'totalInspected': totalInspected,
      'damagePercentage': damagePercent,
      'exceedsThreshold': exceedsThreshold,
      'reportLevel': reportLevel,
      'severityLevel': severityLevel,
      'level': reportLevel.toLowerCase(),
      'isHighLevel': exceedsThreshold,
      'totals': {
        'eggs': _totalEggs,
        'larvae': _totalLarvae,
        'pupae': _totalPupae,
        'moths': _totalMoths,
      },
      'larvaRisk': {
        'present': _totalLarvae > 0,
        'riskLevel': larvaRiskLevel,
        'riskType': 'Infestation/Destruction',
      },
      'mothRisk': {
        'present': _totalMoths > 0,
        'riskLevel': mothRiskLevel,
        'riskType': 'Spread',
      },
      // ─── ADD CAPTURED IMAGES ──────────────────────────────────────────
      'capturedImages': allCapturedImages,
      // FAW plant damage assessment
      'damageAssessment': {
        'plantScores': allPlantScores,
        'averageWhorlLeafScore': avgWhorlScore,
        'averageCobScore': avgCobScore,
        'validationStatus': 'pending',
      },
      'location': fieldLocation != null
          ? {
              'lat': fieldLocation.latitude,
              'lng': fieldLocation.longitude,
            }
          : null,
      'stationsData': _stationData.map((s) => {
        'title': s['title'],
        'completed': s['completed'],
        'plantsInspected': s['plantsInspected'],
        'damaged': s['damaged'],
        'eggMasses': s['eggMasses'],
        'larvae': s['larvae'],
        'pupae': s['pupae'],
        'moths': s['moths'],
        'notes': s['notes'],
        'damageAssessmentChoice': s['damageAssessmentChoice'],
        'plantDamageScores': s['plantDamageScores'],
        // Include image count for reference
        'imageCount': {
          'eggMasses': (s['capturedImages']?['eggMasses'] as List?)?.length ?? 0,
          'larvae': (s['capturedImages']?['larvae'] as List?)?.length ?? 0,
          'pupae': (s['capturedImages']?['pupae'] as List?)?.length ?? 0,
          'moths': (s['capturedImages']?['moths'] as List?)?.length ?? 0,
          'damage': (s['capturedImages']?['damage'] as List?)?.length ?? 0,
        },
      }).toList(),
      
      // Control method info
      'controlMethod': _selectedControlMethod,
      'trapsInstalled': _trapsInstalled,
      
      // Status for validation
      'status': 'pending',
      'createdAt': Timestamp.fromDate(reportDate),
    };

    // ─── Save to top-level clustered_reports collection ────────────────
    await FirebaseFirestore.instance
        .collection('clustered_reports')
        .add(reportData);

    // ─── Save plant damage report ─────────────────────────────────────
    await _createPlantDamageReport(reportDate, weekNumber);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(exceedsThreshold
              ? '✅ High-level clustered report and plant damage report saved successfully!'
              : '✅ Low-level clustered report and plant damage report saved successfully!'),
          backgroundColor: kActionGreen,
        ),
      );
      setState(() {
        _showClusteredReportButton = false;
        _isSavingReport = false;
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() => _isSavingReport = false);
  }
}

String _damageTypeLabelForDap() {
  final type = getFAWAssessmentType(_selectedDayDap);
  switch (type) {
    case FAWAssessmentType.whorl:
      return 'whorl';
    case FAWAssessmentType.cob:
      return 'cob';
    case FAWAssessmentType.transitional:
      return 'unspecified';
  }
}
}
