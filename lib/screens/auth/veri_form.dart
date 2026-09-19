import 'dart:ui';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/screens/auth/login_screen.dart';

class VerificationFormScreen extends StatefulWidget {
  const VerificationFormScreen({super.key});

  @override
  State<VerificationFormScreen> createState() => _VerificationFormScreenState();
}

class _VerificationFormScreenState extends State<VerificationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Name controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String? _selectedExtension = 'None';
  final List<String> _extensionOptions = ['None', 'Jr.', 'Sr.', 'II', 'III', 'IV', 'V'];

  // Other form controllers
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
          SnackBar(
            content: Text(
              'Unauthenticated access blocked. Redirecting to login.',
              style: GoogleFonts.epilogue(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _rsbsaIdController.dispose();
    _farmSizeController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthdate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthdate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF2EAA4D),
              onPrimary: Colors.white,
              surface: Color(0xFF1B2E15),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1B2E15),
            ),
          ),
          child: child!,
        );
      },
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
          String base64String = base64Encode(fileBytes);

          setState(() {
            _base64Image = base64String;
            _farmerIdFileName = result.files.first.name;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Image selected: ${result.files.first.name}',
                  style: GoogleFonts.epilogue(),
                ),
                backgroundColor: const Color(0xFF1A5C30),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking file: $e',
              style: GoogleFonts.epilogue(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _submitForm() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) return;

    if (_hasRsbsaId) {
      if (!_skipFarmerId && _farmerIdFileName == 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please upload your Farmer ID or check "Skip"',
              style: GoogleFonts.epilogue(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    } else {
      if (_farmerIdFileName == 'No file selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please upload a valid government-issued ID',
              style: GoogleFonts.epilogue(),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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

      final firstName = _firstNameController.text.trim();
      final middleName = _middleNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final extension = (_selectedExtension != null && _selectedExtension != 'None')
          ? _selectedExtension!.trim()
          : '';

      // Combine structured name fields into full name
      final nameParts = <String>[];
      if (firstName.isNotEmpty) nameParts.add(firstName);
      if (middleName.isNotEmpty) nameParts.add(middleName);
      if (lastName.isNotEmpty) nameParts.add(lastName);
      if (extension.isNotEmpty) nameParts.add(extension);
      final fullName = nameParts.join(' ');

      // Build farmer data
      Map<String, dynamic> farmerData = {
        "uid": user.uid,
        "email": user.email ?? '',
        "firstName": firstName,
        "middleName": middleName,
        "lastName": lastName,
        "extension": extension.isNotEmpty ? extension : null,
        "fullName": fullName,
        "name": fullName, // for broad compatibility
        "farmSize": double.parse(_farmSizeController.text.trim()),
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

        if (!_skipFarmerId && _base64Image != null) {
          farmerData["farmerIdFileName"] = _farmerIdFileName;
          farmerData["farmerIdImage"] = _base64Image;
        } else {
          farmerData["farmerIdFileName"] = null;
          farmerData["farmerIdImage"] = null;
        }
      } else {
        farmerData["rsbsaId"] = null;
        farmerData["skipFarmerId"] = true;
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
          SnackBar(
            content: Text(
              "Your account is pending approval. Please wait for admin verification.",
              style: GoogleFonts.epilogue(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1A5C30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
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
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
              style: GoogleFonts.epilogue(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? suffixText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.epilogue(
        color: Colors.white.withValues(alpha: 0.38),
        fontSize: 13.5,
      ),
      suffixText: suffixText,
      suffixStyle: GoogleFonts.epilogue(
        color: const Color(0xFF81C784),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      prefixIcon: prefixIcon,
      isDense: true,
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.22),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF2EAA4D),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5.0),
      child: Text(
        label,
        style: GoogleFonts.epilogue(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Colors.white.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge transparent system overlay for true full screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B0D),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen background image layer (covers entire display)
          Positioned.fill(
            child: Image.asset(
              'assets/images/login-bg.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
            ),
          ),

          // 2. Subtle gradient overlay for readability and depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.12),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),

          // 3. Main content (designed to fit viewport cleanly without scrolling)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Glassmorphic Verification Card (No top logo/brand banner)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(28.0),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0,
                                  vertical: 20.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E3E24).withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(28.0),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Card Header Row with Back/Close button & Title
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              if (Navigator.canPop(context)) {
                                                Navigator.pop(context);
                                              } else {
                                                Navigator.pushReplacement(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => const LoginPage()),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(7),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.25),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_back_ios_new_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                RichText(
                                                  text: TextSpan(
                                                    style: GoogleFonts.epilogue(
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.w800,
                                                      color: Colors.white,
                                                    ),
                                                    children: [
                                                      const TextSpan(text: 'Farmer '),
                                                      TextSpan(
                                                        text: 'Verification',
                                                        style: GoogleFonts.epilogue(
                                                          fontSize: 22,
                                                          fontWeight: FontWeight.w800,
                                                          fontStyle: FontStyle.italic,
                                                          color: const Color(0xFF2EAA4D),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  'Complete your profile details to proceed',
                                                  style: GoogleFonts.epilogue(
                                                    fontSize: 12,
                                                    color: Colors.white.withValues(alpha: 0.75),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 16),

                                      // Row 1: First Name & Last Name (Side by Side)
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // First Name
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('FIRST NAME'),
                                                TextFormField(
                                                  controller: _firstNameController,
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  cursorColor: const Color(0xFF2EAA4D),
                                                  decoration: _inputDecoration(
                                                    hintText: 'e.g., Juan',
                                                  ),
                                                  validator: (value) {
                                                    if (value == null || value.trim().isEmpty) {
                                                      return 'Required';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Last Name
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('LAST NAME'),
                                                TextFormField(
                                                  controller: _lastNameController,
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  cursorColor: const Color(0xFF2EAA4D),
                                                  decoration: _inputDecoration(
                                                    hintText: 'e.g., Dela Cruz',
                                                  ),
                                                  validator: (value) {
                                                    if (value == null || value.trim().isEmpty) {
                                                      return 'Required';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Row 2: Middle Name & Suffix / Extension
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Middle Name
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('MIDDLE NAME (OPTIONAL)'),
                                                TextFormField(
                                                  controller: _middleNameController,
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  cursorColor: const Color(0xFF2EAA4D),
                                                  decoration: _inputDecoration(
                                                    hintText: 'e.g., Santos',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Suffix Dropdown
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('SUFFIX'),
                                                DropdownButtonFormField<String>(
                                                  initialValue: _selectedExtension,
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  dropdownColor: const Color(0xFF1B2E15),
                                                  icon: const Icon(
                                                    Icons.keyboard_arrow_down_rounded,
                                                    color: Colors.white70,
                                                    size: 18,
                                                  ),
                                                  decoration: _inputDecoration(hintText: 'None'),
                                                  items: _extensionOptions.map((String ext) {
                                                    return DropdownMenuItem<String>(
                                                      value: ext,
                                                      child: Text(
                                                        ext,
                                                        style: GoogleFonts.epilogue(color: Colors.white),
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged: (String? val) {
                                                    setState(() {
                                                      _selectedExtension = val;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Row 3: Sex Dropdown & Birthdate Picker
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Sex
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('SEX'),
                                                DropdownButtonFormField<String>(
                                                  initialValue: _selectedSex,
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  dropdownColor: const Color(0xFF1B2E15),
                                                  icon: const Icon(
                                                    Icons.keyboard_arrow_down_rounded,
                                                    color: Colors.white70,
                                                    size: 18,
                                                  ),
                                                  decoration: _inputDecoration(hintText: 'Select sex'),
                                                  items: _sexOptions.map((String value) {
                                                    return DropdownMenuItem<String>(
                                                      value: value,
                                                      child: Text(
                                                        value,
                                                        style: GoogleFonts.epilogue(color: Colors.white),
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
                                                      return 'Required';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Birthdate
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('BIRTHDATE'),
                                                GestureDetector(
                                                  onTap: () => _selectBirthdate(context),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.22),
                                                      borderRadius: BorderRadius.circular(14),
                                                      border: Border.all(
                                                        color: Colors.white.withValues(alpha: 0.22),
                                                        width: 1.0,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.calendar_today_outlined,
                                                          color: Color(0xFF2EAA4D),
                                                          size: 16,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            _selectedBirthdate == null
                                                                ? 'Pick date'
                                                                : '${_selectedBirthdate!.day.toString().padLeft(2, '0')}/${_selectedBirthdate!.month.toString().padLeft(2, '0')}/${_selectedBirthdate!.year}',
                                                            style: GoogleFonts.epilogue(
                                                              color: _selectedBirthdate == null
                                                                  ? Colors.white.withValues(alpha: 0.38)
                                                                  : Colors.white,
                                                              fontSize: 13,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
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

                                      const SizedBox(height: 12),

                                      // Row 4: Farm Size & RSBSA ID Toggle
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Farm Size
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('FARM SIZE'),
                                                TextFormField(
                                                  controller: _farmSizeController,
                                                  keyboardType: const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white,
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  cursorColor: const Color(0xFF2EAA4D),
                                                  decoration: _inputDecoration(
                                                    hintText: 'e.g., 2.5',
                                                    suffixText: 'ha',
                                                  ),
                                                  validator: (value) {
                                                    if (value == null || value.trim().isEmpty) {
                                                      return 'Required';
                                                    }
                                                    if (double.tryParse(value.trim()) == null ||
                                                        double.parse(value.trim()) <= 0) {
                                                      return 'Invalid size';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // RSBSA ID Toggle
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildFieldLabel('HAS RSBSA ID?'),
                                                Container(
                                                  height: 44,
                                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.22),
                                                    borderRadius: BorderRadius.circular(14),
                                                    border: Border.all(
                                                      color: Colors.white.withValues(alpha: 0.22),
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                    children: [
                                                      GestureDetector(
                                                        onTap: () => setState(() => _hasRsbsaId = true),
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: _hasRsbsaId
                                                                ? const Color(0xFF1B6A2D)
                                                                : Colors.transparent,
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: Text(
                                                            'Yes',
                                                            style: GoogleFonts.epilogue(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                              color: _hasRsbsaId ? Colors.white : Colors.white60,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          setState(() {
                                                            _hasRsbsaId = false;
                                                            _rsbsaIdController.clear();
                                                          });
                                                        },
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: !_hasRsbsaId
                                                                ? const Color(0xFF1B6A2D)
                                                                : Colors.transparent,
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: Text(
                                                            'No',
                                                            style: GoogleFonts.epilogue(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                              color: !_hasRsbsaId ? Colors.white : Colors.white60,
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
                                        ],
                                      ),

                                      const SizedBox(height: 12),

                                      // Row 5: RSBSA ID Number (Conditional)
                                      if (_hasRsbsaId) ...[
                                        _buildFieldLabel('RSBSA ID NUMBER'),
                                        TextFormField(
                                          controller: _rsbsaIdController,
                                          style: GoogleFonts.epilogue(
                                            color: Colors.white,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          cursorColor: const Color(0xFF2EAA4D),
                                          decoration: _inputDecoration(
                                            hintText: 'e.g., 1234-5678-9012',
                                            prefixIcon: const Icon(
                                              Icons.credit_card_outlined,
                                              color: Color(0xFF2EAA4D),
                                              size: 18,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (_hasRsbsaId &&
                                                (value == null || value.trim().isEmpty)) {
                                              return 'Please enter your RSBSA ID number';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      // Row 6: ID Photo Upload Bar with Inline Skip Option
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildFieldLabel(_hasRsbsaId ? 'FARMER ID PHOTO' : 'GOV ID PHOTO'),
                                          if (_hasRsbsaId)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Transform.scale(
                                                  scale: 0.8,
                                                  child: Checkbox(
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
                                                    activeColor: const Color(0xFF2EAA4D),
                                                    checkColor: Colors.white,
                                                    side: BorderSide(
                                                      color: Colors.white.withValues(alpha: 0.4),
                                                      width: 1.5,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  'Skip for now',
                                                  style: GoogleFonts.epilogue(
                                                    fontSize: 11,
                                                    color: Colors.white.withValues(alpha: 0.75),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: _skipFarmerId ? null : _uploadFarmerId,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _skipFarmerId
                                                ? Colors.black.withValues(alpha: 0.1)
                                                : Colors.black.withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.22),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.cloud_upload_outlined,
                                                color: _skipFarmerId
                                                    ? Colors.white30
                                                    : const Color(0xFF2EAA4D),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  _skipFarmerId
                                                      ? 'Skipped (Upload later in profile)'
                                                      : _farmerIdFileName,
                                                  style: GoogleFonts.epilogue(
                                                    color: _skipFarmerId
                                                        ? Colors.white38
                                                        : Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                color: _skipFarmerId ? Colors.white24 : Colors.white60,
                                                size: 13,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 18),

                                      // Row 7: Submit & Cancel Buttons
                                      Row(
                                        children: [
                                          // Cancel Button (flex 1)
                                          Expanded(
                                            flex: 2,
                                            child: SizedBox(
                                              height: 46,
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  if (Navigator.canPop(context)) {
                                                    Navigator.pop(context);
                                                  } else {
                                                    Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) => const LoginPage(),
                                                      ),
                                                    );
                                                  }
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: Colors.white.withValues(alpha: 0.3),
                                                    width: 1.0,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Cancel',
                                                  style: GoogleFonts.epilogue(
                                                    color: Colors.white.withValues(alpha: 0.85),
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Submit Button (flex 3)
                                          Expanded(
                                            flex: 3,
                                            child: SizedBox(
                                              height: 46,
                                              child: ElevatedButton(
                                                onPressed: _isSubmitting ? null : _submitForm,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF1B6A2D),
                                                  elevation: 4,
                                                  shadowColor: Colors.black.withValues(alpha: 0.35),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(24),
                                                  ),
                                                ),
                                                child: _isSubmitting
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2.0,
                                                        ),
                                                      )
                                                    : Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            'Submit',
                                                            style: GoogleFonts.epilogue(
                                                              color: Colors.white,
                                                              fontSize: 14.5,
                                                              fontWeight: FontWeight.w700,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 6),
                                                          const Icon(
                                                            Icons.arrow_forward_rounded,
                                                            color: Colors.white,
                                                            size: 17,
                                                          ),
                                                        ],
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}