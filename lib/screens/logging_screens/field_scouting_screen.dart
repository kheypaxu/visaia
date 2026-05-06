import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visaia/widgets/success_modal.dart';
import 'package:visaia/services/firestore_service.dart';

// ─── Field Scouting Form Screen ───────────────────────────────────────────────

class FieldScoutingFormScreen extends StatefulWidget {
  final String userId;
  final String? cycleId;
  final String? stationId;
  final int? weekIndex;

  const FieldScoutingFormScreen({
    super.key,
    required this.userId,
    this.cycleId,
    this.stationId,
    this.weekIndex,
  });
  
  @override
  State<FieldScoutingFormScreen> createState() => _FieldScoutingFormScreenState();
}

class _FieldScoutingFormScreenState extends State<FieldScoutingFormScreen>
    with SingleTickerProviderStateMixin {
  // Form state
  String _selectedTrap = 'Station 1';
  String? _selectedCycleId;
  String _selectedCycleName = '';
  String _selectedFieldName = '';
  int _selectedCycleWeekIndex = 0;
  int _totalWeeks = 0;
  // REMOVED unused field: DateTime? _plantingDate;
  late final MonitoringFirestoreService _firestoreService;
  
  final TextEditingController _plantsInspectedController = TextEditingController(text: '100');
  final TextEditingController _damagedPlantsController = TextEditingController(text: '0');
  final TextEditingController _eggMassesController = TextEditingController(text: '0');
  final TextEditingController _larvaeController = TextEditingController(text: '0');
  final TextEditingController _pupaeController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();

  List<XFile> _pickedImages = [];
  bool _isSaving = false;
  bool _showSuccessModal = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final ImagePicker _picker = ImagePicker();

  // Colors
  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _bgColor = Color(0xFFF4F8F5);
  static const _mutedText = Color(0xFF9E9E9E);
  static const _borderColor = Color(0xFFDDEEE4);

  final List<String> _trapOptions = [
    'Station 1',
    'Station 2',
    'Station 3',
    'Station 4',
    'Station 5',
  ];

  @override
  void initState() {
    super.initState();
    _firestoreService = MonitoringFirestoreService(userId: widget.userId);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    
    if (widget.stationId != null) {
      final stationNumber = widget.stationId!.split(' ').last;
      final index = int.tryParse(stationNumber) ?? 1;
      if (index >= 1 && index <= _trapOptions.length) {
        _selectedTrap = 'Station $index';
      }
    }
    
    if (widget.cycleId != null) {
      _selectedCycleId = widget.cycleId;
      _loadCycleData();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _plantsInspectedController.dispose();
    _damagedPlantsController.dispose();
    _eggMassesController.dispose();
    _larvaeController.dispose();
    _pupaeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadCycleData() async {
    if (_selectedCycleId == null) return;
    
    try {
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(_selectedCycleId)
          .get();
      
      if (cycleDoc.exists) {
        final data = cycleDoc.data();
        final plantingDate = (data?['plantingDate'] as Timestamp?)?.toDate();
        final harvestDate = (data?['harvestDate'] as Timestamp?)?.toDate();
        
        setState(() {
          _selectedCycleName = data?['cycleName'] ?? 'Unknown Cycle';
          _selectedFieldName = data?['fieldName'] ?? 'Unknown Field';
          // _plantingDate = plantingDate; // REMOVED
          
          if (plantingDate != null && harvestDate != null) {
            final totalDays = harvestDate.difference(plantingDate).inDays;
            _totalWeeks = (totalDays / 7).ceil().clamp(1, 52);
            
            final daysSincePlanting = DateTime.now().difference(plantingDate).inDays;
            final currentWeek = (daysSincePlanting / 7).floor();
            _selectedCycleWeekIndex = widget.weekIndex ?? currentWeek.clamp(0, _totalWeeks - 1);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading cycle data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserCycles() async {
    try {
      final cyclesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .orderBy('createdAt', descending: true)
          .get();
      
      if (cyclesSnapshot.docs.isEmpty) {
        return [];
      }
      
      final List<Map<String, dynamic>> activeCycles = [];
      
      for (var doc in cyclesSnapshot.docs) {
        final data = doc.data();
        if (data['isCompleted'] == true) {
          continue;
        }
        if (data['plantingDate'] != null && data['harvestDate'] != null) {
          activeCycles.add({
            'id': doc.id,
            'cycleName': data['cycleName'] ?? 'Unnamed Cycle',
            'fieldName': data['fieldName'] ?? 'Unknown Field',
            'plantingDate': data['plantingDate'],
            'harvestDate': data['harvestDate'],
          });
        }
      }
      
      return activeCycles;
    } catch (e) {
      debugPrint('Error fetching cycles: $e');
      return [];
    }
  }

  void _showCycleSelector() async {
    final cycles = await _fetchUserCycles();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Growth Cycle',
                      style: GoogleFonts.inter(
                        color: _darkGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
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
              if (cycles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_outlined, size: 48, color: _mutedText),
                      const SizedBox(height: 12),
                      Text(
                        'No active cycles found',
                        style: GoogleFonts.inter(
                          color: _mutedText,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...cycles.map((cycle) {
                  final isSelected = cycle['id'] == _selectedCycleId;
                  return GestureDetector(
                    onTap: () async {
                      setState(() {
                        _selectedCycleId = cycle['id'] as String;
                        _selectedCycleName = cycle['cycleName'] as String;
                        _selectedFieldName = cycle['fieldName'] as String;
                      });
                      await _loadCycleData();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: isSelected ? _green.withValues(alpha: 0.08) : Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.agriculture, color: _green, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cycle['cycleName'],
                                  style: GoogleFonts.inter(
                                    color: isSelected ? _green : _darkGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cycle['fieldName'],
                                  style: GoogleFonts.inter(
                                    color: _mutedText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: _green, size: 22),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    for (final image in _pickedImages) {
      try {
        imageUrls.add(image.path);
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }
    return imageUrls;
  }

  Future<void> _saveScoutingData() async {
    if (_isSaving || _selectedCycleId == null) {
      if (_selectedCycleId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a growth cycle first'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      // Images are no longer used – removed the variable
      // final uploadedImages = await _uploadImages();
      await _uploadImages(); // keep if you want to keep the method, else remove the call
      
      final stationNumber = int.tryParse(_selectedTrap.split(' ').last) ?? 1;
      final stationTitle = 'Station $stationNumber';
      final weekId = 'week_${_selectedCycleWeekIndex + 1}';
      
      Map<String, dynamic>? weekData = await _firestoreService.getWeek(
        _selectedCycleId!, 
        weekId
      );
      
      List<Map<String, dynamic>> stations = [];
      
      if (weekData != null && weekData['stations'] != null) {
        stations = List<Map<String, dynamic>>.from(
          (weekData['stations'] as List).map((station) => Map<String, dynamic>.from(station))
        );
        debugPrint('Loaded ${stations.length} existing stations from service');
      } else {
        debugPrint('Creating new week document with default stations');
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
      
      final stationIndex = stations.indexWhere((station) => station['title'] == stationTitle);
      final plantsInspected = int.tryParse(_plantsInspectedController.text) ?? 100;
      final damaged = int.tryParse(_damagedPlantsController.text) ?? 0;
      final eggMasses = int.tryParse(_eggMassesController.text) ?? 0;
      final larvae = int.tryParse(_larvaeController.text) ?? 0;
      final pupae = int.tryParse(_pupaeController.text) ?? 0;
      final notes = _notesController.text;
      
      final fawObserved = damaged > 0 || eggMasses > 0 || larvae > 0 || pupae > 0;
      
      if (stationIndex != -1) {
        stations[stationIndex] = {
          'title': stationTitle,
          'completed': stations[stationIndex]['completed'] ?? false,
          'plantsInspected': plantsInspected,
          'damaged': damaged,
          'fawObserved': fawObserved,
          'eggMasses': eggMasses,
          'larvae': larvae,
          'pupae': pupae,
          'notes': notes.isNotEmpty ? notes : (stations[stationIndex]['notes'] ?? ''),
        };
        debugPrint('Updated station $stationTitle');
      } else {
        stations.add({
          'title': stationTitle,
          'completed': false,
          'plantsInspected': plantsInspected,
          'damaged': damaged,
          'fawObserved': fawObserved,
          'eggMasses': eggMasses,
          'larvae': larvae,
          'pupae': pupae,
          'notes': notes,
        });
        debugPrint('Added new station $stationTitle');
      }
      
      final totalDamaged = stations.fold<int>(0, (total, station) => total + (station['damaged'] as int? ?? 0));
      final totalEggs = stations.fold<int>(0, (total, station) => total + (station['eggMasses'] as int? ?? 0));
      final totalLarvae = stations.fold<int>(0, (total, station) => total + (station['larvae'] as int? ?? 0));
      final totalPupae = stations.fold<int>(0, (total, station) => total + (station['pupae'] as int? ?? 0));
      final completedStations = stations.where((station) => station['completed'] as bool? ?? false).length;
      
      final weekDataToSave = {
        'stations': stations,
        'totals': {
          'damaged': totalDamaged,
          'eggs': totalEggs,
          'larvae': totalLarvae,
          'pupae': totalPupae,
        },
        'completedStations': completedStations,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      
      await _firestoreService.saveWeek(_selectedCycleId!, weekId, weekDataToSave);
      debugPrint('Week data saved successfully using service');
      
      if (mounted) {
        setState(() => _showSuccessModal = true);
      }
    } catch (e, stackTrace) {
      debugPrint('Error saving scouting data: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_showSuccessModal) {
      return Stack(
        children: [
          Scaffold(
            backgroundColor: _bgColor,
            body: const Center(),
          ),
          SuccessModal(
            title: 'Scouting Saved!',
            subtitle: 'Your field scouting data for $_selectedCycleName has been saved successfully.',
            buttonText: 'Done',
            onClose: () {
              setState(() => _showSuccessModal = false);
              Navigator.pop(context, true);
            },
          ),
        ],
      );
    }

    return Stack(
      children: [
        Scaffold(
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
                                const Color(0xFF0C503C).withValues(alpha: 0.78),
                                const Color(0xFF1A5C30).withValues(alpha: 0.72),
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
                                  widget.stationId != null 
                                      ? 'Quick Scouting - ${widget.stationId}'
                                      : 'Field Scouting',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Document pest pressure and crop health for the current growth cycle.',
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
                  padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPadding + 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Growth Period (Now Selectable) ──────────────────────
                      const _SectionLabel(label: 'Growth Cycle'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _showCycleSelector,
                        child: _FormCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.agriculture, color: _green, size: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Growth Cycle',
                                      style: GoogleFonts.inter(
                                        color: _mutedText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _selectedCycleId != null 
                                          ? '$_selectedCycleName • $_selectedFieldName'
                                          : 'Tap to select a cycle',
                                      style: GoogleFonts.inter(
                                        color: _selectedCycleId != null ? _darkGreen : _mutedText,
                                        fontSize: 14,
                                        fontWeight: _selectedCycleId != null ? FontWeight.w700 : FontWeight.w400,
                                      ),
                                    ),
                                    if (_selectedCycleId != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Week ${_selectedCycleWeekIndex + 1} of $_totalWeeks',
                                        style: GoogleFonts.inter(
                                          color: _green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: _mutedText, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Station Selection ──────────────────────────────────────
                      const _SectionLabel(label: 'Station Selection'),
                      const SizedBox(height: 8),
                      _FormCard(
                        child: GestureDetector(
                          onTap: widget.stationId == null && _selectedCycleId != null
                              ? () => _showTrapModal(context) 
                              : null,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: _green.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.sensors_rounded, color: _green, size: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Selection Name',
                                      style: GoogleFonts.inter(
                                        color: _mutedText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _selectedTrap,
                                      style: GoogleFonts.inter(
                                        color: _darkGreen,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.stationId == null && _selectedCycleId != null)
                                const Icon(Icons.unfold_more_rounded, color: _mutedText, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Inspection Counters ────────────────────────────────
                      const _SectionLabel(label: 'Inspection Counters'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _CounterCard(
                              label: 'Plants Inspected',
                              controller: _plantsInspectedController,
                              icon: Icons.grain_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CounterCard(
                              label: 'Damaged Plants',
                              controller: _damagedPlantsController,
                              icon: Icons.warning_amber_rounded,
                              isDamaged: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Pest Observations ──────────────────────────────────
                      const _SectionLabel(label: 'Pest Observations'),
                      const SizedBox(height: 8),
                      _FormCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _PestObservationRow(
                              icon: Icons.circle_outlined,
                              label: 'Egg Masses',
                              controller: _eggMassesController,
                              color: Colors.brown.shade400,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(height: 24, color: _borderColor),
                            ),
                            _PestObservationRow(
                              icon: Icons.bug_report_outlined,
                              label: 'Larvae',
                              controller: _larvaeController,
                              color: Colors.orange.shade400,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Divider(height: 24, color: _borderColor),
                            ),
                            _PestObservationRow(
                              icon: Icons.shield_outlined,
                              label: 'Pupae',
                              controller: _pupaeController,
                              color: Colors.purple.shade300,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Upload Field Photo ─────────────────────────────────
                      const _SectionLabel(label: 'Field Photo'),
                      const SizedBox(height: 4),
                      Text(
                        'Optional — attach photos of the scouting area',
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

                      // ── Field Notes ────────────────────────────────────────
                      const _SectionLabel(label: 'Field Notes'),
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
                                'Describe environmental conditions, pest behavior, or other observations…',
                            hintStyle: GoogleFonts.inter(
                              color: _mutedText,
                              fontSize: 13,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Save Button ───────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: _bgColor,
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding + 16),
            child: GestureDetector(
              onTap: _saveScoutingData,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C503C), Color(0xFF1A5C30)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _green.withAlpha(90),
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
                            Text(
                              'Save Scouting Data',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.save_rounded,
                                color: Colors.white, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTrapModal(BuildContext context) {
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
                      'Select Station',
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
              ..._trapOptions.map((trap) {
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

// ── Counter Card ──────────────────────────────────────────────────────────────

class _CounterCard extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isDamaged;

  const _CounterCard({
    required this.label,
    required this.controller,
    required this.icon,
    this.isDamaged = false,
  });

  @override
  State<_CounterCard> createState() => _CounterCardState();
}

class _CounterCardState extends State<_CounterCard> {
  void _updateCount(bool increment) {
    final current = int.tryParse(widget.controller.text) ?? 0;
    final newVal = increment ? current + 1 : (current > 0 ? current - 1 : 0);
    widget.controller.text = newVal.toString();
    setState(() {}); // Trigger UI update if needed for visual changes
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDamaged && (int.tryParse(widget.controller.text) ?? 0) > 0
              ? Colors.orange.shade300
              : const Color(0xFFDDEEE4),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: const Color(0xFF1A5C30), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF9E9E9E),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CounterButton(
                icon: Icons.remove_rounded,
                onTap: () => _updateCount(false),
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  widget.controller.text,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0C503C),
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
              ),
              _CounterButton(
                icon: Icons.add_rounded,
                onTap: () => _updateCount(true),
              ),
            ],
          ),
        ],
      ),
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
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A5C30).withValues(alpha: 0.09),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF1A5C30), size: 18),
      ),
    );
  }
}

// ── Pest Observation Row ──────────────────────────────────────────────────────

class _PestObservationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final Color color;

  const _PestObservationRow({
    required this.icon,
    required this.label,
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF0C503C),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            height: 36,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                color: const Color(0xFF0C503C),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF4F8F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFDDEEE4), width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFDDEEE4), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF1A5C30), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Full-width upload button
        GestureDetector(
          onTap: onAdd,
          child: Container(
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFDDEEE4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A5C30).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_camera_outlined,
                      color: Color(0xFF1A5C30), size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  'Upload Field Photo',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1A5C30),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Grid of uploaded photos
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: images.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
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
                    right: 4,
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
            }).toList(),
          ),
        ],
      ],
    );
  }
}