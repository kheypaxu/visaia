import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'field_creation.dart';
import 'package:visaia/screens/onboarding/welcome_screen.dart';
import 'package:visaia/screens/root_screen.dart';
import 'package:visaia/services/farm_service.dart';

class FieldAreaSetupScreen extends StatefulWidget {
  final String farmId;
  final List<LatLng> farmBoundary;
  final String farmName;
  final VoidCallback onFinished;

  const FieldAreaSetupScreen({
    super.key,
    required this.farmBoundary,
    required this.farmName,
    required this.onFinished,
    required this.farmId,
  });

  @override
  State<FieldAreaSetupScreen> createState() => _FieldAreaSetupState();
}

class _FieldAreaSetupState extends State<FieldAreaSetupScreen> {
  final List<Map<String, dynamic>> _fields = [];
  final FarmService _farmService = FarmService();
  String _userFirstName = '';
  bool _isLoadingUser = true;

  // Crop options
  static const List<Map<String, dynamic>> cropOptions = [
    {'name': 'Corn', 'icon': Icons.eco, 'color': Color(0xFFF5A623)},
    {'name': 'Rice', 'icon': Icons.rice_bowl, 'color': Color(0xFF8BC34A)},
    {'name': 'Soybean', 'icon': Icons.spa, 'color': Color(0xFF4CAF50)},
    {'name': 'Wheat', 'icon': Icons.grain, 'color': Color(0xFFD4A373)},
    {'name': 'Cotton', 'icon': Icons.cloud, 'color': Color(0xFF90CAF9)},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Load existing fields from Firestore
    _loadExistingFields();
  }

  /// Generates the next field name based on existing fields
  String _generateNextFieldName() {
    final existingNames = _fields.map((f) => f['name'] as String? ?? '').toList();
    
    // Get the prefix: farmName - Field
    final prefix = '${widget.farmName} - Field ';
    
    // Find the highest letter used
    int highestIndex = -1;
    for (final name in existingNames) {
      if (name.startsWith(prefix)) {
        final suffix = name.substring(prefix.length);
        if (suffix.length == 1 && suffix.contains(RegExp(r'^[A-Z]$'))) {
          final letterIndex = suffix.codeUnitAt(0) - 'A'.codeUnitAt(0);
          if (letterIndex > highestIndex) {
            highestIndex = letterIndex;
          }
        }
      }
    }
    
    // Next letter
    final nextIndex = highestIndex + 1;
    // If we exceed Z (25), start using AA, AB, etc.
    String nextLetter = _getLetterFromIndex(nextIndex);
    
    return '$prefix$nextLetter';
  }
  
  /// Converts index to letter (0=A, 1=B, ..., 25=Z, 26=AA, 27=AB, etc.)
  String _getLetterFromIndex(int index) {
    if (index < 0) return 'A';
    
    String result = '';
    int temp = index;
    
    // Handle single letters (A-Z)
    if (temp < 26) {
      return String.fromCharCode('A'.codeUnitAt(0) + temp);
    }
    
    // Handle multiple letters (AA, AB, ..., ZZ, AAA, etc.)
    while (temp >= 0) {
      final remainder = temp % 26;
      result = String.fromCharCode('A'.codeUnitAt(0) + remainder) + result;
      temp = (temp / 26).floor() - 1;
      if (temp < 0) break;
    }
    
    return result;
  }

