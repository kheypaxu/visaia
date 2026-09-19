import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'package:visaia/services/firestore_safe_ext.dart';

/// Trap Setup Screen - Complete flow with map placement
/// 
/// This screen handles the entire trap setup process:
/// Step 1: Select number of traps
/// Step 2: Place traps on the field map
/// Step 3: Review and document all traps
class TrapSetupScreen extends StatefulWidget {
  final String cycleId;
  final String userId;
  final int initialStep; // 0 = Step 1 (Quantity), 2 = Step 3 (Review)
  final bool viewOnly; // If true, shows traps in view-only mode

  const TrapSetupScreen({
    super.key,
    required this.cycleId,
    required this.userId,
    this.initialStep = 0,
    this.viewOnly = false,
  });

  @override
  State<TrapSetupScreen> createState() => _TrapSetupScreenState();
}

class _TrapSetupScreenState extends State<TrapSetupScreen> {
  // Step management
  int _currentStep = 0;
  final int _totalSteps = 3;

  // Step 1: Quantity
  int _trapCount = 1;

  // Step 2: Map placement
  final List<TrapPlacement> _placedTraps = [];
  List<LatLng> _fieldBoundaries = [];
  LatLng _fieldCenter = const LatLng(0, 0);
  bool _isLoadingField = true;
  String? _fieldError;
  final MapController _mapController = MapController();

  // Step 3: Review
  List<TrapItem> _traps = [];

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _fetchFieldData();
  }

  // ========================
  // DATA FETCHING
  // ========================
  Future<void> _fetchFieldData() async {
    setState(() => _isLoadingField = true);

    try {
      final cycleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .safeGet();

      if (!cycleDoc.exists) {
        setState(() {
          _fieldError = 'Cycle not found';
          _isLoadingField = false;
        });
        return;
      }

      final cycleData = cycleDoc.data()!;
      final fieldId = cycleData['fieldId'];

      if (fieldId == null) {
        setState(() {
          _fieldError = 'No field associated with this cycle';
          _isLoadingField = false;
        });
        return;
      }

      final fieldDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('fields')
          .doc(fieldId)
          .safeGet();

      if (!fieldDoc.exists) {
        setState(() {
          _fieldError = 'Field not found';
          _isLoadingField = false;
        });
        return;
      }

      final fieldData = fieldDoc.data()!;
      setState(() {
        _fieldBoundaries = _extractBoundaries(fieldData);
        _fieldCenter = _calculateCenter(_fieldBoundaries);
        _isLoadingField = false;
      });
    } catch (e) {
      setState(() {
        _fieldError = 'Failed to load field data: $e';
        _isLoadingField = false;
      });
    }
  }

  List<LatLng> _extractBoundaries(Map<String, dynamic> fieldData) {
    final boundaries = fieldData['boundaries'] as List? ?? [];
    return boundaries.map((b) => LatLng(b['lat'], b['lng'])).toList();
  }

  LatLng _calculateCenter(List<LatLng> boundaries) {
    if (boundaries.isEmpty) return const LatLng(0, 0);
    double lat = 0, lng = 0;
    for (var point in boundaries) {
      lat += point.latitude;
      lng += point.longitude;
    }
    return LatLng(lat / boundaries.length, lng / boundaries.length);
  }

  // ========================
  // DASHED POLYLINE HELPER
  // ========================
  List<List<LatLng>> _createDashedPolyline(
    List<LatLng> points, {
    double dashLength = 0.00002,
    double gapLength = 0.00005,
  }) {
    List<List<LatLng>> dashedLines = [];
    if (points.length < 2) return dashedLines;

    final closedPoints = [...points];
    if (closedPoints.first != closedPoints.last) {
      closedPoints.add(closedPoints.first);
    }

    for (int i = 0; i < closedPoints.length - 1; i++) {
      final start = closedPoints[i];
      final end = closedPoints[i + 1];
      final dx = end.longitude - start.longitude;
      final dy = end.latitude - start.latitude;
      final distance = math.sqrt(dx * dx + dy * dy);
      final steps = (distance / (dashLength + gapLength)).floor();

      for (int j = 0; j < steps; j++) {
        final startStep = (j * (dashLength + gapLength)) / distance;
        final endStep =
            ((j * (dashLength + gapLength)) + dashLength) / distance;

        dashedLines.add([
          LatLng(start.latitude + dy * startStep,
              start.longitude + dx * startStep),
          LatLng(start.latitude + dy * endStep,
              start.longitude + dx * endStep),
        ]);
      }
    }
    return dashedLines;
  }

  // ========================
