import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui';

// CONSTANTS - Exact Hex Codes from Design
const Color kPrimaryGreen = Color(0xFF134E39);
const Color kBackgroundWhite = Color(0xFFF9FBFB);
const Color kCardWhite = Color(0xFFFFFFFF);
const Color kTextDark = Color(0xFF1A1C1E);
const Color kTextGrey = Color(0xFF5E6266);
const Color kArchiveRed = Color(0xFFC0392B);
const Color kArchiveBg = Color(0xFFFFE5E5);
const Color kBorderColor = Color(0xFFE8ECEF);

class EditCropCycleScreen extends StatefulWidget {
  final String cycleId;

  const EditCropCycleScreen({super.key, required this.cycleId});

  @override
  State<EditCropCycleScreen> createState() => _EditCropCycleScreenState();
}

class _EditCropCycleScreenState extends State<EditCropCycleScreen> {
  // State variables
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSaveModal = false;
  bool _showArchiveModal = false;
  String? _error;

  // Form controllers
  final TextEditingController _cycleNameController = TextEditingController();
  final TextEditingController _seedDensityController = TextEditingController();
  final TextEditingController _plantingDateController = TextEditingController();
  final TextEditingController _harvestDateController = TextEditingController();
  
  // Dropdown selections
  String _selectedFarmField = '';
  String _selectedFieldName = '';
  String? _selectedCropType;
  String? _selectedVariety;

  // Map state
  List<LatLng> _fieldBoundaries = [];
  LatLng _fieldCenter = const LatLng(0, 0);
  bool _hasFieldLocation = false;
  bool _isLoadingMap = false;

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Available fields for dropdown
  List<Map<String, dynamic>> _availableFields = [];
  bool _isLoadingFields = false;

