import 'package:visaia/utils/trap_inspection_policy.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:visaia/services/firestore_image_service.dart';
import 'package:visaia/services/local_write_service.dart';
import 'package:visaia/widgets/success_modal.dart';
import 'package:visaia/screens/logging_screens/trap_lists.dart';
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

enum TrapCondition { good, needsCleaning, damaged }

extension TrapConditionExt on TrapCondition {
  String get label {
    switch (this) {
      case TrapCondition.good:
        return 'Good';
      case TrapCondition.needsCleaning:
        return 'Needs Cleaning';
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
  final String? cycleId;
  final String? userId;
  final String? initialTrapName;

  const InspectTrapScreen({
    super.key,
    this.cycleId,
    this.userId,
    this.initialTrapName,
  });

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
  bool _saved = false;
  bool _allowPop = false;
  bool _dateChanged = false;
  String? _conditionError;
  String? _inspectionId;
  final Map<String, String> _uploadedImages = {};

  bool get _dirty =>
      _mothCount != 0 ||
      _selectedCondition != null ||
      _notesController.text.isNotEmpty ||
      _pickedImages.isNotEmpty ||
      _dateChanged;

  String? get _uid =>
      widget.userId ??
      FirebaseAuth.instance.currentUser?.uid ??
      AuthCacheService().cachedUid;

  Map<String, dynamic>? get _cycle {
    for (final cycle in _availableCycles) {
      if (cycle['id'] == _selectedCycleId) return cycle;
    }
    return null;
  }

  DateTime get _firstInspectionDate {
    final traps = (_cycle?['traps'] as List?) ?? [];
    for (final trap in traps) {
      if (trap['name'] == _selectedTrap &&
          trap['installationDate'] is Timestamp) {
        return DateUtils.dateOnly(
          (trap['installationDate'] as Timestamp).toDate(),
        );
      }
    }
    final planted = _cycle?['plantingDate'];
    return planted is Timestamp
        ? DateUtils.dateOnly(planted.toDate())
        : DateTime(2020);
  }

  Future<bool> _confirmDiscard() async {
    if (_isSaving) return false;
    if (!_dirty || _saved) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard inspection?'),
            content: const Text('Your unsaved inspection will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep editing'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _leave() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, _saved);
    });
  }

  void _resetInspection() {
    _mothCount = 0;
    _selectedCondition = null;
    _conditionError = null;
    _notesController.clear();
    _pickedImages = [];
    _uploadedImages.clear();
    _inspectionId = null;
    _selectedDate = DateTime.now();
    _dateChanged = false;
  }

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final uid = _uid;
      if (uid == null) throw StateError('Please sign in to inspect traps.');
      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cycles');
      final cycles = <Map<String, dynamic>>[];
      void addCycle(String id, Map<String, dynamic> data) {
        final traps = (data['traps'] as List? ?? [])
            .whereType<Map>()
            .map((trap) => Map<String, dynamic>.from(trap))
            .where(
              (trap) =>
                  trap['name'] is String &&
                  (trap['name'] as String).trim().isNotEmpty,
            )
            .toList();
        if (data['isCompleted'] == true ||
            data['trapsInstalled'] != true ||
            traps.isEmpty) {
          return;
        }
        cycles.add({
          ...data,
          'id': id,
          'name': data['cycleName'] ?? 'Current Cycle',
          'fieldName': data['fieldName'] ?? '',
          'traps': traps,
          'trapNames': traps.map((trap) => trap['name'] as String).toList(),
        });
      }

