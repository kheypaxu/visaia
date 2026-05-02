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

  const DailyLogFormScreen({
    super.key,
    required this.userId,
    required this.cycleId,
    required this.shouldAssignCycle,
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
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
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

  Future<void> _saveActivityToFirestore() async {
    if (_selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an activity type')),
      );
      return;
    }

    // If we have a cycleId already (from monitoring screen), save directly
    if (widget.cycleId.isNotEmpty && !widget.shouldAssignCycle) {
      setState(() => _isSaving = true);
      try {
        await _saveToCycle(widget.cycleId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activity saved successfully!'),
              backgroundColor: Color(0xFF1A5C30),
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
      // No cycle assigned yet - show assign modal
      _openAssignModal();
    }
  }

  Future<void> _saveToCycle(String cycleId) async {
    final imageUrls = <String>[];

    for (final image in _pickedImages) {
      final url = await _uploadImage(image);
      if (url != null) imageUrls.add(url);
    }

    // Get the cycle document to find planting date
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
    
    // Check if selected date is within cycle range
    if (_selectedDate.isBefore(plantingDate) || _selectedDate.isAfter(harvestDate)) {
      throw Exception('Activity date must be between ${DateFormat('MMM d').format(plantingDate)} and ${DateFormat('MMM d').format(harvestDate)}');
    }
    
    // Calculate days since planting (0-based)
    final daysSincePlanting = _selectedDate.difference(plantingDate).inDays;
    
    // Day number is daysSincePlanting + 1 (1-based for display)
    final dayNumber = daysSincePlanting + 1;
    final dayId = 'day_${dayNumber.toString().padLeft(2, '0')}';

    final activityData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': _selectedActivity!.label,
      'icon': _selectedActivity!.icon.codePoint,
      'notes': _notesController.text,
      'images': imageUrls,
      'completed': _isCompleted,
      'timestamp': FieldValue.serverTimestamp(),
      'date': Timestamp.fromDate(_selectedDate),
      'dayNumber': dayNumber, // Optional: store for reference
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
          await _saveToCycle(cycleId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Activity saved successfully!'),
                backgroundColor: Color(0xFF1A5C30),
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
                      // Background image
                      Image.asset(
                        'assets/images/bg.png',
                        fit: BoxFit.cover,
                      ),
                      // Dark overlay for text readability
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
                      // Content
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
                                  color: Colors.white.withValues(alpha: 0.88),
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

                    const SizedBox(height: 20),

                    // ── Completion Toggle ──────────────────────────────────
                    _SectionLabel(label: 'Completion Status'),
                    const SizedBox(height: 8),
                    _FormCard(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: (_isCompleted ? _green : _mutedText)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isCompleted
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: _isCompleted ? _green : _mutedText,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCompleted ? 'Completed' : 'In Progress',
                                  style: GoogleFonts.inter(
                                    color: _isCompleted ? _green : _mutedText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _isCompleted
                                      ? 'This activity has been finished'
                                      : 'Mark when the activity is done',
                                  style: GoogleFonts.inter(
                                    color: _mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _isCompleted = !_isCompleted),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 50,
                              height: 28,
                              decoration: BoxDecoration(
                                color: _isCompleted ? _green : _borderColor,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: AnimatedAlign(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                alignment: _isCompleted
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  width: 22,
                                  height: 22,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 1))
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          _green.withValues(alpha: 0.5),
                          _darkGreen.withValues(alpha: 0.5),
                        ],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF0C503C), Color(0xFF1A5C30)],
                      ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.35),
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
                            'Save Activity',
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