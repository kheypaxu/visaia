import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/widgets/success_modal.dart';
import 'package:visaia/screens/monitoring_screens/monitoring.dart';
import 'package:visaia/widgets/database_image.dart';
import 'package:visaia/services/firestore_safe_ext.dart';

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
  State<FieldScoutingFormScreen> createState() =>
      _FieldScoutingFormScreenState();
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
  ScoutingFormSession? _session;
  String? _hydratedSelection;
  bool _hydrating = false;
  final _mothsController = TextEditingController(text: '0');

  int get _stationIndex =>
      (int.tryParse(_selectedTrap.split(' ').last) ?? 1) - 1;
  bool get _formLocked =>
      _session == null ||
      _session!.loading ||
      _session!.error != null ||
      _session!.locked ||
      _session!.station(_stationIndex) == null ||
      _session!.station(_stationIndex)?['completed'] == true;

  Map<String, TextEditingController> get _observationControllers => {
    'damaged': _damagedPlantsController,
    'eggMasses': _eggMassesController,
    'larvae': _larvaeController,
    'pupae': _pupaeController,
    'moths': _mothsController,
  };

  void _syncObservations() {
    if (_hydrating || _formLocked) return;
    final values = <String, dynamic>{
      for (final entry in _observationControllers.entries)
        entry.key: int.tryParse(entry.value.text) ?? 0,
      'notes': _notesController.text,
    };
    _session!.update(_stationIndex, values);
    setState(() {});
  }

  void _hydrateStation(ScoutingFormSession session) {
    final selection = '$_selectedCycleId-${session.weekIndex}-$_stationIndex';
    if (session.loading ||
        session.error != null ||
        _hydratedSelection == selection) {
      return;
    }
    final station = session.station(_stationIndex);
    if (station == null) return;
    _hydratedSelection = selection;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hydratedSelection != selection) return;
      _hydrating = true;
      _plantsInspectedController.text = '10';
      for (final entry in _observationControllers.entries) {
        entry.value.text = '${station[entry.key] ?? 0}';
      }
      _notesController.text = station['notes'] as String? ?? '';
      _hydrating = false;
      setState(() {});
    });
  }

  final TextEditingController _plantsInspectedController =
      TextEditingController(text: '10');
  final TextEditingController _damagedPlantsController = TextEditingController(
    text: '0',
  );
  final TextEditingController _eggMassesController = TextEditingController(
    text: '0',
  );
  final TextEditingController _larvaeController = TextEditingController(
    text: '0',
  );
  final TextEditingController _pupaeController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();

  bool _isSaving = false;
  bool _showSuccessModal = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

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
    for (final controller in [
      ..._observationControllers.values,
      _notesController,
    ]) {
      controller.addListener(_syncObservations);
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

    if (widget.stationId != null) {
      final stationNumber = widget.stationId!.split(' ').last;
      final index = int.tryParse(stationNumber) ?? 1;
      if (index >= 1 && index <= _trapOptions.length) {
        _selectedTrap = 'Station $index';
      }
    }

    if (widget.cycleId?.trim().isNotEmpty == true) {
      _selectedCycleId = widget.cycleId;
      _loadCycleData();
    }
  }

  @override
  void dispose() {
    _mothsController.dispose();
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
          .safeGet();

      if (cycleDoc.exists) {
        final data = cycleDoc.data();
        final plantingDate = (data?['plantingDate'] as Timestamp?)?.toDate();
        final harvestDate = (data?['harvestDate'] as Timestamp?)?.toDate();

        if (mounted) {
          setState(() {
            _selectedCycleName = data?['cycleName'] ?? 'Unknown Cycle';
            _selectedFieldName = data?['fieldName'] ?? 'Unknown Field';
            // _plantingDate = plantingDate; // REMOVED

            if (plantingDate != null && harvestDate != null) {
              final totalDays = harvestDate.difference(plantingDate).inDays;
              _totalWeeks = (totalDays / 7).ceil().clamp(1, 52);

              final daysSincePlanting = DateTime.now()
                  .difference(plantingDate)
                  .inDays;
              final currentWeek =
                  (daysSincePlanting.clamp(0, totalDays) / 7).ceil() - 1;
              _selectedCycleWeekIndex =
                  widget.weekIndex ?? currentWeek.clamp(0, _totalWeeks - 1);
            }
          });
        }
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
          .safeGet();

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
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
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
              if (cycles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: _mutedText,
                      ),
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
                      if (_session != null && !await _session!.saveDraft()) {
                        return;
                      }
                      if (!mounted || !ctx.mounted) return;
                      setState(() {
                        _session = null;
                        _hydratedSelection = null;
                        _selectedCycleId = cycle['id'] as String;
                        _selectedCycleName = cycle['cycleName'] as String;
                        _selectedFieldName = cycle['fieldName'] as String;
                      });
                      await _loadCycleData();
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      color: isSelected
                          ? _green.withValues(alpha: 0.08)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.agriculture,
                              color: _green,
                              size: 20,
                            ),
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
                            const Icon(
                              Icons.check_circle_rounded,
                              color: _green,
                              size: 22,
                            ),
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

  Future<void> _saveScoutingData() async {
    if (_isSaving) return;
    if (_session == null || _session!.loading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a growth cycle and wait for station data to load.',
          ),
        ),
      );
      return;
    }
    if (_formLocked) return;
    for (final entry in _observationControllers.entries) {
      final value = int.tryParse(entry.value.text);
      if (value == null ||
          value < 0 ||
          (entry.key == 'damaged' && value > 10)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Use nonnegative whole numbers; damaged plants must be between 0 and 10.',
            ),
          ),
        );
        return;
      }
    }
    _syncObservations();
    setState(() => _isSaving = true);
    try {
      final saved = await _session!.complete(_stationIndex);
      if (mounted && saved) setState(() => _showSuccessModal = true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCycleId == null) return _buildForm(context);
    return MonitoringScreen(
      key: ValueKey(_selectedCycleId),
      cycleId: _selectedCycleId!,
      userId: widget.userId,
      initialWeekIndex: widget.weekIndex,
      quickLog: true,
      scoutingFormBuilder: (session) {
        _session = session;
        _hydrateStation(session);
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (_showSuccessModal) {
      return Stack(
        children: [
          Scaffold(backgroundColor: _bgColor, body: const Center()),
          SuccessModal(
            title: 'Scouting Saved!',
            subtitle:
                'Your field scouting data for $_selectedCycleName has been saved successfully.',
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
                  expandedHeight:
                      168 +
                      (MediaQuery.textScalerOf(context).scale(100) - 100) * 2,
                  pinned: true,
                  backgroundColor: _darkGreen,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () async {
                      if (_isSaving) return;
                      if (_session != null &&
                          !_session!.loading &&
                          _session!.error == null &&
                          !await _session!.saveDraft()) {
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
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
                                child: const Icon(
                                  Icons.agriculture,
                                  color: _green,
                                  size: 18,
                                ),
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
                                        color: _selectedCycleId != null
                                            ? _darkGreen
                                            : _mutedText,
                                        fontSize: 14,
                                        fontWeight: _selectedCycleId != null
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    if (_selectedCycleId != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Week ${(_session?.weekIndex ?? _selectedCycleWeekIndex) + 1} of $_totalWeeks',
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
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: _mutedText,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Station Selection ──────────────────────────────────────
                      const _SectionLabel(label: 'Scouting Week'),
                      const SizedBox(height: 8),
                      _FormCard(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey(
                            'scouting-week-$_selectedCycleId-${_session?.weekIndex}',
                          ),
                          initialValue: _session != null && !_session!.loading
                              ? _session!.weekIndex
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.date_range_outlined,
                              color: _green,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          hint: Text(
                            _selectedCycleId == null
                                ? 'Select a growth cycle first'
                                : 'Loading scouting weeks...',
                          ),
                          items: _session == null || _session!.loading
                              ? []
                              : [
                                  for (
                                    int index = 0;
                                    index < _session!.totalWeeks;
                                    index++
                                  )
                                    DropdownMenuItem(
                                      value: index,
                                      enabled: index < _session!.currentWeek,
                                      child: Text(
                                        'Week ${index + 1} - ${DateFormat('MMM d').format(_session!.weekStart(index))}${index >= _session!.currentWeek ? ' (Upcoming)' : ''}',
                                        style: GoogleFonts.inter(
                                          color: index < _session!.currentWeek
                                              ? _darkGreen
                                              : _mutedText,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                          onChanged:
                              _session == null || _session!.loading || _isSaving
                              ? null
                              : (index) async {
                                  if (index == null) return;
                                  await _session!.selectWeek(index);
                                  if (mounted) setState(() {});
                                },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Station Selection'),
                      const SizedBox(height: 8),
                      _FormCard(
                        child: GestureDetector(
                          onTap:
                              widget.stationId == null &&
                                  _selectedCycleId != null
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
                                child: const Icon(
                                  Icons.sensors_rounded,
                                  color: _green,
                                  size: 18,
                                ),
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
                              if (widget.stationId == null &&
                                  _selectedCycleId != null)
                                const Icon(
                                  Icons.unfold_more_rounded,
                                  color: _mutedText,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Inspection Counters ────────────────────────────────
                      if (_session?.loading == true)
                        const LinearProgressIndicator(),
                      if (_session?.error != null)
                        Text(
                          _session!.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      if (_session?.station(_stationIndex)?['completed'] ==
                          true)
                        const Text(
                          'This station is completed.',
                          style: TextStyle(color: _green),
                        ),
                      _FormCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.grain_rounded,
                              color: _green,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Plants inspected',
                                style: GoogleFonts.inter(
                                  color: _darkGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '10 per station',
                              style: GoogleFonts.inter(
                                color: _green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Pest Observations'),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CounterCard(
                                  enabled: !_formLocked,
                                  label: 'Egg Masses',
                                  controller: _eggMassesController,
                                  icon: Icons.circle_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CounterCard(
                                  enabled: !_formLocked,
                                  label: 'Larvae',
                                  controller: _larvaeController,
                                  icon: Icons.bug_report_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _CounterCard(
                                  enabled: !_formLocked,
                                  label: 'Pupae',
                                  controller: _pupaeController,
                                  icon: Icons.shield_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _CounterCard(
                                  enabled: !_formLocked,
                                  label: 'Moths',
                                  controller: _mothsController,
                                  icon: Icons.bug_report_outlined,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Plant Damage'),
                      const SizedBox(height: 8),
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CounterCard(
                              enabled: !_formLocked,
                              maxValue: 10,
                              label: 'Damaged Plants',
                              controller: _damagedPlantsController,
                              icon: Icons.warning_amber_rounded,
                              isDamaged: true,
                              embedded: true,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Out of 10 plants. Rate each damaged plant below.',
                              style: GoogleFonts.inter(
                                color: _mutedText,
                                fontSize: 12,
                              ),
                            ),
                            if ((int.tryParse(_damagedPlantsController.text) ??
                                        0) >
                                    0 &&
                                _session != null) ...[
                              const Divider(height: 28, color: _borderColor),
                              const _SectionLabel(
                                label: 'Plant Damage Ratings',
                              ),
                              const SizedBox(height: 8),
                              AbsorbPointer(
                                absorbing: _formLocked,
                                child: _session!.damageAssessment(
                                  _stationIndex,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel(label: 'Field Photo'),
                      const SizedBox(height: 4),
                      Text(
                        'Verify observed pests and attach at least one damage photo for each damaged plant.',
                        style: GoogleFonts.inter(
                          color: _mutedText,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _FormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _formLocked
                                  ? null
                                  : () async {
                                      _syncObservations();
                                      await _session!.verify(_stationIndex);
                                      if (mounted) setState(() {});
                                    },
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                color: _green,
                              ),
                              label: const Text(
                                'Add photos & verify observations',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _green,
                                minimumSize: const Size(48, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            if (_session?.station(
                                  _stationIndex,
                                )?['verificationCompleted'] ==
                                true)
                              const Text(
                                'Evidence verified',
                                style: TextStyle(color: _green),
                              ),
                            if (_session?.station(
                                  _stationIndex,
                                )?['damagePhotos']
                                is List)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final photo
                                      in _session!.station(
                                            _stationIndex,
                                          )!['damagePhotos']
                                          as List)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: DatabaseImage(
                                          source: photo as String,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const _SectionLabel(label: 'Field Notes'),
                      const SizedBox(height: 8),
                      _FormCard(
                        padding: EdgeInsets.zero,
                        child: TextField(
                          enabled: !_formLocked,
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
              onTap: _formLocked || _isSaving ? null : _saveScoutingData,
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
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
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
                            const Icon(
                              Icons.save_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
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
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
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
              ..._trapOptions.map((trap) {
                final isSelected = trap == _selectedTrap;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTrap = trap;
                      _hydratedSelection = null;
                    });
                    Navigator.pop(ctx);
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

// ── Counter Card ──────────────────────────────────────────────────────────────

class _CounterCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool isDamaged;
  final bool enabled;
  final int? maxValue;
  final bool embedded;

  const _CounterCard({
    required this.label,
    required this.controller,
    required this.icon,
    this.isDamaged = false,
    this.enabled = true,
    this.maxValue,
    this.embedded = false,
  });

  void _change(int amount) {
    final next = ((int.tryParse(controller.text) ?? 0) + amount).clamp(
      0,
      maxValue ?? 2147483647,
    );
    controller.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final count = int.tryParse(value.text) ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1A5C30), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0C503C),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _CounterButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Decrease $label',
                  onTap: enabled && count > 0 ? () => _change(-1) : null,
                ),
                Expanded(
                  child: TextField(
                    key: ValueKey('count-$label'),
                    enabled: enabled,
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      if (maxValue != null)
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          if (newValue.text.isEmpty) return newValue;
                          final parsed = int.tryParse(newValue.text);
                          return parsed != null && parsed <= maxValue!
                              ? newValue
                              : oldValue;
                        }),
                    ],
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0C503C),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      semanticCounterText: '$label count',
                      hintText: '0',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 2,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                _CounterButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Increase $label',
                  onTap: enabled && (maxValue == null || count < maxValue!)
                      ? () => _change(1)
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
    if (embedded) return content;
    return _FormCard(padding: const EdgeInsets.all(10), child: content);
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _CounterButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
      foregroundColor: const Color(0xFF1A5C30),
      backgroundColor: const Color(0x171A5C30),
    ),
  );
}