  // Crop data with varieties (same as StartCroppingCycleScreen)
  final Map<String, List<String>> _cropVarieties = {
    'Corn': [
      'Hybrid Glutinous',
      'Conv. Hybrid',
      'GMO Hybrid',
      'Green Corn'
    ],
    'Soybean': [
      'Delta',
      'Pioneer',
      'Asgrow',
      'Syngenta'
    ],
    'Wheat': [
      'Hard Red Winter',
      'Soft Red Winter',
      'Hard Red Spring',
      'White Wheat'
    ],
    'Rice': [
      'Japonica',
      'Indica',
      'Glutinous',
      'Aromatic'
    ],
    'Cotton': [
      'Upland',
      'Pima',
      'Hybrid'
    ],
    'Barley': [
      'Two-Row',
      'Six-Row',
      'Hulless'
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadCycleData();
    _loadAvailableFields();
  }

  @override
  void dispose() {
    _cycleNameController.dispose();
    _seedDensityController.dispose();
    _plantingDateController.dispose();
    _harvestDateController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableFields() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingFields = true);
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fields')
          .get();

      setState(() {
        _availableFields = snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'name': doc.data()['fieldName'] ?? doc.data()['name'] ?? 'Unnamed Field',
                  'data': doc.data(),
                  'boundaries': doc.data()['boundaries'],
                })
            .toList();
        _isLoadingFields = false;
      });
    } catch (e) {
      setState(() => _isLoadingFields = false);
    }
  }

  Future<void> _loadCycleData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Please sign in to edit cycles';
        _isLoading = false;
      });
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cycles')
          .doc(widget.cycleId)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Cycle not found';
          _isLoading = false;
        });
        return;
      }

      final data = doc.data()!;
      _cycleNameController.text = data['cycleName'] ?? '';
      _selectedCropType = data['cropType'] ?? data['cropVariety'] ?? '';
      _selectedVariety = data['cropVariety'] ?? '';
      _selectedFarmField = data['fieldId'] ?? '';
      _selectedFieldName = data['fieldName'] ?? '';
      
      // Set seed density
      final seedDensity = data['seedDensity'];
      if (seedDensity != null) {
        _seedDensityController.text = seedDensity.toString();
      }

      // Format dates
      final plantingDate = data['plantingDate'] as Timestamp?;
      if (plantingDate != null) {
        _plantingDateController.text = _formatDate(plantingDate.toDate());
      }

      final harvestDate = data['harvestDate'] as Timestamp?;
      if (harvestDate != null) {
        _harvestDateController.text = _formatDate(harvestDate.toDate());
      }

      // Load field boundaries if field is selected
      if (_selectedFarmField.isNotEmpty) {
        await _loadFieldBoundaries(_selectedFarmField);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load cycle data';
        _isLoading = false;
      });
    }
  }

  // Same boundary loading logic as CycleDetailsScreen
  Future<void> _loadFieldBoundaries(String fieldId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoadingMap = true);

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fields')
          .doc(fieldId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final boundaries = _extractBoundaries(data);

        setState(() {
          _fieldBoundaries = boundaries;
          if (boundaries.isNotEmpty) {
            _fieldCenter = _calculateCenter(boundaries);
            _hasFieldLocation = true;
          } else {
            _hasFieldLocation = false;
          }
          _isLoadingMap = false;
        });
      } else {
        setState(() {
          _fieldBoundaries = [];
          _hasFieldLocation = false;
          _isLoadingMap = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading field boundaries: $e');
      setState(() {
        _fieldBoundaries = [];
        _hasFieldLocation = false;
        _isLoadingMap = false;
      });
    }
  }

  List<LatLng> _extractBoundaries(Map<String, dynamic> fieldData) {
    try {
      // Try different possible boundary formats
      
      // Format 1: List of GeoPoints or Maps
      if (fieldData['boundaries'] != null) {
        final bounds = fieldData['boundaries'];
        if (bounds is List && bounds.isNotEmpty) {
          final result = bounds.map((b) {
            if (b is GeoPoint) {
              return LatLng(b.latitude, b.longitude);
            } else if (b is Map) {
              final lat = b['lat'] ?? b['latitude'];
              final lng = b['lng'] ?? b['longitude'];
              if (lat != null && lng != null) {
                try {
                  return LatLng(
                    lat is num ? lat.toDouble() : double.parse(lat.toString()),
                    lng is num ? lng.toDouble() : double.parse(lng.toString()),
                  );
                } catch (_) {
                  return null;
                }
              }
            }
            return null;
          }).whereType<LatLng>().toList();

          if (result.isNotEmpty) return result;
        }
      }

      // Format 2: Individual latitude/longitude fields
      if (fieldData['latitude'] != null && fieldData['longitude'] != null) {
        try {
          final lat = fieldData['latitude'];
          final lng = fieldData['longitude'];
          final latVal = lat is num ? lat.toDouble() : double.parse(lat.toString());
          final lngVal = lng is num ? lng.toDouble() : double.parse(lng.toString());

          // Create a small square around the point for visualization
          final size = 0.001; // ~100 meters
          return [
            LatLng(latVal - size, lngVal - size),
            LatLng(latVal - size, lngVal + size),
            LatLng(latVal + size, lngVal + size),
            LatLng(latVal + size, lngVal - size),
          ];
        } catch (_) {
          return [];
        }
      }

      return [];
    } catch (e) {
      debugPrint('Error extracting boundaries: $e');
      return [];
    }
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

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveChanges() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to save changes');
      return;
    }

    // Validate inputs
    if (_cycleNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter a cycle name');
      return;
    }

    if (_selectedFarmField.isEmpty) {
      _showSnackBar('Please select a farm/field');
      return;
    }

    if (_selectedCropType == null || _selectedCropType!.isEmpty) {
      _showSnackBar('Please select a crop type');
      return;
    }

    if (_selectedVariety == null || _selectedVariety!.isEmpty) {
      _showSnackBar('Please select a variety');
      return;
    }

    final plantingDate = _parseDate(_plantingDateController.text);
    if (plantingDate == null) {
      _showSnackBar('Please enter a valid planting date (MM/DD/YYYY)');
      return;
    }

    final harvestDate = _parseDate(_harvestDateController.text);
    if (harvestDate == null) {
      _showSnackBar('Please enter a valid harvest date (MM/DD/YYYY)');
      return;
    }

    if (harvestDate.isBefore(plantingDate)) {
      _showSnackBar('Harvest date must be after planting date');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Get field name from selected field
      String fieldName = _selectedFieldName;
      for (final field in _availableFields) {
        if (field['id'] == _selectedFarmField) {
          fieldName = field['name'] ?? '';
          break;
        }
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cycles')
          .doc(widget.cycleId)
          .update({
        'cycleName': _cycleNameController.text.trim(),
        'fieldId': _selectedFarmField,
        'fieldName': fieldName,
        'cropType': _selectedCropType,
        'cropVariety': _selectedVariety,
        'plantingDate': Timestamp.fromDate(plantingDate),
        'harvestDate': Timestamp.fromDate(harvestDate),
        'seedDensity': double.tryParse(_seedDensityController.text) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _showSaveModal = false;
        _isSaving = false;
      });

      _showSnackBar('Changes saved successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Failed to save changes: $e');
    }
  }

  Future<void> _archiveCycle() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('cycles')
          .doc(widget.cycleId)
          .update({
        'isArchived': true,
        'isCompleted': true,
        'archivedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _showArchiveModal = false;
        _isSaving = false;
      });

      _showSnackBar('Cycle archived successfully');
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Failed to archive cycle: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kPrimaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initialDate = _parseDate(controller.text) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimaryGreen,
              onPrimary: Colors.white,
              onSurface: kTextDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundWhite,
      body: Stack(
        children: [
          // --- SCREEN 1: EDIT FORM ---
          _buildScreen1(),

          // --- SCREEN 2: SAVE CHANGES MODAL ---
          if (_showSaveModal)
            _buildOverlayWrapper(
              child: _buildSaveModal(),
              onDismiss: () => setState(() => _showSaveModal = false),
            ),

          // --- SCREEN 3: ARCHIVE MODAL ---
          if (_showArchiveModal)
            _buildOverlayWrapper(
              child: _buildArchiveModal(),
              onDismiss: () => setState(() => _showArchiveModal = false),
            ),

          // Loading overlay
          if (_isLoading || _isSaving)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: kPrimaryGreen,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // SCREEN 1 implementation
  Widget _buildScreen1() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16, color: kTextGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  _sectionHeader("PHASE 01", "Cycle Identity"),
                  const SizedBox(height: 16),
                  _buildInputField(
                    "CYCLE NAME",
                    _cycleNameController,
                    hint: 'Enter cycle name',
                  ),
                  const SizedBox(height: 16),
                  _buildFarmFieldDropdown(),
                  const SizedBox(height: 16),
                  _buildMapView(),
                  const SizedBox(height: 32),
                  _sectionHeader("PHASE 02", "Botanical Details"),
                  const SizedBox(height: 16),
                  // Crop Type Dropdown
                  _buildDropdownField(
                    "CROP TYPE",
                    _selectedCropType,
                    _cropVarieties.keys.toList(),
                    (value) {
                      setState(() {
                        _selectedCropType = value;
                        _selectedVariety = null; // Reset variety when crop changes
                      });
                    },
                    icon: Icons.eco_outlined,
                  ),
                  const SizedBox(height: 16),
                  // Variety Dropdown
                  _buildDropdownField(
                    "VARIETY",
                    _selectedVariety,
                    _selectedCropType != null 
                        ? _cropVarieties[_selectedCropType] ?? []
                        : [],
                    (value) {
                      setState(() {
                        _selectedVariety = value;
                      });
                    },
                    icon: Icons.spa_outlined,
                    isEnabled: _selectedCropType != null,
                    hint: _selectedCropType == null 
                        ? 'Select crop type first' 
                        : 'Select variety',
                  ),
                  const SizedBox(height: 16),
                  _buildDateInputField(
                    "PLANTING DATE",
                    _plantingDateController,
                    Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDateInputField(
                    "EST. HARVEST",
                    _harvestDateController,
                    Icons.event_note_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    "TARGET SEED DENSITY (kg)",
                    _seedDensityController,
                    hint: 'Enter seed density',
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 40),
                  _buildArchiveButton(),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      "ARCHIVED CYCLES REMAIN VISIBLE IN\nHISTORICAL REPORTS",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kTextGrey,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: kPrimaryGreen),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          const Text(
            "Edit Crop Cycle",
            style: TextStyle(
              color: kPrimaryGreen,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _isLoading ? null : () => setState(() => _showSaveModal = true),
            child: Text(
              "Save",
              style: TextStyle(
                color: _isLoading ? kTextGrey : kPrimaryGreen,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String phase, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          phase,
          style: const TextStyle(
            color: Color(0xFF27AE60),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            color: kPrimaryGreen,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType? keyboardType,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: kTextGrey,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: kPrimaryGreen,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: kTextGrey.withOpacity(0.5),
                fontSize: 16,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmFieldDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "FARM / FIELD SELECTION",
            style: TextStyle(
              color: kTextGrey,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedFarmField.isNotEmpty ? _selectedFarmField : null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              color: kTextDark,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            hint: _isLoadingFields
                ? const Text('Loading fields...')
                : const Text('Select a field'),
            items: _availableFields.map((field) {
              return DropdownMenuItem<String>(
                value: field['id'],
                child: Text(field['name'] ?? 'Unnamed Field'),
              );
            }).toList(),
            onChanged: _isLoading ? null : (value) {
              setState(() {
                _selectedFarmField = value ?? '';
                _selectedFieldName = '';
                for (final field in _availableFields) {
                  if (field['id'] == _selectedFarmField) {
                    _selectedFieldName = field['name'] ?? '';
                    break;
                  }
                }
              });
              if (_selectedFarmField.isNotEmpty) {
                _loadFieldBoundaries(_selectedFarmField);
              } else {
                setState(() {
                  _fieldBoundaries = [];
                  _hasFieldLocation = false;
                });
              }
            },
            icon: const Icon(Icons.keyboard_arrow_down, color: kTextGrey),
          ),
        ],
      ),
    );
  }

  // Dropdown field for crop type and variety
  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged, {
    IconData? icon,
    bool isEnabled = true,
    String hint = 'Select an option',
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: kPrimaryGreen, size: 16),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: kTextGrey,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              color: isEnabled ? kTextDark : kTextGrey,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            hint: Text(
              hint,
              style: TextStyle(
                color: kTextGrey.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: isEnabled ? onChanged : null,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: isEnabled ? kTextGrey : kTextGrey.withOpacity(0.3),
            ),
          ),
          if (!isEnabled && value == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Please select a crop type first',
                style: TextStyle(
                  fontSize: 11,
                  color: kTextGrey.withOpacity(0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Working Map View
  Widget _buildMapView() {
    return Container(
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "FIELD LOCATION",
                  style: TextStyle(
                    color: kTextGrey,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.map_outlined, size: 14, color: kTextGrey),
                    SizedBox(width: 4),
                    Text(
                      "Map View",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Map
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 180,
                width: double.infinity,
                color: const Color(0xFFF1F3F1),
                child: _isLoadingMap
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kPrimaryGreen,
                          ),
                        ),
                      )
                    : _hasFieldLocation && _fieldBoundaries.isNotEmpty
                        ? _buildFieldMap()
                        : _buildEmptyMap(),
              ),
            ),
          ),

          // Footer info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _hasFieldLocation ? Icons.check_circle : Icons.info_outline,
                  size: 16,
                  color: _hasFieldLocation ? kPrimaryGreen : kTextGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hasFieldLocation
                        ? 'Field location loaded from selected field'
                        : 'Select a field to view its location on the map',
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasFieldLocation ? kPrimaryGreen : kTextGrey,
                      fontWeight: _hasFieldLocation ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldMap() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: _fieldCenter,
        initialZoom: 15.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
          userAgentPackageName: 'com.visaia.app',
        ),
        if (_fieldBoundaries.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: _fieldBoundaries,
                color: kPrimaryGreen.withOpacity(0.15),
                borderColor: kPrimaryGreen,
                borderStrokeWidth: 2,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyMap() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 40,
            color: Color(0xFFCCCCCC),
          ),
          SizedBox(height: 8),
          Text(
            'No field location available',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFFAAAAAA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInputField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return GestureDetector(
      onTap: () => _selectDate(controller),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kBorderColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: kTextGrey,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: kPrimaryGreen, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: AbsorbPointer(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(
                        color: kTextDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: kTextGrey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchiveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : () => setState(() => _showArchiveModal = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5E5),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.archive_outlined, color: kArchiveRed, size: 22),
            const SizedBox(width: 10),
            Text(
              "Archive This Crop Cycle",
              style: TextStyle(
                color: _isLoading ? kTextGrey : kArchiveRed,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HELPER: Modal Wrapper with Blur
  Widget _buildOverlayWrapper({
    required Widget child,
    required VoidCallback onDismiss,
  }) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            color: Colors.black.withOpacity(0.1),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {}, // Prevent click-through
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // --- SCREEN 2: SAVE CHANGES MODAL ---
  Widget _buildSaveModal() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFC8F7DC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_turned_in_outlined,
              color: kPrimaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Save Changes?",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: kTextGrey,
                fontSize: 14,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: "Are you sure you want to save the updates to ",
                ),
                TextSpan(
                  text: _cycleNameController.text.isEmpty
                      ? "this cycle"
                      : _cycleNameController.text,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kPrimaryGreen,
                  ),
                ),
                const TextSpan(
                  text: "? Previous parameters will be updated.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _modalButton(
            "Save Changes",
            kPrimaryGreen,
            Colors.white,
            _saveChanges,
          ),
          const SizedBox(height: 12),
          _modalButton(
            "Cancel",
            Colors.transparent,
            kTextGrey,
            () => setState(() => _showSaveModal = false),
            hasBorder: true,
          ),
        ],
      ),
    );
  }

  // --- SCREEN 3: ARCHIVE MODAL ---
  Widget _buildArchiveModal() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFFEBD2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.archive_outlined,
              color: Color(0xFF7E5700),
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Archive This Crop Cycle?",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: kTextGrey,
                fontSize: 14,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: "This will move "),
                TextSpan(
                  text: _cycleNameController.text.isEmpty
                      ? "'this cycle'"
                      : "'${_cycleNameController.text}'",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const TextSpan(
                  text:
                      " to your historical records. You will no longer be able to record active monitoring data for this field.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _modalButton(
            "Archive Cycle",
            const Color(0xFF5C3D00),
            Colors.white,
            _archiveCycle,
          ),
          const SizedBox(height: 12),
          _modalButton(
            "Keep Active",
            const Color(0xFFE8ECEF),
            kTextDark,
            () => setState(() => _showArchiveModal = false),
          ),
        ],
      ),
    );
  }

  Widget _modalButton(
    String text,
    Color bg,
    Color textColor,
    VoidCallback onTap, {
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: _isSaving ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: hasBorder ? Border.all(color: kBorderColor) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}