import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/screens/logging_screens/assign_log_modal.dart';
import 'dart:convert';

// ─── Activity Type Model ──────────────────────────────────────────────────────

enum ActivityType {
  watering,
  fertilizing,
  pestControl,
  harvesting,
  planting,
  pruning,
  soilPrep,
  irrigation,
  other,
}

extension ActivityTypeExt on ActivityType {
  String get label {
    switch (this) {
      case ActivityType.watering:
        return 'Watering';
      case ActivityType.fertilizing:
        return 'Fertilizing';
      case ActivityType.pestControl:
        return 'Pest Control';
      case ActivityType.harvesting:
        return 'Harvesting';
      case ActivityType.planting:
        return 'Planting';
      case ActivityType.pruning:
        return 'Pruning';
      case ActivityType.soilPrep:
        return 'Soil Preparation';
      case ActivityType.irrigation:
        return 'Irrigation';
      case ActivityType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityType.watering:
        return Icons.water_drop_outlined;
      case ActivityType.fertilizing:
        return Icons.science_outlined;
      case ActivityType.pestControl:
        return Icons.pest_control_outlined;
      case ActivityType.harvesting:
        return Icons.agriculture_outlined;
      case ActivityType.planting:
        return Icons.eco_outlined;
      case ActivityType.pruning:
        return Icons.content_cut_outlined;
      case ActivityType.soilPrep:
        return Icons.layers_outlined;
      case ActivityType.irrigation:
        return Icons.waves_outlined;
      case ActivityType.other:
        return Icons.more_horiz_rounded;
    }
  }
}

// ─── Daily Log Form Screen ────────────────────────────────────────────────────

class DailyLogFormScreen extends StatefulWidget {
  final String userId;
  final String cycleId;
  final bool shouldAssignCycle;
  final int? currentDayIndex;
  final DateTime? plantingDate;

  const DailyLogFormScreen({
    super.key,
    required this.userId,
    required this.cycleId,
    required this.shouldAssignCycle,
    this.currentDayIndex,
    this.plantingDate,
  });

  @override
  State<DailyLogFormScreen> createState() => _DailyLogFormScreenState();
}

