import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class VerificationFormScreen extends StatefulWidget {
  const VerificationFormScreen({Key? key}) : super(key: key);

  @override
  _VerificationFormScreenState createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers
  final _fullNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _rsbsaIdController = TextEditingController();
  final _farmSizeController = TextEditingController();

  // Dropdown values
  String? _selectedSex;
  DateTime? _selectedBirthdate;
  String _farmerIdPath = 'No file selected';

  // List of sex options
  final List<String> _sexOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    // Validate authentication status before showing the form
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

  // Method to show date picker
  Future<void> _selectBirthdate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthdate) {
      setState(() {
        _selectedBirthdate = picked;
      });
    }
  }

  String? _base64Image;
  String _farmerIdFileName = 'No file selected';

  Future<void> _uploadFarmerId() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null) {
        Uint8List? fileBytes = result.files.first.bytes;

        if (fileBytes != null) {
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
    if (_formKey.currentState!.validate()) {
      if (_farmerIdFileName == 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload your Farmer ID')),
        );
        return;
      }

      try {
        User user = FirebaseAuth.instance.currentUser!;

        await FirebaseFirestore.instance
            .collection("farmers")
            .doc(user.uid)
            .set({
          "uid": user.uid,
          "email": user.email,
          "fullName": _fullNameController.text.trim(),
          "middleName": _middleNameController.text.trim(),
          "rsbsaId": _rsbsaIdController.text.trim(),
          "farmSize": double.parse(_farmSizeController.text),
          "sex": _selectedSex,
          "birthdate": _selectedBirthdate?.toIso8601String(),
          "farmerIdFileName": _farmerIdFileName,
          "farmerIdImage": _base64Image,
          "status": "pending",
          "createdAt": FieldValue.serverTimestamp(),
        });

        await FirebaseAuth.instance.signOut();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Your account is pending approval. Please wait for admin verification."),
            backgroundColor: Color(0xFF8DBA60),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make the app fullscreen to match RegistrationPage
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          // Background image layer
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
          // Dark blue overlay with 75% opacity
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF102216).withValues(alpha: 0.75),
          ),
          
          // Form content layer
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

                          // RSBSA ID Number Field
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
                              if (value == null || value.isEmpty) {
                                return 'Please enter your RSBSA ID number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

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

                          // Farmer ID Upload
                          ListTile(
                            title: Text(
                              'Farmer ID',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                            subtitle: Text(
                              _farmerIdPath == 'No file selected' 
                                  ? 'e.g., farmer_id.jpg'
                                  : _farmerIdPath,
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
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8DBA60),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Text(
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