// ADD NEW TRAP
// ========================
void _addNewTrap() {
  // Show dialog to add trap details
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => _buildAddTrapDialog(context),
  );
}

Widget _buildAddTrapDialog(BuildContext context) {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  String selectedSide = 'North Side';

  final List<String> sides = [
    'North Side',
    'North-East Side',
    'East Side',
    'South-East Side',
    'South Side',
    'South-West Side',
    'West Side',
    'North-West Side',
  ];

  return AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    ),
    title: Text(
      'Add New Trap',
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0F5234),
      ),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter trap details',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 20),
          // Trap Name
          TextFormField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Trap Name',
              hintText: 'e.g., Trap 1',
              filled: true,
              fillColor: const Color(0xFFF5F7F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Zone/Side Dropdown
          DropdownButtonFormField<String>(
            value: selectedSide,
            decoration: InputDecoration(
              labelText: 'Zone / Side',
              filled: true,
              fillColor: const Color(0xFFF5F7F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: sides.map((String side) {
              return DropdownMenuItem<String>(
                value: side,
                child: Text(side),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                selectedSide = newValue;
              }
            },
          ),
          const SizedBox(height: 16),
          // Location Notes
          TextFormField(
            controller: notesController,
            decoration: InputDecoration(
              labelText: 'Location Notes',
              hintText: 'e.g., Near the old oak tree...',
              filled: true,
              fillColor: const Color(0xFFF5F7F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            maxLines: 2,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          'Cancel',
          style: GoogleFonts.inter(
            color: const Color(0xFF666666),
          ),
        ),
      ),
      ElevatedButton(
        onPressed: () {
          if (nameController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a trap name.'),
                backgroundColor: Color(0xFFC62828),
              ),
            );
            return;
          }

          // Create new trap placement
          // For manual addition, place at center of field
          final newTrap = TrapPlacement(
            position: _fieldCenter,
            placedAt: DateTime.now(),
          );

          setState(() {
            _placedTraps.add(newTrap);
            _trapCount = _placedTraps.length;
          });

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${nameController.text} added successfully!'),
              backgroundColor: const Color(0xFF0F5234),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0F5234),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        child: const Text('Add Trap'),
      ),
    ],
  );
}

  // ========================
  // NAVIGATION
  // ========================
  void _nextStep() {
    // If in view-only mode, just close
    if (widget.viewOnly) {
      Navigator.pop(context);
      return;
    }
    
    if (_currentStep == 0 && _trapCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 trap.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    if (_currentStep == 1 && _placedTraps.length < _trapCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please place all $_trapCount traps on the map.'),
          backgroundColor: Color(0xFFC62828),
        ),
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _completeSetup();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _completeSetup() {
    _saveTrapsToFirestore();
    _addToDailyLog();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: const Color(0xFF0F5234), size: 32),
            const SizedBox(width: 12),
            const Text('Traps Installed!'),
          ],
        ),
        content: Text(
          'Successfully configured ${_traps.length} traps in your field.\n\n'
          'Remember to:\n'
          '• Check traps weekly\n'
          '• Record your findings\n'
          '• Replace lures every 4-6 weeks',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F5234),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Back to Monitoring'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTrapsToFirestore() async {
    try {
      final trapData = _traps.map((trap) {
        return {
          'name': trap.name,
          'zone': trap.zone,
          'position': {
            'lat': trap.position.latitude,
            'lng': trap.position.longitude,
          },
          'installationDate': Timestamp.fromDate(trap.installationDate),
          'nextLureDate': Timestamp.fromDate(trap.nextLureDate),
          'notes': trap.notes,
        };
      }).toList();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('cycles')
          .doc(widget.cycleId)
          .update({
        'traps': trapData,
        'trapsInstalled': true,
        'trapInstallationDate': FieldValue.serverTimestamp(),
        'trapCount': _traps.length,
      });
    } catch (e) {
      debugPrint('Error saving traps: $e');
    }
  }