class _DailyLogFormScreenState extends State<DailyLogFormScreen>
    with SingleTickerProviderStateMixin {
  // Form state
  DateTime _selectedDate = DateTime.now();
  ActivityType? _selectedActivity;
  final TextEditingController _notesController = TextEditingController();
  List<XFile> _pickedImages = [];
  bool _isCompleted = false;
  bool _isSaving = false;
  
  // Schedule state
  bool _isScheduled = false;
  TimeOfDay? _scheduledTime;
  DateTime? _scheduledDate;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final ImagePicker _picker = ImagePicker();

  // Colors
  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _bgColor = Color(0xFFF4F8F5);
  static const _mutedText = Color(0xFF9E9E9E);
  static const _borderColor = Color(0xFFDDEEE4);

  @override
  void initState() {
    super.initState();
    
    // If planting date and current day index are provided, set the selected date
    if (widget.plantingDate != null && widget.currentDayIndex != null) {
      _selectedDate = widget.plantingDate!.add(Duration(days: widget.currentDayIndex!));
    }
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    // Set default scheduled date to tomorrow
    _scheduledDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _darkGreen,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _green),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _darkGreen,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _green),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickScheduleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _darkGreen,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _green),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);
    if (images.isNotEmpty) {
      setState(() {
        _pickedImages = [..._pickedImages, ...images];
      });
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  Future<String?> _uploadImage(XFile image) async {
    try {
      final bytes = await File(image.path).readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('Error converting image: $e');
      return null;
    }
  }

  Future<void> _createScheduledActivityNotification(String cycleId, String activityId) async {
    if (_scheduledDate == null || _scheduledTime == null) return;
    
    final scheduledDateTime = DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );
    
    await FirebaseFirestore.instance
        .collection('alerts')
        .add({
      'alertType': 'scheduled_activity',
      'title': 'Upcoming Activity: ${_selectedActivity!.label}',
      'message': 'You have a scheduled ${_selectedActivity!.label} activity for ${DateFormat('MMM d, yyyy').format(scheduledDateTime)} at ${_scheduledTime!.format(context)}.\n\nActivity: ${_notesController.text.isNotEmpty ? _notesController.text : 'No additional notes'}',
      'farmerId': widget.userId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'unread',
      'source': 'daily_log',
      'risk': 'Low',
      'activityId': activityId,
      'cycleId': cycleId,
      'scheduledFor': Timestamp.fromDate(scheduledDateTime),
      'activityType': _selectedActivity!.label,
      'severity': 'Scheduled',
    });
  }

  Future<void> _saveActivityToFirestore() async {
    if (_selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activity type')),
      );
      return;
    }

    if (!_isCompleted && (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a schedule time for this activity')),
      );
      return;
    }

    if (widget.cycleId.isNotEmpty && !widget.shouldAssignCycle) {
      setState(() => _isSaving = true);
      try {
        final activityId = await _saveToCycle(widget.cycleId);
        if (_isScheduled && activityId != null) {
          await _createScheduledActivityNotification(widget.cycleId, activityId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isCompleted 
                  ? 'Activity saved successfully!' 
                  : 'Activity scheduled! You\'ll be notified when it\'s time.',
              ),
              backgroundColor: const Color(0xFF1A5C30),
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      _openAssignModal();
    }
  }

  Future<String?> _saveToCycle(String cycleId) async {
    final imageUrls = <String>[];

    for (final image in _pickedImages) {
      final url = await _uploadImage(image);
      if (url != null) imageUrls.add(url);
    }

    final cycleDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cycles')
        .doc(cycleId)
        .get();
    
    if (!cycleDoc.exists) {
      throw Exception('Cycle not found');
    }
    
    final plantingDate = (cycleDoc.data()?['plantingDate'] as Timestamp?)?.toDate();
    final harvestDate = (cycleDoc.data()?['harvestDate'] as Timestamp?)?.toDate();
    
    if (plantingDate == null || harvestDate == null) {
      throw Exception('Planting or harvest date not found');
    }
    
    if (_selectedDate.isBefore(plantingDate) || _selectedDate.isAfter(harvestDate)) {
      throw Exception('Activity date must be between ${DateFormat('MMM d').format(plantingDate)} and ${DateFormat('MMM d').format(harvestDate)}');
    }
    
    final daysSincePlanting = _selectedDate.difference(plantingDate).inDays;
    final dayNumber = daysSincePlanting + 1;
    final dayId = 'day_${dayNumber.toString().padLeft(2, '0')}';

    final activityId = DateTime.now().millisecondsSinceEpoch.toString();
    final activityData = {
      'id': activityId,
      'type': _selectedActivity!.label,
      'icon': _selectedActivity!.icon.codePoint,
      'notes': _notesController.text,
      'images': imageUrls,
      'completed': _isCompleted,
      'timestamp': FieldValue.serverTimestamp(),
      'date': Timestamp.fromDate(_selectedDate),
      'dayNumber': dayNumber,
      'cycleId': cycleId,
      'userId': widget.userId,
      'isScheduled': _isScheduled,
      'scheduledFor': _isScheduled && _scheduledDate != null && _scheduledTime != null
          ? Timestamp.fromDate(DateTime(
              _scheduledDate!.year,
              _scheduledDate!.month,
              _scheduledDate!.day,
              _scheduledTime!.hour,
              _scheduledTime!.minute,
            ))
          : null,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cycles')
        .doc(cycleId)
        .collection('dailyLogs')
        .doc(dayId)
        .collection('activities')
        .add(activityData);
        
    return activityId;
  }

  Future<void> _openAssignModal() async {
    showAssignLogSheet(
      context,
      userId: widget.userId,
      cycleId: widget.cycleId,
      onCycleSelected: (cycleId) async {
        if (cycleId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a cycle')),
          );
          return;
        }
        
        setState(() => _isSaving = true);
        try {
          final activityId = await _saveToCycle(cycleId);
          if (_isScheduled && activityId != null) {
            await _createScheduledActivityNotification(cycleId, activityId);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isCompleted 
                    ? 'Activity saved successfully!' 
                    : 'Activity scheduled! You\'ll be notified when it\'s time.',
                ),
                backgroundColor: const Color(0xFF1A5C30),
              ),
            );
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              // ── Custom App Bar ───────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 148,
                pinned: true,
                backgroundColor: _darkGreen,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/bg.png',
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF0C503C).withOpacity(0.78),
                              const Color(0xFF1A5C30).withOpacity(0.72),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Daily Log',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Track what happens on your farm every day — from watering to harvest. One entry at a time builds a complete picture of your season.',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 12,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
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

              // ── Form Body ─────────────────────────────────────────────────
              SliverPadding(
                padding:
                    EdgeInsets.fromLTRB(16, 20, 16, bottomPadding + 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Entry Date ─────────────────────────────────────────
                    _SectionLabel(label: 'Entry Date'),
                    const SizedBox(height: 8),
                    _FormCard(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.09),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.calendar_today_rounded,
                                  color: _green, size: 18),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('EEEE').format(_selectedDate),
                                    style: GoogleFonts.inter(
                                      color: _mutedText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMMM d, yyyy')
                                        .format(_selectedDate),
                                    style: GoogleFonts.inter(
                                      color: _darkGreen,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: _mutedText),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Status (Progress) ──────────────────────────────────
                    _SectionLabel(label: 'Status'),
                    const SizedBox(height: 8),
                    _FormCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _isCompleted = !_isCompleted),
                            child: Row(
                              children: [
                                Icon(
                                  _isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: _isCompleted ? _green : _mutedText,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _isCompleted ? 'Completed' : 'In Progress',
                                  style: GoogleFonts.inter(
                                    color: _isCompleted ? _green : _mutedText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isCompleted) ...[
                            const SizedBox(width: 16),
                            const VerticalDivider(color: _borderColor, thickness: 1, width: 1),
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: () => setState(() => _isScheduled = !_isScheduled),
                              child: Row(
                                children: [
                                  Icon(
                                    _isScheduled 
                                        ? Icons.check_box_rounded 
                                        : Icons.check_box_outline_blank_rounded,
                                    color: _isScheduled ? _green : _mutedText,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Schedule',
                                    style: GoogleFonts.inter(
                                      color: _isScheduled ? _green : _mutedText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Schedule Section (only when in progress and scheduled) ──
                    if (!_isCompleted && _isScheduled) ...[
                      const SizedBox(height: 12),
                      _buildScheduleSection(),
                    ],

                    const SizedBox(height: 20),

                    // ── Activity Type ──────────────────────────────────────
                    _SectionLabel(label: 'Activity Type'),
                    const SizedBox(height: 8),
                    _ActivityGrid(
                      selected: _selectedActivity,
                      onSelect: (type) =>
                          setState(() => _selectedActivity = type),
                    ),

                    const SizedBox(height: 20),

                    // ── Notes ──────────────────────────────────────────────
                    _SectionLabel(label: 'Notes'),
                    const SizedBox(height: 8),
                    _FormCard(
                      padding: EdgeInsets.zero,
                      child: TextField(
                        controller: _notesController,
                        maxLines: 5,
                        style: GoogleFonts.inter(
                          color: _darkGreen,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Describe what was done, any observations, issues noticed…',
                          hintStyle: GoogleFonts.inter(
                            color: _mutedText,
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Image Evidence ─────────────────────────────────────
                    _SectionLabel(label: 'Image Evidence'),
                    const SizedBox(height: 4),
                    Text(
                      'Optional — attach photos of the activity',
                      style: GoogleFonts.inter(
                          color: _mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 10),
                    _ImagePickerSection(
                      images: _pickedImages,
                      onAdd: _pickImages,
                      onRemove: _removeImage,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // ── Next Button ───────────────────────────────────────────────────
        bottomNavigationBar: Container(
          color: _bgColor,
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
          child: GestureDetector(
            onTap: _saveActivityToFirestore,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 54,
              decoration: BoxDecoration(
                gradient: _isSaving
                    ? LinearGradient(
                        colors: [
                          _green.withOpacity(0.5),
                          _darkGreen.withOpacity(0.5),
                        ],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF0C503C), Color(0xFF1A5C30)],
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _green.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _isCompleted ? 'Save Activity' : 'Schedule Activity',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 18),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Schedule Details'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickScheduleDate,
                child: _FormCard(
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: _green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: GoogleFonts.inter(
                                color: _mutedText,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _scheduledDate != null
                                  ? DateFormat('MMM d, yyyy').format(_scheduledDate!)
                                  : 'Select date',
                              style: GoogleFonts.inter(
                                color: _darkGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _mutedText, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _pickScheduleTime,
                child: _FormCard(
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: _green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: GoogleFonts.inter(
                                color: _mutedText,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _scheduledTime != null
                                  ? _scheduledTime!.format(context)
                                  : 'Select time',
                              style: GoogleFonts.inter(
                                color: _darkGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: _mutedText, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: const Color(0xFFF57C00), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You will receive a notification when it\'s time to do this activity.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFE65100),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Supporting Widgets ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: const Color(0xFF0C503C),
        fontWeight: FontWeight.w800,
        fontSize: 10.5,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _FormCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDEEE4), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

// ── Activity Grid ─────────────────────────────────────────────────────────────

class _ActivityGrid extends StatelessWidget {
  final ActivityType? selected;
  final ValueChanged<ActivityType> onSelect;

  const _ActivityGrid({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final types = ActivityType.values;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: types.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (_, i) {
        final type = types[i];
        final isSelected = selected == type;
        return GestureDetector(
          onTap: () => onSelect(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF1A5C30)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1A5C30)
                    : const Color(0xFFDDEEE4),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1A5C30).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [
                      const BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      )
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type.icon,
                  color: isSelected ? Colors.white : const Color(0xFF1A5C30),
                  size: 24,
                ),
                const SizedBox(height: 6),
                Text(
                  type.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: isSelected ? Colors.white : const Color(0xFF0C503C),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Image Picker Section ──────────────────────────────────────────────────────

class _ImagePickerSection extends StatelessWidget {
  final List<XFile> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImagePickerSection({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add button
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 90,
              height: 90,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFDDEEE4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined,
                      color: Color(0xFF1A5C30), size: 26),
                  const SizedBox(height: 4),
                  Text(
                    'Add Photo',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF1A5C30),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Picked images
          ...images.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFDDEEE4), width: 1.2),
                    image: DecorationImage(
                      image: FileImage(File(file.path)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 14,
                  child: GestureDetector(
                    onTap: () => onRemove(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: Colors.red),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}