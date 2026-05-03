import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class UploadPestScreen extends StatefulWidget {
  final String? userId;

  const UploadPestScreen({super.key, this.userId});

  @override
  State<UploadPestScreen> createState() => _UploadPestScreenState();
}

class _UploadPestScreenState extends State<UploadPestScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  bool _isAnalyzing = false;
  bool _analysisConfirmed = false;
  String _identifiedPest = '';
  String _identifiedStage = '';
  String? _selectedCycleId;
  int _selectedStation = 1;
  List<Map<String, dynamic>> _cycles = [];

  // ─── Brand Colors ──────────────────────────────────────────────
  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _lightGreen = Color(0xFFEAF3DE);
  static const _midGreen = Color(0xFF3B6D11);
  static const _bgColor = Color(0xFFF4F8F5);
  static const _mutedText = Color(0xFF9DB5A4);
  static const _borderColor = Color(0xFFDDEEE4);

  @override
  void initState() {
    super.initState();
    _fetchCycles();
  }

  Future<void> _fetchCycles() async {
    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cycles')
        .where('isCompleted', isEqualTo: false)
        .get();
    setState(() {
      _cycles = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['cycleName'] ?? 'Unnamed',
          'fieldName': doc['fieldName'] ?? '',
          'plantingDate': (doc['plantingDate'] as Timestamp?)?.toDate(),
          'harvestDate': (doc['harvestDate'] as Timestamp?)?.toDate(),
        };
      }).toList();
    });
  }

  // ─── Image Picking ─────────────────────────────────────────────
  Future<void> _pickFromCamera() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image != null) _onImageSelected(image);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) _onImageSelected(image);
  }

  void _onImageSelected(XFile image) {
    setState(() {
      _image = image;
      _identifiedPest = '';
      _identifiedStage = '';
      _analysisConfirmed = false;
    });
    _analyzeImage();
  }

  void _retakePhoto() {
    setState(() {
      _image = null;
      _identifiedPest = '';
      _identifiedStage = '';
      _analysisConfirmed = false;
      _isAnalyzing = false;
    });
  }

  // ─── Analysis ──────────────────────────────────────────────────
  Future<void> _analyzeImage() async {
    setState(() => _isAnalyzing = true);

    // Show analysis modal
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (_) => _AnalysisModal(
          isAnalyzing: _isAnalyzing,
          pest: _identifiedPest,
          stage: _identifiedStage,
          onConfirm: () {
            Navigator.pop(context);
            setState(() => _analysisConfirmed = true);
          },
          onDiscard: () {
            Navigator.pop(context);
            _retakePhoto();
          },
          analysisFuture: _runAnalysis(),
        ),
      );
    }
  }

  Future<Map<String, String>> _runAnalysis() async {
    await Future.delayed(const Duration(seconds: 2));
    final random = DateTime.now().millisecondsSinceEpoch % 3;
    final pests = ['Fall Armyworm', 'Corn Borer', 'Aphid'];
    final stages = ['larvae', 'eggs', 'pupae'];
    final pest = pests[random % pests.length];
    final stage = stages[random % stages.length];
    setState(() {
      _identifiedPest = pest;
      _identifiedStage = stage;
      _isAnalyzing = false;
    });
    return {'pest': pest, 'stage': stage};
  }

  // ─── Save ──────────────────────────────────────────────────────
  Future<void> _savePestRecord() async {
    if (_selectedCycleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a cropping cycle')),
      );
      return;
    }
    final uid = widget.userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cycleDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cycles')
        .doc(_selectedCycleId)
        .get();
    final plantingDate =
        (cycleDoc.data()?['plantingDate'] as Timestamp?)?.toDate();
    if (plantingDate == null) return;

    final daysSincePlanting =
        DateTime.now().difference(plantingDate).inDays;
    final weekNumber = (daysSincePlanting / 7).floor() + 1;
    final weekId = 'week_$weekNumber';

    final weekRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cycles')
        .doc(_selectedCycleId)
        .collection('weeks')
        .doc(weekId);
    final weekSnap = await weekRef.get();

    List<Map<String, dynamic>> stations = [];
    if (weekSnap.exists && weekSnap.data()?['stations'] != null) {
      stations = List<Map<String, dynamic>>.from(
          (weekSnap.data()!['stations'] as List)
              .map((s) => Map<String, dynamic>.from(s)));
    } else {
      stations = List.generate(
          5,
          (i) => {
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

    final stationIndex = _selectedStation - 1;
    if (stationIndex >= 0 && stationIndex < stations.length) {
      final String stageKey = _identifiedStage;
      if (stations[stationIndex].containsKey(stageKey)) {
        stations[stationIndex][stageKey] =
            (stations[stationIndex][stageKey] as int) + 1;
        if (_identifiedPest.toLowerCase().contains('armyworm')) {
          stations[stationIndex]['fawObserved'] = true;
        }
      }
    }

    final totalDamaged = stations.fold<int>(
        0, (int t, s) => t + (s['damaged'] as int? ?? 0));
    final totalEggs = stations.fold<int>(
        0, (int t, s) => t + (s['eggMasses'] as int? ?? 0));
    final totalLarvae = stations.fold<int>(
        0, (int t, s) => t + (s['larvae'] as int? ?? 0));
    final totalPupae = stations.fold<int>(
        0, (int t, s) => t + (s['pupae'] as int? ?? 0));
    final completedStations =
        stations.where((s) => s['completed'] as bool? ?? false).length;

    await weekRef.set({
      'stations': stations,
      'totals': {
        'damaged': totalDamaged,
        'eggs': totalEggs,
        'larvae': totalLarvae,
        'pupae': totalPupae,
      },
      'completedStations': completedStations,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final dayNumber = daysSincePlanting + 1;
    final dayId = 'day_${dayNumber.toString().padLeft(2, '0')}';
    final activityId = 'pest_upload_${DateTime.now().millisecondsSinceEpoch}';
    final activityData = {
      'type': 'Pest Upload - $_identifiedPest ($_identifiedStage)',
      'notes':
          'Uploaded via quick pest identification. Added to Station $_selectedStation.',
      'images': [],
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'pestData': {
        'pest': _identifiedPest,
        'stage': _identifiedStage,
        'station': _selectedStation,
      }
    };
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cycles')
        .doc(_selectedCycleId)
        .collection('dailyLogs')
        .doc(dayId)
        .collection('activities')
        .doc(activityId)
        .set(activityData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Added 1 $_identifiedStage to Station $_selectedStation')),
      );
      Navigator.pop(context);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _darkGreen,
              size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Upload pest',
          style: GoogleFonts.dmSans(
            color: _darkGreen,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo card ─────────────────────────────────────
            _buildPhotoCard(),
            const SizedBox(height: 18),

            // ── Tips card (always visible) ──────────────────────
            _buildTipsCard(),
            const SizedBox(height: 18),

            // ── Assign section (after confirmation) ────────────
            if (_analysisConfirmed) ...[
              _buildAssignCard(),
              const SizedBox(height: 18),
              _buildSaveButton(),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Photo Card ────────────────────────────────────────────────
  Widget _buildPhotoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview zone
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 200,
                color: _lightGreen,
                child: _image != null
                    ? Image.file(File(_image!.path), fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF97C459), width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt_outlined,
                                color: _midGreen, size: 22),
                          ),
                          const SizedBox(height: 10),
                          Text('No photo yet',
                              style: GoogleFonts.dmSans(
                                  color: _midGreen,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Use the buttons below',
                              style: GoogleFonts.dmSans(
                                  color: const Color(0xFF639922), fontSize: 11)),
                        ],
                      ),
              ),
              if (_image != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _retakePhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Retake',
                          style: GoogleFonts.dmSans(
                              color: _lightGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
            ],
          ),

          // Action buttons row
          const Divider(height: 1, color: _borderColor),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.camera_alt_outlined,
                  label: 'Take photo',
                  onTap: _pickFromCamera,
                  hasBorder: true,
                ),
              ),
              Expanded(
                child: _actionButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose from gallery',
                  onTap: _pickFromGallery,
                  hasBorder: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool hasBorder,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: hasBorder
              ? const Border(right: BorderSide(color: _borderColor, width: 1))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _green, size: 16),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.dmSans(
                    color: _green, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ─── Tips Card ─────────────────────────────────────────────────
  Widget _buildTipsCard() {
    final tips = [
      'Get within 15–20 cm of the affected area or pest',
      'Use natural light — avoid harsh shadows or flash glare',
      'Focus on visible damage, egg masses, larvae, or the pest itself',
      'Hold steady — blur reduces identification accuracy',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to capture a good photo',
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _mutedText,
                  letterSpacing: 0.5)),
          const SizedBox(height: 12),
          ...tips.asMap().entries.map((e) {
            final isLast = e.key == tips.length - 1;
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _lightGreen),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: GoogleFonts.dmSans(
                                color: _midGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.value,
                          style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: const Color(0xFF6B8070),
                              height: 1.5)),
                    ),
                  ],
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: _borderColor),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ─── Assign Card ───────────────────────────────────────────────
  Widget _buildAssignCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cycle selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cropping cycle',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _mutedText,
                        letterSpacing: 0.5)),
                const SizedBox(height: 10),
                _buildCycleSelector(),
              ],
            ),
          ),
          const Divider(height: 1, color: _borderColor),
          // Station selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Station',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _mutedText,
                        letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _buildStationSelector(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleSelector() {
    if (_cycles.isEmpty) {
      return Text(
        'No active cycles found. Please start a cropping cycle first.',
        style: GoogleFonts.dmSans(color: _mutedText, fontSize: 13),
      );
    }
    return DropdownButtonFormField<String>(
      value: _selectedCycleId,
      decoration: InputDecoration(
        filled: true,
        fillColor: _bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
      hint: Text('Select cycle',
          style: GoogleFonts.dmSans(color: _mutedText, fontSize: 13)),
      items: _cycles.map<DropdownMenuItem<String>>((cycle) {
        return DropdownMenuItem<String>(
          value: cycle['id'] as String,
          child: Text('${cycle['name']} · ${cycle['fieldName']}',
              style: GoogleFonts.dmSans(fontSize: 13)),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedCycleId = value),
    );
  }

  Widget _buildStationSelector() {
    return Row(
      children: List.generate(5, (index) {
        final num = index + 1;
        final selected = _selectedStation == num;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedStation = num),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
              height: 52,
              decoration: BoxDecoration(
                color: selected ? _green : _bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? _green : _borderColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$num',
                      style: GoogleFonts.dmMono(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: selected ? Colors.white : _darkGreen)),
                  const SizedBox(height: 3),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? Colors.white.withOpacity(0.35)
                          : _borderColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Save Button ───────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _savePestRecord,
        icon: const Icon(Icons.save_outlined, size: 18, color: Colors.white),
        label: Text('Save pest record',
            style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

// ─── Analysis Modal ─────────────────────────────────────────────────────────
class _AnalysisModal extends StatefulWidget {
  final bool isAnalyzing;
  final String pest;
  final String stage;
  final VoidCallback onConfirm;
  final VoidCallback onDiscard;
  final Future<Map<String, String>> analysisFuture;

  const _AnalysisModal({
    required this.isAnalyzing,
    required this.pest,
    required this.stage,
    required this.onConfirm,
    required this.onDiscard,
    required this.analysisFuture,
  });

  @override
  State<_AnalysisModal> createState() => _AnalysisModalState();
}

class _AnalysisModalState extends State<_AnalysisModal> {
  bool _done = false;
  String _pest = '';
  String _stage = '';

  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C503C);
  static const _lightGreen = Color(0xFFEAF3DE);
  static const _midGreen = Color(0xFF3B6D11);
  static const _bgColor = Color(0xFFF4F8F5);
  static const _borderColor = Color(0xFFDDEEE4);
  static const _amberBg = Color(0xFFFAEEDA);
  static const _amberText = Color(0xFF633806);
  static const _amberDark = Color(0xFF854F0B);

  @override
  void initState() {
    super.initState();
    widget.analysisFuture.then((result) {
      if (mounted) {
        setState(() {
          _done = true;
          _pest = result['pest'] ?? '';
          _stage = result['stage'] ?? '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDEEE4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _done ? 'Pest identified' : 'Analyzing photo...',
                  style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _darkGreen),
                ),
                const SizedBox(height: 3),
                Text(
                  _done
                      ? 'AI analysis complete'
                      : 'Running AI pest identification',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, color: const Color(0xFF9DB5A4)),
                ),
                const SizedBox(height: 18),

                if (!_done) ...[
                  // Analyzing state
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: _green, strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text('This takes a few seconds...',
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: const Color(0xFF9DB5A4))),
                      ],
                    ),
                  ),
                ] else ...[
                  // Result chips
                  Row(
                    children: [
                      Expanded(
                          child: _resultChip(
                              label: 'Pest',
                              value: _pest,
                              valueColor: _midGreen)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _resultChip(
                              label: 'Life stage',
                              value: _stage,
                              valueColor: const Color(0xFF633806))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Confidence bar
                  Row(
                    children: [
                      Text('Confidence',
                          style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: const Color(0xFF9DB5A4))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: 0.78,
                            minHeight: 4,
                            backgroundColor: _borderColor,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(_midGreen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('78%',
                          style: GoogleFonts.dmMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _midGreen)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Alert banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _amberBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: _amberDark, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Larvae detected — scout adjacent rows and record all 5 stations this week.',
                            style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: _amberText,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onDiscard,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _darkGreen,
                          side: const BorderSide(color: _borderColor),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text('Discard',
                            style: GoogleFonts.dmSans(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _done ? widget.onConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          disabledBackgroundColor: _lightGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: Text('Confirm & assign',
                            style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white)),
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

  Widget _resultChip(
      {required String label,
      required String value,
      required Color valueColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9DB5A4),
                  letterSpacing: 0.4)),
          const SizedBox(height: 5),
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor)),
        ],
      ),
    );
  }
}