      if (widget.cycleId != null && widget.cycleId!.isNotEmpty) {
        final doc = await collection.doc(widget.cycleId).safeGet();
        if (doc.exists) addCycle(doc.id, doc.data()!);
      } else {
        String? farmId;
        try {
          farmId = context.read<FarmProvider>().activeFarmId;
        } catch (_) {}
        var query = collection.where('isCompleted', isEqualTo: false);
        if (farmId != null) query = query.where('farmId', isEqualTo: farmId);
        final result = await query.safeGet();
        for (final doc in result.docs) {
          addCycle(doc.id, doc.data());
        }
      }
      if (!mounted) return;
      setState(() {
        _availableCycles = cycles;
        _canInspectTraps = cycles.isNotEmpty;
        _selectedCycleId = cycles.isEmpty ? null : cycles.first['id'] as String;
        if (cycles.isNotEmpty) {
          final names = cycles.first['trapNames'] as List<String>;
          _selectedTrap = names.contains(widget.initialTrapName)
              ? widget.initialTrapName!
              : names.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load traps. Please try again.\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    if (_firstInspectionDate.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This trap has a future installation date. Correct it before inspecting.',
          ),
        ),
      );
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(_firstInspectionDate)
          ? _firstInspectionDate
          : _selectedDate,
      firstDate: _firstInspectionDate,
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
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateChanged = true;
      });
    }
  }

  Future<void> _pickImages() async {
    List<XFile> images;
    try {
      images = await _picker.pickMultiImage(imageQuality: 80);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open photos. Please try again.'),
          ),
        );
      }
      return;
    }
    if (mounted && images.isNotEmpty) {
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

    final trapNames = (cycle['trapNames'] as List?) ?? [];

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
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
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
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: _darkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _borderColor),
                ...trapNames.map((trap) {
                  final isSelected = trap == _selectedTrap;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      if (trap == _selectedTrap ||
                          !await _confirmDiscard() ||
                          !mounted) {
                        return;
                      }
                      setState(() {
                        _resetInspection();
                        _selectedTrap = trap;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      color: isSelected
                          ? _green.withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            trap,
                            style: GoogleFonts.inter(
                              color: isSelected ? _green : _darkGreen,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: _green,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveInspection() async {
    if (_isSaving || _selectedCycleId == null) return;
    if (_selectedCondition == null) {
      setState(
        () => _conditionError = 'Select the trap condition before saving.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the trap condition before saving.'),
        ),
      );
      return;
    }
    if (DateUtils.dateOnly(_selectedDate).isBefore(_firstInspectionDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inspection date cannot be before trap installation.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final uid = _uid;
      if (uid == null) throw StateError('Please sign in again.');
      final db = FirebaseFirestore.instance;
      final cycleRef = db
          .collection('users')
          .doc(uid)
          .collection('cycles')
          .doc(_selectedCycleId);
      final cycleDoc = await cycleRef.safeGet();
      final data = cycleDoc.data();
      final traps = (data?['traps'] as List? ?? [])
          .whereType<Map>()
          .map((t) => Map<String, dynamic>.from(t))
          .toList();
      final index = traps.indexWhere((t) => t['name'] == _selectedTrap);
      if (data == null ||
          data['isCompleted'] == true ||
          data['trapsInstalled'] != true ||
          index < 0) {
        throw StateError(
          'This trap is no longer available. Reopen the inspection to refresh.',
        );
      }
      final installed = traps[index]['installationDate'];
      if (installed is Timestamp &&
          DateUtils.dateOnly(
            _selectedDate,
          ).isBefore(DateUtils.dateOnly(installed.toDate()))) {
        throw StateError('Inspection date cannot be before trap installation.');
      }
      final planting = data['plantingDate'];
      if (planting is! Timestamp) {
        throw StateError(
          'This cycle needs a planting date before an inspection can be logged.',
        );
      }
      final dayIndex = trapInspectionDayIndex(_selectedDate, planting.toDate());
      if (dayIndex < 0) {
        throw StateError('Inspection date cannot be before planting.');
      }
      final images = <String>[];
      for (final image in _pickedImages) {
        var reference = _uploadedImages[image.path];
        if (reference == null) {
          final bytes =
              await FlutterImageCompress.compressWithFile(
                image.path,
                minWidth: 640,
                minHeight: 640,
                quality: 45,
                format: CompressFormat.jpeg,
              ) ??
              await image.readAsBytes();
          reference = await FirestoreImageService.upload(
            bytes: bytes,
            userId: uid,
            cycleId: _selectedCycleId!,
            category: 'trap_inspection',
          );
          _uploadedImages[image.path] = reference;
        }
        images.add(reference);
      }
      final inspectionRef = cycleRef
          .collection('trapInspections')
          .doc(_inspectionId);
      _inspectionId = inspectionRef.id;
      final date = Timestamp.fromDate(_selectedDate);
      final batch = db.batch();
      batch.set(inspectionRef, {
        'trapName': _selectedTrap,
        'mothCount': _mothCount,
        'condition': _selectedCondition!.label,
        'conditionIcon': _selectedCondition!.icon.codePoint,
        'notes': _notesController.text.trim(),
        'date': date,
        'timestamp': FieldValue.serverTimestamp(),
        'images': images,
        'cycleId': _selectedCycleId,
      });
      final dayId = 'day_${(dayIndex + 1).toString().padLeft(2, '0')}';
      batch.set(
        cycleRef
            .collection('dailyLogs')
            .doc(dayId)
            .collection('activities')
            .doc(inspectionRef.id),
        {
          'type': 'Trap Inspection: $_selectedTrap',
          'notes':
              'Inspected $_selectedTrap. Found $_mothCount moths. Condition: ${_selectedCondition!.label}.'
              '${_notesController.text.trim().isEmpty ? '' : '\n${_notesController.text.trim()}'}',
          'images': images,
          'completed': true,
          'completedAt': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
          'date': date,
          'inspectionId': inspectionRef.id,
        },
      );
      final previous = traps[index]['lastInspectedAt'];
      if (shouldUpdateTrapInspection(
        _selectedDate,
        previous is Timestamp ? previous.toDate() : null,
      )) {
        traps[index].addAll({
          'lastInspectedAt': date,
          'lastMothCount': _mothCount,
          'lastCondition': _selectedCondition!.label,
        });
        final lastCycleDate = data['lastTrapInspectionDate'];
        batch.update(cycleRef, {
          'traps': traps,
          if (shouldUpdateTrapInspection(
            _selectedDate,
            lastCycleDate is Timestamp ? lastCycleDate.toDate() : null,
          ))
            'lastTrapInspectionDate': date,
        });
      }
      await LocalWriteService.run(inspectionRef, batch.commit);
      if (!mounted) return;
      setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save inspection: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_saved) {
      return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _leave();
        },
        child: Stack(
          children: [
            Scaffold(backgroundColor: _bgColor),
            SuccessModal(
              title: 'Inspection Saved!',
              subtitle: 'Your inspection for $_selectedTrap has been saved.',
              buttonText: 'Done',
              onClose: _leave,
            ),
          ],
        ),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: _bgColor,
        bottomNavigationBar:
            !_isLoading && _errorMessage == null && _canInspectTraps
            ? Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                color: _bgColor,
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_darkGreen, _green],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveInspection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving
                              ? 'Saving inspection...'
                              : 'Save Inspection',
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : null,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight:
                    168 +
                    (MediaQuery.textScalerOf(context).scale(100) - 100) * 2,
                backgroundColor: _darkGreen,
                leading: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _isSaving ? null : _leave,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/images/bg.png', fit: BoxFit.cover),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _darkGreen.withValues(alpha: 0.78),
                              _green.withValues(alpha: 0.72),
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
                              Text(
                                'Inspect Trap',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Record moth catches and trap condition for the current growth cycle.',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 12,
                                  height: 1.5,
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
              SliverToBoxAdapter(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1A5C30),
                        ),
                      )
                    : _errorMessage != null
                    ? _buildErrorState()
                    : !_canInspectTraps
                    ? _buildLockedState()
                    : AbsorbPointer(
                        absorbing: _isSaving,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            20,
                            16,
                            bottomPadding + 20,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Cycle Selector ──────────────────────────
                              _SectionLabel(label: 'Growth Cycle'),
                              const SizedBox(height: 8),
                              _buildCycleSelector(),
                              const SizedBox(height: 20),

                              // ── Inspection Details Row ────────────────
                              Column(
                                children: [
                                  // Inspection Date
                                  SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionLabel(label: 'Inspection Date'),
                                        const SizedBox(height: 8),
                                        _FormCard(
                                          child: GestureDetector(
                                            onTap: _pickDate,
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    9,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _green.withValues(
                                                      alpha: 0.09,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .calendar_today_rounded,
                                                    color: _green,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        DateFormat(
                                                          'EEEE',
                                                        ).format(_selectedDate),
                                                        style:
                                                            GoogleFonts.inter(
                                                              color: _mutedText,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                      ),
                                                      Text(
                                                        DateFormat(
                                                          'MMM d, yyyy',
                                                        ).format(_selectedDate),
                                                        style:
                                                            GoogleFonts.inter(
                                                              color: _darkGreen,
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
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
                                  const SizedBox(height: 20),
                                  // Trap Name
                                  SizedBox(
                                    width: double.infinity,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionLabel(label: 'Trap Name'),
                                        const SizedBox(height: 8),
                                        _FormCard(
                                          child: GestureDetector(
                                            onTap: () =>
                                                _showTrapModal(context),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    9,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _green.withValues(
                                                      alpha: 0.09,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.location_on_outlined,
                                                    color: _green,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _selectedTrap,
                                                    style: GoogleFonts.inter(
                                                      color: _darkGreen,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.expand_more_rounded,
                                                  color: _mutedText,
                                                  size: 20,
                                                ),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                          onTap: () =>
                                              setState(() => _mothCount++),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ── Trap Condition ────────────────────────
                              _SectionLabel(label: 'Trap Condition'),
                              if (_conditionError != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _conditionError!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: TrapCondition.values.map((condition) {
                                  final isSelected =
                                      _selectedCondition == condition;
                                  return Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: condition != TrapCondition.good
                                            ? 6.0
                                            : 0,
                                        right:
                                            condition != TrapCondition.damaged
                                            ? 6.0
                                            : 0,
                                      ),
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _selectedCondition = condition;
                                          _conditionError = null;
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? _darkGreen
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? _darkGreen
                                                  : _borderColor,
                                              width: 1.5,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: _darkGreen
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        3,
                                                      ),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(
                                                condition.icon,
                                                color: isSelected
                                                    ? Colors.white
                                                    : _darkGreen,
                                                size: 24,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                condition.label,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.inter(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : _darkGreen,
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
                              _SectionLabel(label: 'Photos (Optional)'),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickImages,
                                child: CustomPaint(
                                  painter: _DashedBorderPainter(
                                    color: _borderColor,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt_outlined,
                                          color: _mutedText.withValues(
                                            alpha: 0.6,
                                          ),
                                          size: 36,
                                        ),
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
                                  children: _pickedImages.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final file = entry.value;
                                    return Stack(
                                      children: [
                                        Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: _borderColor,
                                              width: 1.2,
                                            ),
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
                                              constraints: const BoxConstraints(
                                                minWidth: 48,
                                                minHeight: 48,
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: Colors.red,
                                              ),
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
                              _SectionLabel(label: 'Field Notes (Optional)'),
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
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
              ),
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
              'Install pheromone traps in an active growth cycle before recording an inspection. Open Monitoring to select a cycle and install traps.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _mutedText,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                if (widget.cycleId == null || _uid == null) {
                  _leave();
                  return;
                }
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrapSetupScreen(
                      cycleId: widget.cycleId!,
                      userId: _uid!,
                    ),
                  ),
                );
                if (mounted) _loadData();
              },
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: Text(
                widget.cycleId == null ? 'Go Back' : 'Install Traps',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
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
          itemHeight: 64,
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _darkGreen,
                    ),
                  ),
                  Text(
                    cycle['fieldName'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, color: _mutedText),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null ||
                value == _selectedCycleId ||
                !await _confirmDiscard() ||
                !mounted) {
              return;
            }
            setState(() {
              _resetInspection();
              _selectedCycleId = value;
              final cycle = _availableCycles.firstWhere(
                (c) => c['id'] == value,
              );
              final trapNames = cycle['trapNames'] as List;
              _selectedTrap = trapNames.first as String;
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
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDEEE4), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
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
        width: 48,
        height: 48,
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
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(16),
        ),
      );

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