  /// Extracts the first name from a full name string
  String _extractFirstName(String fullName) {
    if (fullName.isEmpty) return 'User';
    
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : 'User';
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('farmers')
            .doc(user.uid)
            .get();
        
        if (doc.exists && mounted) {
          final data = doc.data();
          if (data != null) {
            final fullName = data['fullName'] as String? ?? '';
            final firstName = _extractFirstName(fullName);
            setState(() {
              _userFirstName = firstName;
              _isLoadingUser = false;
            });
          } else {
            final firstName = user.displayName?.split(' ').first ?? 
                             user.email?.split('@').first ?? 
                             'User';
            setState(() {
              _userFirstName = firstName;
              _isLoadingUser = false;
            });
          }
        } else {
          final firstName = user.displayName?.split(' ').first ?? 
                           user.email?.split('@').first ?? 
                           'User';
          setState(() {
            _userFirstName = firstName;
            _isLoadingUser = false;
          });
        }
      } else {
        setState(() {
          _userFirstName = 'User';
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _userFirstName = 'User';
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _loadExistingFields() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('fields')
          .where('farmId', isEqualTo: widget.farmId)
          .get();

      if (mounted) {
        setState(() {
          _fields.addAll(snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Field',
              'acres': data['acres'] ?? 0,
              'crop': data['crop'],
              'cropIcon': data['cropIcon'],
              'cropColor': data['cropColor'],
              'boundaries': data['boundaries'],
            };
          }).toList());
        });
      }
    } catch (e) {
      debugPrint('Error loading existing fields: $e');
    }
  }

  void _addField() async {
    // Generate automatic field name
    final autoName = _generateNextFieldName();
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FieldCreation(
          farmBoundary: widget.farmBoundary,
          farmName: widget.farmName,
          existingFields: _fields,
          suggestedName: autoName, // Pass the auto-generated name here
          onFinished: () {
            Navigator.pop(context, {
              'name': autoName,
              'acres': 0,
              'boundaries': _fields.isNotEmpty ? _fields.last['boundaries'] : [],
            });
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _fields.add(result);
      });
    }
  }

  // Show crop selection dialog
  void _showCropSelectionDialog(int fieldIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select Crop',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a crop to assign to this field',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              ...cropOptions.map((crop) {
                final isSelected = _fields[fieldIndex]['crop'] == crop['name'];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _fields[fieldIndex]['crop'] = crop['name'];
                      _fields[fieldIndex]['cropIcon'] = crop['icon'];
                      _fields[fieldIndex]['cropColor'] = crop['color'];
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? crop['color'].withOpacity(0.1) 
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected 
                            ? crop['color'] 
                            : Colors.grey[200]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: crop['color'].withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            crop['icon'],
                            color: crop['color'],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            crop['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? crop['color'] : Colors.grey[800],
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: crop['color'],
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              // Clear crop option
              GestureDetector(
                onTap: () {
                  setState(() {
                    _fields[fieldIndex]['crop'] = null;
                    _fields[fieldIndex]['cropIcon'] = null;
                    _fields[fieldIndex]['cropColor'] = null;
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red[200]!,
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.remove_circle_outline,
                        color: Colors.red,
                        size: 24,
                      ),
                      SizedBox(width: 14),
                      Text(
                        'Remove Crop',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Field Setup"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // ================= HEADER =================
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Field Setup',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Define boundaries and assign crop cycles.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addField,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B57),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'New Field',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================= FIELDS LIST =================
          Expanded(
            child: _fields.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.agriculture,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No fields added yet',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap "New Field" to add your first field',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _fields.length,
                    itemBuilder: (context, index) {
                      final field = _fields[index];
                      final hasCrop = field['crop'] != null;
                      final cropIcon = field['cropIcon'] as IconData? ?? Icons.eco;
                      final cropColor = field['cropColor'] as Color? ?? Colors.green;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Field name with "Field X" badge
                                  Row(
                                    children: [
                                      Text(
                                        field['name'] ?? 'Unnamed Field',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E8B57)
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF2E8B57)
                                                .withOpacity(0.2),
                                          ),
                                        ),
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF2E8B57),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: hasCrop
                                          ? Colors.green[200]
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      hasCrop ? 'ACTIVE' : 'EMPTY',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: hasCrop
                                              ? Colors.green[800]
                                              : Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${field['acres'] ?? 0} Acres',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 12),
                              if (hasCrop)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cropColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: cropColor.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        cropIcon,
                                        color: cropColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          field['crop'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: cropColor,
                                          ),
                                        ),
                                      ),
                                      // Edit crop button
                                      GestureDetector(
                                        onTap: () => _showCropSelectionDialog(index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cropColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Change',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: cropColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                    ]
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ================= SAVE BUTTON =================
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _fields.isNotEmpty && !_isLoadingUser
                    ? () async {
                        try {
                          // 1. Save fields to Firestore with crop data
                          await _farmService.saveFields(
                            fields: _fields, 
                            farmId: widget.farmId,
                          );

                          // 2. Update user document
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({
                              'hasFields': true,
                            }, SetOptions(merge: true));
                          }

                          // Fake save delay
                          await Future.delayed(const Duration(milliseconds: 600));

                          if (!context.mounted) return;

                          // Navigate to InitializationScreen with real first name
                          Navigator.of(context, rootNavigator: true).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => InitializationScreen(
                                firstName: _userFirstName,
                                onFinished: () {
                                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const RootLayout()),
                                    (route) => false,
                                  );
                                },
                              ),
                            ),
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error saving fields: $e")),
                            );
                          }
                        }
                      }
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoadingUser
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SAVE FIELD SETUP',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}