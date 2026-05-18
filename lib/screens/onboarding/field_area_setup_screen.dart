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

  void _addField() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FieldCreation(
          farmBoundary: widget.farmBoundary,
          farmName: widget.farmName,
          existingFields: _fields,
          onFinished: () {
            Navigator.pop(context, {'name': 'New Field', 'acres': 0});
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
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _fields.length,
                    itemBuilder: (context, index) {
                      final field = _fields[index];
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
                                  Text(
                                    field['name'] ?? 'Unnamed Field',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: field['crop'] != null
                                          ? Colors.green[200]
                                          : Colors.grey[300],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      field['crop'] != null ? 'ACTIVE' : 'EMPTY',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: field['crop'] != null
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
                              if (field['crop'] != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.eco, size: 18),
                                      const SizedBox(width: 8),
                                      Text(field['crop']),
                                    ],
                                  ),
                                )
                              else
                                GestureDetector(
                                  onTap: () {
                                    // Handle crop assignment
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add, size: 16),
                                        SizedBox(width: 8),
                                        Text('Assign Crop'),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
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
                  onPressed: _fields.isNotEmpty
                    ? () async {
                        try {
                          // 1. Save fields to Firestore
                          await _farmService.saveFields(fields: _fields, farmId: widget.farmId,);

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

                          Navigator.of(context, rootNavigator: true).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => InitializationScreen(
                                firstName: 'Sample',
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
                  child: const Text(
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
