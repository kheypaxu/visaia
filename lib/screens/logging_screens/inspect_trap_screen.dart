import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:visaia/core/providers/farm_provider.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

// ─── Trap Condition Model ─────────────────────────────────────────────────────

enum TrapCondition {
  good,
  needsCleaning,
  damaged,
}

extension TrapConditionExt on TrapCondition {
  String get label {
    switch (this) {
      case TrapCondition.good:
        return 'Good';
      case TrapCondition.needsCleaning:
        return 'Needs\nCleaning';
      case TrapCondition.damaged:
        return 'Damaged';
    }
  }

  IconData get icon {
    switch (this) {
      case TrapCondition.good:
        return Icons.check_circle_outline;
      case TrapCondition.needsCleaning:
        return Icons.cleaning_services_outlined;
      case TrapCondition.damaged:
        return Icons.warning_amber_rounded;
    }
  }
}

// ─── Inspect Trap Form Screen ─────────────────────────────────────────────────

class InspectTrapScreen extends StatefulWidget {
  const InspectTrapScreen({super.key});

  @override
  State<InspectTrapScreen> createState() => _InspectTrapScreenState();
}

class _InspectTrapScreenState extends State<InspectTrapScreen>
    with SingleTickerProviderStateMixin {
  // Form state
  DateTime _selectedDate = DateTime.now();
  String _selectedTrap = 'Trap 1';
  int _mothCount = 0;
  TrapCondition? _selectedCondition;
  final TextEditingController _notesController = TextEditingController();
  
  List<XFile> _pickedImages = [];
  bool _isSaving = false;
  bool _isLoading = true;
  bool _canInspectTraps = false;
  String? _errorMessage;
  
  // Cycle selection
  String? _selectedCycleId;
  List<Map<String, dynamic>> _availableCycles = [];

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
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthCacheService().cachedUid;
      if (uid == null) {
        setState(() {
          _errorMessage = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get the active farm ID from the provider
      final farmProvider = context.read<FarmProvider>();
      final activeFarmId = farmProvider.activeFarmId;

      if (activeFarmId == null) {
        setState(() {
          _errorMessage = 'No active farm selected. Please select a farm first.';
          _isLoading = false;
        });
        return;
      }

      // Fetch cycles for this user that belong to the active farm
      final cyclesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cycles')
          .where('farmId', isEqualTo: activeFarmId)
          .where('isCompleted', isEqualTo: false)
          .safeGet();

      final cycles = <Map<String, dynamic>>[];
      
      for (final doc in cyclesSnapshot.docs) {
        final data = doc.data();
        final controlMethod = data['controlMethod'] as String?;
        final trapsInstalled = data['trapsInstalled'] == true;
        
        // Only include cycles with biological control AND traps installed
        if (controlMethod == 'biological' && trapsInstalled) {
          // Get trap names from the cycle
          final traps = data['traps'] as List? ?? [];
          final trapNames = traps.map((t) => t['name'] as String? ?? 'Trap ${traps.indexOf(t) + 1}').toList();
          
          cycles.add({
            'id': doc.id,
            'name': data['cycleName'] ?? 'Unknown Cycle',
            'fieldName': data['fieldName'] ?? '',
            'trapsInstalled': trapsInstalled,
            'trapNames': trapNames.isEmpty ? ['Trap 1'] : trapNames,
          });
        }
      }

      setState(() {
        _availableCycles = cycles;
        _isLoading = false;
        _canInspectTraps = cycles.isNotEmpty;
        if (cycles.isNotEmpty) {
          _selectedCycleId = cycles.first['id'];
          final firstCycle = cycles.first;
          final trapNames = firstCycle['trapNames'] as List? ?? ['Trap 1'];
          if (trapNames.isNotEmpty) {
            _selectedTrap = trapNames.first;
          }
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
        _isLoading = false;
      });
    }
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

  void _showTrapModal(BuildContext context) {
    if (_availableCycles.isEmpty) return;
    
    final cycle = _availableCycles.firstWhere(
      (c) => c['id'] == _selectedCycleId,
      orElse: () => {},
    );
    
    final trapNames = (cycle['trapNames'] as List?) ?? ['Trap 1'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Trap',
                      style: GoogleFonts.inter(
                        color: _darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: _bgColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: _darkGreen),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _borderColor),
              ...trapNames.map((trap) {
                final isSelected = trap == _selectedTrap;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTrap = trap);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    color: isSelected ? _green.withValues(alpha: 0.08) : Colors.transparent,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trap,
                          style: GoogleFonts.inter(
                            color: isSelected ? _green : _darkGreen,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: _green, size: 20),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveInspection() async {
    if (_selectedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cycle first')),
      );
      return;
    }

    if (_selectedCondition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select trap condition')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? AuthCacheService().cachedUid;
      if (uid == null) throw Exception('User not authenticated');

      // Save inspection to Firestore
      final inspectionData = {
        'trapName': _selectedTrap,
        'mothCount': _mothCount,
        'condition': _selectedCondition!.label,
        'conditionIcon': _selectedCondition!.icon.codePoint,
        'notes': _notesController.text,
        'date': Timestamp.fromDate(_selectedDate),
        'timestamp': FieldValue.serverTimestamp(),
        'images': _pickedImages.map((img) => img.path).toList(),
        'cycleId': _selectedCycleId,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cycles')
          .doc(_selectedCycleId)
          .collection('trapInspections')
          .add(inspectionData);

      // Also add to daily log
      DocumentSnapshot<Map<String, dynamic>>? cycleDoc;
      try {
        cycleDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cycles')
            .doc(_selectedCycleId)
            .safeGet();
      } catch (e) {
        debugPrint('Error getting cycleDoc for trap inspection (offline): $e');
      }
      
      final plantingDate = (cycleDoc.data()?['plantingDate'] as Timestamp?)?.toDate();
      if (plantingDate != null) {
        final dayIndex = _selectedDate.difference(plantingDate).inDays;
        if (dayIndex >= 0) {
          final dayId = 'day_${(dayIndex + 1).toString().padLeft(2, '0')}';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('cycles')
              .doc(_selectedCycleId)
              .collection('dailyLogs')
              .doc(dayId)
              .collection('activities')
              .add({
            'type': 'Trap Inspection: $_selectedTrap',
            'notes': 'Inspected $_selectedTrap. Found $_mothCount moths. Condition: ${_selectedCondition!.label}',
            'images': _pickedImages.map((img) => img.path).toList(),
            'completed': true,
            'timestamp': FieldValue.serverTimestamp(),
            'date': Timestamp.fromDate(_selectedDate),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trap inspection saved successfully!'),
            backgroundColor: _green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _darkGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Inspect Trap',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          // Show active farm name in app bar
          Consumer<FarmProvider>(
            builder: (context, farmProvider, child) {
              final farmName = farmProvider.activeFarmName;
              if (farmName != null) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      farmName,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A5C30)),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : !_canInspectTraps
                    ? _buildLockedState()
                    : SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPadding + 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Cycle Selector ──────────────────────────
                            _SectionLabel(label: 'Select Cycle'),
                            const SizedBox(height: 8),
                            _buildCycleSelector(),
                            const SizedBox(height: 20),

                            // ── Inspection Details Row ────────────────
                            Row(
                              children: [
                                // Inspection Date
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel(label: 'Inspection Date'),
                                      const SizedBox(height: 8),
                                      _FormCard(
                                        child: GestureDetector(
                                          onTap: _pickDate,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(9),
                                                decoration: BoxDecoration(
                                                  color: _green.withValues(alpha: 0.09),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.calendar_today_rounded, color: _green, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      DateFormat('EEEE').format(_selectedDate),
                                                      style: GoogleFonts.inter(color: _mutedText, fontSize: 10, fontWeight: FontWeight.w500),
                                                    ),
                                                    Text(
                                                      DateFormat('MMM d, yyyy').format(_selectedDate),
                                                      style: GoogleFonts.inter(color: _darkGreen, fontSize: 14, fontWeight: FontWeight.w700),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Trap Name
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel(label: 'Trap Name'),
                                      const SizedBox(height: 8),
                                      _FormCard(
                                        child: GestureDetector(
                                          onTap: () => _showTrapModal(context),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(9),
                                                decoration: BoxDecoration(
                                                  color: _green.withValues(alpha: 0.09),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.location_on_outlined, color: _green, size: 18),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _selectedTrap,
                                                  style: GoogleFonts.inter(color: _darkGreen, fontSize: 14, fontWeight: FontWeight.w700),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(Icons.expand_more_rounded, color: _mutedText, size: 20),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ── Moth Population Counter ──────────────
                            _SectionLabel(label: 'Moth Population Data'),
                            const SizedBox(height: 8),
                            _FormCard(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    right: -10,
                                    top: -10,
                                    child: Opacity(
                                      opacity: 0.04,
                                      child: Icon(
                                        Icons.pest_control_outlined,
                                        color: _green,
                                        size: 140,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _CounterButton(
                                        icon: Icons.remove_rounded,
                                        onTap: () {
                                          if (_mothCount > 0) {
                                            setState(() => _mothCount--);
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 40),
                                      Text(
                                        '$_mothCount',
                                        style: GoogleFonts.inter(
                                          color: _darkGreen,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 42,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(width: 40),
                                      _CounterButton(
                                        icon: Icons.add_rounded,
                                        onTap: () => setState(() => _mothCount++),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Trap Condition ────────────────────────
                            _SectionLabel(label: 'Trap Condition'),
                            const SizedBox(height: 8),
                            Row(
                              children: TrapCondition.values.map((condition) {
                                final isSelected = _selectedCondition == condition;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: condition != TrapCondition.good ? 6.0 : 0,
                                      right: condition != TrapCondition.damaged ? 6.0 : 0,
                                    ),
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedCondition = condition),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        decoration: BoxDecoration(
                                          color: isSelected ? _darkGreen : Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected ? _darkGreen : _borderColor,
                                            width: 1.5,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: _darkGreen.withValues(alpha: 0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(
                                              condition.icon,
                                              color: isSelected ? Colors.white : _darkGreen,
                                              size: 24,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              condition.label,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.inter(
                                                color: isSelected ? Colors.white : _darkGreen,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 24),

                            // ── Upload Photo ──────────────────────────
                            _SectionLabel(label: 'Upload Photo'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickImages,
                              child: CustomPaint(
                                painter: _DashedBorderPainter(color: _borderColor),
                                child: Container(
                                  width: double.infinity,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, color: _mutedText.withValues(alpha: 0.6), size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Tap to upload trap photos',
                                        style: GoogleFonts.inter(
                                          color: _mutedText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Uploaded Images Grid
                            if (_pickedImages.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _pickedImages.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final file = entry.value;
                                  return Stack(
                                    children: [
                                      Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: _borderColor, width: 1.2),
                                          image: DecorationImage(
                                            image: FileImage(File(file.path)),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(color: Colors.black12, blurRadius: 4)
                                              ],
                                            ),
                                            child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // ── Field Notes ───────────────────────────
                            _SectionLabel(label: 'Field Notes'),
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
                                      'Any additional observations about the trap location or surrounding area…',
                                  hintStyle: GoogleFonts.inter(
                                    color: _mutedText,
                                    fontSize: 13,
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // ── Save Button ───────────────────────────────────
                            if (_canInspectTraps)
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveInspection,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.save_rounded,
                                                color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Save Inspection',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Something went wrong',
            style: GoogleFonts.inter(fontSize: 16, color: Colors.red.shade400),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Traps Not Available',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _darkGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You need to have biological control selected and traps installed in a cycle to inspect traps.\n\n'
              'Go to Monitoring → Select a cycle → Choose Biological Control → Install traps',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _mutedText,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const Text('Go Back', style: TextStyle(
                color: Colors.white,
              ),),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleSelector() {
    if (_availableCycles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No cycles with traps installed in your current farm. Please set up traps first.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCycleId,
          isExpanded: true,
          hint: const Text('Select a cycle'),
          icon: const Icon(Icons.expand_more, color: Color(0xFF0C503C)),
          items: _availableCycles.map((cycle) {
            return DropdownMenuItem<String>(
              value: cycle['id'],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cycle['name'],
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _darkGreen,
                    ),
                  ),
                  Text(
                    cycle['fieldName'] ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _mutedText,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCycleId = value;
              final cycle = _availableCycles.firstWhere((c) => c['id'] == value);
              final trapNames = cycle['trapNames'] as List? ?? ['Trap 1'];
              _selectedTrap = trapNames.isNotEmpty ? trapNames.first : 'Trap 1';
            });
          },
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

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A5C30).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF1A5C30), size: 22),
      ),
    );
  }
}

// ── Dashed Border Painter ─────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ));

    for (PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double length = dashWidth.clamp(0.0, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}