// ========================
// ADD TO DAILY LOG
// ========================
Future<void> _addToDailyLog() async {
  try {
    // Get today's date
    final now = DateTime.now();
    
    // Calculate the day number from planting date
    final cycleDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .safeGet();
    
    if (!cycleDoc.exists) return;
    
    final cycleData = cycleDoc.data()!;
    final plantingDate = (cycleData['plantingDate'] as Timestamp?)?.toDate();
    
    if (plantingDate == null) return;
    
    final dayIndex = now.difference(plantingDate).inDays;
    if (dayIndex < 0) return;
    
    final dayId = 'day_${(dayIndex + 1).toString().padLeft(2, '0')}';
    
    // Create the log entry as a normal completed task
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cycles')
        .doc(widget.cycleId)
        .collection('dailyLogs')
        .doc(dayId)
        .collection('activities')
        .doc();
    
    await docRef.set({
      'type': 'Installed ${_traps.length} Pheromone Traps',
      'notes': 'Installed ${_traps.length} pheromone traps in the field for pest monitoring.',
      'images': [],
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    debugPrint('✅ Trap installation added to daily log for day $dayId');
  } catch (e) {
    debugPrint('Error adding to daily log: $e');
  }
}

  // ========================
  // BUILD
  // ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildStep1Quantity(),
                _buildStep2MapPlacement(),
                _buildStep3Review(),
              ],
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  // ========================
  // APP BAR
  // ========================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Setup Trap',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A),
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline, color: Color(0xFF666666)),
          onPressed: () {
            // TODO: Show help dialog
          },
        ),
      ],
    );
  }

  Widget _buildAddTrapButton() {
  // If in view-only mode, show "Add Another Trap" button
  if (widget.viewOnly) {
    return GestureDetector(
      onTap: () {
        // Navigate back to step 1 to add more traps
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrapSetupScreen(
              cycleId: widget.cycleId,
              userId: widget.userId,
              initialStep: 0,
              viewOnly: false,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0E8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF0F5234).withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              color: const Color(0xFF0F5234),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Add Another Trap',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F5234),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Original button for first-time setup
  return GestureDetector(
    onTap: _addNewTrap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0F5234).withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add,
            color: const Color(0xFF0F5234),
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Add Another Trap',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F5234),
            ),
          ),
        ],
      ),
    ),
  );
}

  // ========================
  // PROGRESS INDICATOR
  // ========================
  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: isActive || isCompleted
                          ? const Color(0xFF0F5234)
                          : const Color(0xFFE8EAE5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive || isCompleted
                        ? const Color(0xFF0F5234)
                        : const Color(0xFFE8EAE5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive || isCompleted
                                  ? Colors.white
                                  : const Color(0xFF888888),
                            ),
                          ),
                  ),
                ),
                if (index < _totalSteps - 1) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ========================
  // STEP 1: QUANTITY
  // ========================
  Widget _buildStep1Quantity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Number of Traps',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F5234),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select how many units to install in your farm area.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_trapCount > 1) {
                          setState(() => _trapCount--);
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE8EDE8),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.remove,
                          color: Color(0xFF0F5234),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    Text(
                      '$_trapCount',
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F5234),
                      ),
                    ),
                    const SizedBox(width: 32),
                    GestureDetector(
                      onTap: () {
                        if (_trapCount < 20) {
                          setState(() => _trapCount++);
                        }
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F5234),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F5234).withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Recommended: 4-5 traps per hectare',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF888888),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trap placement guide',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F5234),
                  ),
                ),
                const SizedBox(height: 16),
                _buildChecklistItem(
                  'Place near field edge, ideally aligned with prevailing wind directions.',
                  true,
                ),
                const SizedBox(height: 12),
                _buildChecklistItem(
                  'Optimal height: 1-1.5 meters above ground level.',
                  false,
                ),
                const SizedBox(height: 12),
                _buildChecklistItem(
                  'Keep away from buildings or large dense tree lines that disrupt airflow.',
                  true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String text, bool checked) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: checked ? const Color(0xFF0F5234) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: checked ? const Color(0xFF0F5234) : const Color(0xFFD0D5D0),
              width: 2,
            ),
          ),
          child: checked
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF333333),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ========================
  // STEP 2: MAP PLACEMENT
  // ========================
  Widget _buildStep2MapPlacement() {
    if (_isLoadingField) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F5234)),
      );
    }

    if (_fieldError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _fieldError!,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.red.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Place Your Traps',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F5234),
                    ),
                  ),
                  Text(
                    'Tap on the map to place each trap',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5234).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF0F5234).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.ads_click,
                      color: const Color(0xFF0F5234),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_placedTraps.length} / $_trapCount',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F5234),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: const Color(0xFF0F5234).withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _fieldCenter,
                      initialZoom: 17.0,
                      minZoom: 14,
                      maxZoom: 20,
                      onTap: (tapPosition, point) {
                        _placeTrapOnMap(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                        userAgentPackageName: 'com.visaia.app',
                      ),
                      
                      // FIELD BOUNDARY
                      if (_fieldBoundaries.length >= 3)
                        PolygonLayer(
                          polygons: [
                            Polygon(
                              points: _fieldBoundaries,
                              color: const Color(0xFFFFBA27).withValues(alpha: 0.15),
                              borderColor: Colors.transparent,
                              borderStrokeWidth: 0,
                            ),
                          ],
                        ),
                      
                      if (_fieldBoundaries.length >= 3)
                        PolylineLayer(
                          polylines: _createDashedPolyline(_fieldBoundaries).map((segment) {
                            return Polyline(
                              points: segment,
                              color: const Color(0xFFFFBA27),
                              strokeWidth: 2.5,
                            );
                          }).toList(),
                        ),
                      
                      if (_fieldBoundaries.length >= 3)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _fieldCenter,
                              width: 80,
                              height: 40,
                              child: Column(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFBA27),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFFBA27),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      'Your Field',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFFFBA27),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      
                      // Placed traps
                      MarkerLayer(
                        markers: _placedTraps.map((trap) {
                          final index = _placedTraps.indexOf(trap);
                          return Marker(
                            width: 44,
                            height: 44,
                            point: trap.position,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F5234),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0F5234).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        spreadRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF0F5234).withValues(alpha: 0.2),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // Zoom controls
                  Positioned(
                    right: 12,
                    bottom: 80,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _mapController.move(_mapController.camera.center, 
                                _mapController.camera.zoom + 1);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFF0F5234),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            _mapController.move(_mapController.camera.center, 
                                _mapController.camera.zoom - 1);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.remove,
                              color: Color(0xFF0F5234),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            _mapController.move(_fieldCenter, 17.0);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: Color(0xFF0F5234),
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Instructions overlay
                  if (_placedTraps.length < _trapCount)
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tap the map to place trap ${_placedTraps.length + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Completed status
                  if (_placedTraps.length == _trapCount && _trapCount > 0)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'All $_trapCount traps placed!',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Undo button
                  if (_placedTraps.isNotEmpty)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: _removeLastTrap,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.undo,
                            color: Color(0xFFC62828),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _placeTrapOnMap(LatLng position) {
    if (_placedTraps.length >= _trapCount) return;

    setState(() {
      _placedTraps.add(
        TrapPlacement(
          position: position,
          placedAt: DateTime.now(),
        ),
      );
    });
  }

  void _removeLastTrap() {
    setState(() {
      if (_placedTraps.isNotEmpty) {
        _placedTraps.removeLast();
      }
    });
  }

  // ========================
  // STEP 3: REVIEW
  // ========================
  Widget _buildStep3Review() {
    if (_traps.isEmpty && _placedTraps.isNotEmpty) {
      _generateTrapItems();
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review & Document',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F5234),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify the placement details for each installed unit.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 20),
                _buildAddTrapButton(),
                const SizedBox(height: 16),

                // Mini map preview
                Container(
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: _fieldCenter,
                            initialZoom: 16.0,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
                              userAgentPackageName: 'com.visaia.app',
                            ),
                            if (_fieldBoundaries.length >= 3)
                              PolygonLayer(
                                polygons: [
                                  Polygon(
                                    points: _fieldBoundaries,
                                    color: const Color(0xFFFFBA27).withValues(alpha: 0.15),
                                    borderColor: Colors.transparent,
                                    borderStrokeWidth: 0,
                                  ),
                                ],
                              ),
                            if (_fieldBoundaries.length >= 3)
                              PolylineLayer(
                                polylines: _createDashedPolyline(_fieldBoundaries).map((segment) {
                                  return Polyline(
                                    points: segment,
                                    color: const Color(0xFFFFBA27),
                                    strokeWidth: 2,
                                  );
                                }).toList(),
                              ),
                            MarkerLayer(
                              markers: _placedTraps.map((trap) {
                                final index = _placedTraps.indexOf(trap);
                                return Marker(
                                  width: 28,
                                  height: 28,
                                  point: trap.position,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F5234),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.2),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        Container(
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF0F5234).withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                ..._traps.map((trap) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TrapCard(
                      trap: trap,
                      onNotesChanged: (notes) {
                        setState(() {
                          final index = _traps.indexOf(trap);
                          _traps[index].notes = notes;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _generateTrapItems() {
    final sides = [
      'North Side',
      'North-East Side',
      'East Side',
      'South-East Side',
      'South Side',
      'South-West Side',
      'West Side',
      'North-West Side',
    ];

    setState(() {
      _traps = _placedTraps.asMap().entries.map((entry) {
        final index = entry.key;
        final placement = entry.value;
        final sideIndex = index % sides.length;

        return TrapItem(
          id: 'trap_${index + 1}',
          name: 'Trap ${index + 1}',
          zone: sides[sideIndex],
          position: placement.position,
          installationDate: DateTime.now(),
          nextLureDate: DateTime.now().add(const Duration(days: 42)),
          notes: '',
        );
      }).toList();
    });
  }

  // ========================
  // BOTTOM NAVIGATION
  // ========================
Widget _buildBottomNavigation() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 12,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // PREV Button - Hide in view-only mode
          if (_currentStep > 0 && !widget.viewOnly)
            TextButton.icon(
              onPressed: _prevStep,
              icon: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Color(0xFF0F5234),
              ),
              label: Text(
                'PREV',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F5234),
                ),
              ),
            )
          else if (!widget.viewOnly)
            const SizedBox(width: 80),

          // Step indicator - Hide in view-only mode
          if (!widget.viewOnly)
            Text(
              'STEP ${_currentStep + 1} OF $_totalSteps',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF888888),
                letterSpacing: 0.5,
              ),
            ),

          // NEXT/DONE Button
          ElevatedButton.icon(
            onPressed: _nextStep,
            icon: Icon(
              _currentStep == _totalSteps - 1 || widget.viewOnly 
                  ? Icons.close 
                  : Icons.arrow_forward,
              size: 18,
              color: Colors.white,
            ),
            label: Text(
              widget.viewOnly ? 'CLOSE' 
                  : (_currentStep == _totalSteps - 1 ? 'DONE' : 'NEXT'),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F5234),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    ),
  );
}
}

// ========================
// TRAP PLACEMENT MODEL
// ========================
class TrapPlacement {
  final LatLng position;
  final DateTime placedAt;

  TrapPlacement({
    required this.position,
    required this.placedAt,
  });
}

// ========================
// TRAP ITEM MODEL
// ========================
class TrapItem {
  final String id;
  final String name;
  final String zone;
  final LatLng position;
  final DateTime installationDate;
  final DateTime nextLureDate;
  String notes;

  TrapItem({
    required this.id,
    required this.name,
    required this.zone,
    required this.position,
    required this.installationDate,
    required this.nextLureDate,
    this.notes = '',
  });
}

// ========================
// TRAP CARD WIDGET
// ========================
class TrapCard extends StatelessWidget {
  final TrapItem trap;
  final Function(String) onNotesChanged;

  const TrapCard({
    super.key,
    required this.trap,
    required this.onNotesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: const Color(0xFF0F5234),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trap.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        trap.zone,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF0F5234),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0E8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Active',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F5234),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INSTALLATION DATE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF888888),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(trap.installationDate),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT LURE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF888888),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(trap.nextLureDate),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC62828),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Location Notes',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: trap.notes,
              onChanged: onNotesChanged,
              decoration: InputDecoration(
                hintText: 'e.g., Near the old oak tree...',
                filled: true,
                fillColor: const Color(0xFFF5F7F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFB0B0B0),
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF1A1A1A),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}