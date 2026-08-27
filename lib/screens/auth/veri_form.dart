import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:developer' as developer;

class VerificationFormScreen extends StatefulWidget {
  const VerificationFormScreen({Key? key}) : super(key: key);

  @override
  _VerificationFormScreenState createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _rsbsaIdController = TextEditingController();
  final _farmSizeController = TextEditingController();

  String? _selectedSex;
  DateTime? _selectedBirthdate;
  final List<String> _sexOptions = ['Male', 'Female', 'Other'];

  String? _base64Image;
  String _farmerIdFileName = 'No file selected';
  
  bool _isSubmitting = false;
  
  // Track if user has RSBSA ID
  bool _hasRsbsaId = true; // Default to true
  
  // Track if user wants to skip farmer ID (only applicable for RSBSA holders)
  bool _skipFarmerId = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FirebaseAuth.instance.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unauthenticated access blocked. Redirecting to login.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _middleNameController.dispose();
    _rsbsaIdController.dispose();
    _farmSizeController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthdate) {
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  Future<void> _uploadFarmerId() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null) {
        Uint8List? fileBytes = result.files.first.bytes;

        if (fileBytes != null) {
          // Compress image to prevent memory issues
          String base64String = base64Encode(fileBytes);

          setState(() {
            _base64Image = base64String;
            _farmerIdFileName = result.files.first.name;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image selected successfully')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking file: $e')),
      );
    }
  }

  void _submitForm() async {
    if (_isSubmitting) return;
    
    if (!_formKey.currentState!.validate()) return;

    // Check farmer ID upload based on RSBSA status
    if (_hasRsbsaId) {
      // If they have RSBSA, they can skip farmer ID
      if (!_skipFarmerId && _farmerIdFileName == 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your Farmer ID or check "Skip"')),
        );
        return;
      }
    } else {
      // If they don't have RSBSA, they MUST upload an ID
      if (_farmerIdFileName == 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a valid government-issued ID')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        throw Exception('You have been logged out. Please register again.');
      }

      // Build farmer data
      Map<String, dynamic> farmerData = {
        "uid": user.uid,
        "email": user.email ?? '',
        "fullName": _fullNameController.text.trim(),
        "middleName": _middleNameController.text.trim(),
        "farmSize": double.parse(_farmSizeController.text),
        "sex": _selectedSex,
        "birthdate": _selectedBirthdate?.toIso8601String(),
        "status": "pending",
        "createdAt": FieldValue.serverTimestamp(),
        "hasRsbsaId": _hasRsbsaId,
      };

      // Handle RSBSA ID
      if (_hasRsbsaId) {
        farmerData["rsbsaId"] = _rsbsaIdController.text.trim();
        farmerData["skipFarmerId"] = _skipFarmerId;
        
        // Only add farmer ID image if not skipped
        if (!_skipFarmerId && _base64Image != null) {
          farmerData["farmerIdFileName"] = _farmerIdFileName;
          farmerData["farmerIdImage"] = _base64Image;
        } else {
          farmerData["farmerIdFileName"] = null;
          farmerData["farmerIdImage"] = null;
        }
      } else {
        // No RSBSA ID - must upload alternative ID
        farmerData["rsbsaId"] = null;
        farmerData["skipFarmerId"] = true; // Forced skip since no RSBSA
        farmerData["farmerIdFileName"] = _farmerIdFileName;
        farmerData["farmerIdImage"] = _base64Image;
      }

      developer.log('📤 Saving farmer data: $farmerData');

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection("farmers")
          .doc(user.uid)
          .set(farmerData);

      // Sign out after successful submission
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Your account is pending approval. Please wait for admin verification."
            ),
            backgroundColor: Color(0xFF8DBA60),
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
      
    } catch (e) {
      developer.log('❌ Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF102216).withValues(alpha: 0.75),
          ),
          
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      padding: const EdgeInsets.all(30.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: Colors.black,
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Logo and Title
                          Column(
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                width: 120,
                                height: 120,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'Verification Form',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Please complete your profile information.',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),

                          // Full Name Field
                          TextFormField(
                            controller: _fullNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              hintText: 'e.g., Juan Dela Cruz Jr.',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              prefixIcon: const Icon(Icons.person, color: Color(0xFF8DBA60)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF8DBA60)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Middle Name Field
                          TextFormField(
                            controller: _middleNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Middle Name',
                              hintText: 'e.g., Santos',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF8DBA60)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF8DBA60)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // RSBSA ID Toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.assignment_ind, color: Color(0xFF8DBA60)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Do you have an RSBSA ID?',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    ChoiceChip(
                                      label: Text(
                                        'Yes',
                                        style: GoogleFonts.inter(
                                          color: _hasRsbsaId ? Colors.black : Colors.white,
                                        ),
                                      ),
                                      selected: _hasRsbsaId,
                                      onSelected: (selected) {
                                        setState(() {
                                          _hasRsbsaId = selected;
                                          if (!selected) {
                                            _rsbsaIdController.clear();
                                          }
                                        });
                                      },
                                      selectedColor: const Color(0xFF8DBA60),
                                      backgroundColor: Colors.transparent,
                                      side: BorderSide(
                                        color: _hasRsbsaId ? const Color(0xFF8DBA60) : Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ChoiceChip(
                                      label: Text(
                                        'No',
                                        style: GoogleFonts.inter(
                                          color: !_hasRsbsaId ? Colors.black : Colors.white,
                                        ),
                                      ),
                                      selected: !_hasRsbsaId,
                                      onSelected: (selected) {
                                        setState(() {
                                          _hasRsbsaId = !selected;
                                          if (!_hasRsbsaId) {
                                            _rsbsaIdController.clear();
                                          }
                                        });
                                      },
                                      selectedColor: const Color(0xFF8DBA60),
                                      backgroundColor: Colors.transparent,
                                      side: BorderSide(
                                        color: !_hasRsbsaId ? const Color(0xFF8DBA60) : Colors.white.withValues(alpha: 0.3),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // RSBSA ID Field (only show if user has RSBSA ID)
                          if (_hasRsbsaId)
                            TextFormField(
                              controller: _rsbsaIdController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'RSBSA ID Number',
                                hintText: 'e.g., 1234-5678-9012',
                                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF8DBA60)),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                  borderSide: const BorderSide(color: Color(0xFF8DBA60)),
                                ),
                              ),
                              validator: (value) {
                                if (_hasRsbsaId && (value == null || value.isEmpty)) {
                                  return 'Please enter your RSBSA ID number';
                                }
                                return null;
                              },
                            ),
                          
                          if (_hasRsbsaId) const SizedBox(height: 16),

                          // Farm Size Field
                          TextFormField(
                            controller: _farmSizeController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Farm Size',
                              hintText: 'e.g., 5.5',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              suffixText: 'hectares',
                              suffixStyle: const TextStyle(color: Color(0xFF8DBA60)),
                              prefixIcon: const Icon(Icons.agriculture, color: Color(0xFF8DBA60)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF8DBA60)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your farm size';
                              }
                              if (double.tryParse(value) == null || double.tryParse(value)! <= 0) {
                                return 'Please enter a valid farm size';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Sex Dropdown
                          DropdownButtonFormField<String>(
                            style: const TextStyle(color: Colors.white),
                            dropdownColor: const Color(0xFF102216),
                            decoration: InputDecoration(
                              labelText: 'Sex',
                              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              prefixIcon: const Icon(Icons.people, color: Color(0xFF8DBA60)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: const BorderSide(color: Color(0xFF8DBA60)),
                              ),
                            ),
                            items: _sexOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedSex = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your sex';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Birthdate ListTile
                          ListTile(
                            title: Text(
                              'Birthdate',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                            subtitle: Text(
                              _selectedBirthdate == null
                                  ? 'e.g., January 1, 1990'
                                  : '${_selectedBirthdate!.day}/${_selectedBirthdate!.month}/${_selectedBirthdate!.year}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            leading: const Icon(Icons.calendar_today, color: Color(0xFF8DBA60)),
                            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                            tileColor: Colors.white.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            onTap: () => _selectBirthdate(context),
                          ),
                          const SizedBox(height: 16),

                          // Farmer ID Upload Section
                          if (_hasRsbsaId) ...[
                            // For users WITH RSBSA ID
                            Row(
                              children: [
                                Expanded(
                                  child: ListTile(
                                    title: Text(
                                      'Farmer ID (RSBSA ID Image)',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                    ),
                                    subtitle: Text(
                                      _farmerIdFileName == 'No file selected' 
                                          ? 'e.g., rsbsa_id.jpg'
                                          : _farmerIdFileName,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    leading: const Icon(Icons.cloud_upload, color: Color(0xFF8DBA60)),
                                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                                    tileColor: Colors.white.withValues(alpha: 0.05),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                    ),
                                    onTap: _skipFarmerId ? null : _uploadFarmerId,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Checkbox(
                                  value: _skipFarmerId,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _skipFarmerId = value ?? false;
                                      if (_skipFarmerId) {
                                        _base64Image = null;
                                        _farmerIdFileName = 'No file selected';
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF8DBA60),
                                  checkColor: Colors.black,
                                ),
                                Text(
                                  'Skip',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (_skipFarmerId) ...[
                              const SizedBox(height: 4),
                              Text(
                                '✅ RSBSA ID image skipped. You can upload it later.',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8DBA60),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ] else ...[
                            // For users WITHOUT RSBSA ID
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Since you don\'t have an RSBSA ID, please upload any valid government-issued ID for verification purposes.',
                                      style: GoogleFonts.inter(
                                        color: Colors.orange,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListTile(
                              title: Text(
                                'Alternative ID Upload',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                              ),
                              subtitle: Text(
                                _farmerIdFileName == 'No file selected' 
                                    ? 'e.g., passport, drivers_license.jpg'
                                    : _farmerIdFileName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              leading: const Icon(Icons.cloud_upload, color: Color(0xFF8DBA60)),
                              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                              tileColor: Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              onTap: _uploadFarmerId,
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8DBA60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Submit',
                                      style: GoogleFonts.inter(
                                        color: Colors.black,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Cancel Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF8DBA60)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF8DBA60),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}