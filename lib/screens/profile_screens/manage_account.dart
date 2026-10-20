import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:visaia/utils/location_constants.dart';
import 'package:visaia/utils/image_compression.dart';
import 'package:visaia/widgets/image_source_sheet.dart';

class ManageAccountScreen extends StatefulWidget {
  const ManageAccountScreen({super.key});

  @override
  State<ManageAccountScreen> createState() => _ManageAccountScreenState();
}

class _ManageAccountScreenState extends State<ManageAccountScreen> {
  // Theme Colors
  static const Color bgColor = Color(0xFFF8F9F8);
  static const Color darkGreen = Color(0xFF1B3015);
  static const Color textGray = Color(0xFF43483E);
  static const Color inputBg = Color(0xFFF1F3F1);

  // User data
  String _fullName = '';
  String _email = '';
  String _rsbsaId = '';
  String _barangay = '';
  String? _selectedBarangay;
  String _profileImageBase64 = '';
  bool _isLoading = true;
  bool _isSaving = false;

  // Identity documents (front / back of the ID)
  String _idFrontBase64 = '';
  String _idBackBase64 = '';
  String _idFrontFileName = '';
  String _idBackFileName = '';
  bool _isUploadingImage = false;
  IdSide? _uploadingSide;
  
  // Password fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  // Editable field controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _rsbsaIdController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isEditing = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _rsbsaIdController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = await _firestore
          .collection('farmers')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final loadedBarangay = (data['barangay'] as String?)?.trim() ?? '';
        setState(() {
          _fullName = data['fullName'] ?? '';
          _email = data['email'] ?? user.email ?? '';
          _rsbsaId = data['rsbsaId'] ?? '';
          _profileImageBase64 = data['profileImage']?.toString() ?? '';
          _idFrontBase64 = data['farmerIdImage'] ?? '';
          _idBackBase64 = data['farmerIdImageBack'] ?? '';
          _idFrontFileName = data['farmerIdFileName'] ?? '';
          _idBackFileName = data['farmerIdBackFileName'] ?? '';
          _barangay = loadedBarangay;
          _selectedBarangay = loadedBarangay.isNotEmpty && LocationConstants.cabatuanBarangays.contains(loadedBarangay)
              ? loadedBarangay
              : null;
          
          _fullNameController.text = _fullName;
          _emailController.text = _email;
          _rsbsaIdController.text = _rsbsaId;
          
          _isLoading = false;
        });
      } else {
        setState(() {
          _fullName = user.displayName ?? '';
          _email = user.email ?? '';
          _fullNameController.text = _fullName;
          _emailController.text = _email;
          _isLoading = false;
        });
      }

      // If barangay was not found in farmers collection, check users collection as fallback
      if (_barangay.isEmpty) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final uData = userDoc.data();
          final loadedBarangay = (uData?['barangay'] as String?)?.trim() ?? '';
          if (loadedBarangay.isNotEmpty && mounted) {
            setState(() {
              _barangay = loadedBarangay;
              _selectedBarangay = LocationConstants.cabatuanBarangays.contains(loadedBarangay)
                  ? loadedBarangay
                  : null;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: $e')),
        );
      }
    }
  }

  /* ================= ID HANDLING ================= */

  /// Picks, compresses and persists one side (front / back) of the ID.
  Future<void> _pickAndSaveIdSide(IdSide side) async {
    if (_isUploadingImage) return;

    try {
      final source = await pickImageSource(context);
      if (source == null) return;

      setState(() {
        _isUploadingImage = true;
        _uploadingSide = side;
      });

      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (picked == null) {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
            _uploadingSide = null;
          });
        }
        return;
      }

      final compressed = await compressImageToBase64(
        picked.path,
        fileName: picked.name,
      );

      if (compressed == null) {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
            _uploadingSide = null;
          });
          _showSnack('Could not read the selected image.', Colors.red);
        }
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isUploadingImage = false;
            _uploadingSide = null;
          });
        }
        return;
      }

      final payload = side == IdSide.front
          ? {
              'farmerIdImage': compressed.base64,
              'farmerIdFileName': compressed.fileName,
            }
          : {
              'farmerIdImageBack': compressed.base64,
              'farmerIdBackFileName': compressed.fileName,
            };

      await _firestore
          .collection('farmers')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        if (side == IdSide.front) {
          _idFrontBase64 = compressed.base64;
          _idFrontFileName = compressed.fileName;
        } else {
          _idBackBase64 = compressed.base64;
          _idBackFileName = compressed.fileName;
        }
        _isUploadingImage = false;
        _uploadingSide = null;
      });
      _showSnack('${side.label} of your ID uploaded', Colors.green);
    } catch (e) {
      debugPrint('Error uploading ID side: $e');
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadingSide = null;
        });
        _showSnack('Error uploading ID: $e', Colors.red);
      }
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  /// True when at least one side of the ID is still missing.
  bool get _hasMissingIdSide =>
      _idFrontBase64.isEmpty || _idBackBase64.isEmpty;

  /// Human readable description of what still needs to be uploaded.
  String get _missingIdSideLabel {
    if (_idFrontBase64.isEmpty && _idBackBase64.isEmpty) {
      return 'both sides of your ID';
    }
    if (_idFrontBase64.isEmpty) return 'the front of your ID';
    if (_idBackBase64.isEmpty) return 'the back of your ID';
    return '';
  }

  Future<void> _saveUserData() async {
    try {
      setState(() => _isSaving = true);
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final chosenBarangay = _selectedBarangay ?? _barangay;

      await _firestore
          .collection('farmers')
          .doc(user.uid)
          .set({
            'fullName': _fullNameController.text,
            'email': _emailController.text,
            'rsbsaId': _rsbsaIdController.text,
            'municipality': LocationConstants.defaultMunicipality,
            'barangay': chosenBarangay,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
            'fullName': _fullNameController.text,
            'name': _fullNameController.text,
            'email': _emailController.text,
            'municipality': LocationConstants.defaultMunicipality,
            'barangay': chosenBarangay,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (_fullNameController.text != _fullName) {
        await user.updateDisplayName(_fullNameController.text);
        await user.reload();
      }

      setState(() {
        _fullName = _fullNameController.text;
        _email = _emailController.text;
        _rsbsaId = _rsbsaIdController.text;
        _barangay = chosenBarangay;
        _isEditing = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('Error saving user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving data: $e')),
        );
      }
    }
  }

  Future<void> _updatePassword() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Validate current password is entered
      if (_currentPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your current password'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Validate new passwords
      if (_newPasswordController.text.isEmpty || 
          _confirmPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all password fields'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New passwords do not match'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_newPasswordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password must be at least 6 characters'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if new password is same as current
      if (_currentPasswordController.text == _newPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New password must be different from current password'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() => _isSaving = true);

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(_newPasswordController.text);

      // Clear password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      setState(() => _isSaving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isSaving = false);
      
      String errorMessage = 'Failed to update password';
      if (e.code == 'wrong-password') {
        errorMessage = 'Current password is incorrect';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Too many failed attempts. Please try again later';
      } else if (e.code == 'user-not-found') {
        errorMessage = 'User not found';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Account has been disabled';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Please log out and log in again before changing your password';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      debugPrint('Error updating password: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating password: $e')),
        );
      }
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _fullNameController.text = _fullName;
        _emailController.text = _email;
        _rsbsaIdController.text = _rsbsaId;
        _selectedBarangay = _barangay.isNotEmpty && LocationConstants.cabatuanBarangays.contains(_barangay)
            ? _barangay
            : null;
      }
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  String _getInitials() {
    if (_fullName.isEmpty) return '?';
    final parts = _fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return parts[0][0].toUpperCase();
  }

  /// Decoded profile photo, or `null` when the farmer has no (valid) photo.
  Uint8List? get _profileImageBytes =>
      decodeBase64Safely(_profileImageBase64.isEmpty ? null : _profileImageBase64);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(color: darkGreen),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Settings',
          style: GoogleFonts.epilogue(
            color: darkGreen,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2D4421),
              backgroundImage: _profileImageBytes != null
                  ? MemoryImage(_profileImageBytes!)
                  : null,
              child: _profileImageBytes == null
                  ? Text(
                      _getInitials(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Information Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Personal Information',
                        style: GoogleFonts.epilogue(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: darkGreen,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isEditing ? _saveUserData : _toggleEditing,
                        icon: Icon(
                          _isEditing ? Icons.save : Icons.edit,
                          size: 18,
                          color: const Color(0xFF173408),
                        ),
                        label: Text(
                          _isEditing ? 'Save' : 'Edit',
                          style: GoogleFonts.manrope(
                            color: const Color(0xFF173408),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  _isEditing
                      ? _buildEditableTextField('FULL NAME', _fullNameController)
                      : _buildDisplayField('FULL NAME', _fullName, const Color(0xFF173408), FontWeight.w900, 24),
                  
                  const SizedBox(height: 20),
                  
                  _isEditing
                      ? _buildEditableTextField('EMAIL ADDRESS', _emailController, keyboardType: TextInputType.emailAddress)
                      : _buildDisplayField('EMAIL ADDRESS', _email, const Color(0xFF181C1A), FontWeight.w600, 16),
                  
                  const SizedBox(height: 20),
                  
                  _isEditing
                      ? _buildEditableTextField('RSBSA ID NUMBER', _rsbsaIdController)
                      : _buildIdNumberRow('RSBSA ID NUMBER', _rsbsaId),

                  const SizedBox(height: 20),

                  _isEditing
                      ? _buildBarangayDropdown()
                      : _buildDisplayField(
                          'BARANGAY (CABATUAN)',
                          _barangay.isEmpty ? 'Not set (Tap Edit to choose)' : '$_barangay, Cabatuan',
                          const Color(0xFF181C1A),
                          FontWeight.w600,
                          16,
                        ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Profile Photo Card
            Text(
              'Profile Photo',
              style: GoogleFonts.epilogue(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFF2D4421),
                    backgroundImage: _profileImageBytes != null
                        ? MemoryImage(_profileImageBytes!)
                        : null,
                    child: _profileImageBytes == null
                        ? Text(
                            _getInitials(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 26,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profileImageBytes == null
                              ? 'No profile photo yet'
                              : 'Profile photo updated',
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _profileImageBytes == null
                                ? Colors.grey
                                : darkGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This photo is shown to the LGU-MAO on your farmer profile.',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: textGray.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'To change your photo, go back to your Profile tab and tap the camera button on your picture.',
                          style: GoogleFonts.manrope(
                            fontSize: 12.5,
                            color: textGray.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            // Identity Documents Card
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Identity Documents',
                  style: GoogleFonts.epilogue(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: darkGreen,
                  ),
                ),
                if (_hasMissingIdSide)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Action required',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Prompt for the missing side(s)
            if (_hasMissingIdSide)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFDE3A7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_rounded,
                            color: Color(0xFFB45309), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Please upload $_missingIdSideLabel. '
                            'The municipal office needs both sides to '
                            'complete your verification.',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              height: 1.45,
                              color: const Color(0xFF78350F),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_idFrontBase64.isEmpty)
                      _buildUploadAction(
                        label: 'Upload the front of your ID',
                        side: IdSide.front,
                      ),
                    if (_idFrontBase64.isEmpty && _idBackBase64.isEmpty)
                      const SizedBox(height: 10),
                    if (_idBackBase64.isEmpty)
                      _buildUploadAction(
                        label: 'Upload the back of your ID',
                        side: IdSide.back,
                      ),
                  ],
                ),
              ),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your ID images are compressed and stored securely for '
                    'verification purposes only.',
                    style: GoogleFonts.manrope(
                      fontSize: 12.5,
                      color: textGray.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildIdPreview(
                          side: IdSide.front,
                          base64: _idFrontBase64,
                          fileName: _idFrontFileName,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildIdPreview(
                          side: IdSide.back,
                          base64: _idBackBase64,
                          fileName: _idBackFileName,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),
            Text(
              'Security & Password',
              style: GoogleFonts.epilogue(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: darkGreen,
              ),
            ),
            const SizedBox(height: 16),

            // Password Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('CURRENT PASSWORD'),
                  _buildPasswordField(
                    _currentPasswordController,
                    'Enter current password',
                    showVisibilityToggle: true,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInputLabel('NEW PASSWORD'),
                  _buildPasswordField(
                    _newPasswordController,
                    'Enter new password',
                    showVisibilityToggle: true,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInputLabel('CONFIRM NEW PASSWORD'),
                  _buildPasswordField(
                    _confirmPasswordController,
                    'Re-type new password',
                    showVisibilityToggle: true,
                  ),
                  const SizedBox(height: 8),
                  
                  // Password requirements hint
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '• Password must be at least 6 characters long',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: textGray.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14290B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Update Password',
                              style: GoogleFonts.manrope(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Helper widgets
  Widget _buildUploadAction({
    required String label,
    required IdSide side,
  }) {
    final busy = _isUploadingImage && _uploadingSide == side;
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton.icon(
        onPressed: _isUploadingImage ? null : () => _pickAndSaveIdSide(side),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.cloud_upload_outlined, size: 18),
        label: Text(
          busy ? 'Uploading…' : label,
          style: GoogleFonts.manrope(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF14290B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
      ),
    );
  }

  /// Front / back container for one side of the identity document.
  Widget _buildIdPreview({
    required IdSide side,
    required String base64,
    required String fileName,
  }) {
    final hasImage = base64.isNotEmpty;
    final busy = _isUploadingImage && _uploadingSide == side;

    return GestureDetector(
      onTap: _isUploadingImage ? null : () => _pickAndSaveIdSide(side),
      child: Container(
        decoration: BoxDecoration(
          color: inputBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasImage
                ? const Color(0xFF4A633F).withValues(alpha: 0.45)
                : Colors.grey.withValues(alpha: 0.35),
            width: 1.2,
            style: hasImage ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.6,
              child: hasImage
                  ? Image.memory(
                      base64Decode(base64),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildIdPlaceholder(side),
                    )
                  : _buildIdPlaceholder(side),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${side.label.toUpperCase()} OF ID',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: textGray.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    busy
                        ? 'Uploading…'
                        : (hasImage
                            ? (fileName.isEmpty ? 'Uploaded' : fileName)
                            : 'Not uploaded'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: hasImage ? darkGreen : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasImage
                            ? Icons.check_circle_rounded
                            : Icons.add_a_photo_outlined,
                        size: 15,
                        color: hasImage
                            ? const Color(0xFF4A633F)
                            : const Color(0xFF173408),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasImage ? 'Replace' : 'Upload',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF173408),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdPlaceholder(IdSide side) {
    return Container(
      color: inputBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 26,
            color: Colors.grey.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 6),
          Text(
            '${side.label} not uploaded',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarangayDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('BARANGAY (CABATUAN)'),
        DropdownButtonFormField<String>(
          initialValue: _selectedBarangay,
          isExpanded: true,
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: darkGreen,
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: darkGreen),
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: darkGreen, width: 2),
            ),
          ),
          hint: Text(
            'Select your barangay',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          items: LocationConstants.cabatuanBarangays.map((String brgy) {
            return DropdownMenuItem<String>(
              value: brgy,
              child: Text(
                brgy,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: darkGreen,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? val) {
            setState(() {
              _selectedBarangay = val;
            });
          },
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0, left: 4),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: textGray.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildDisplayField(String label, String value, Color textColor, FontWeight fontWeight, double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        Text(
          value.isEmpty ? 'Not set' : value,
          style: GoogleFonts.manrope(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: value.isEmpty ? Colors.grey : textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildEditableTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: darkGreen, width: 2),
            ),
          ),
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: darkGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildIdNumberRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_outlined, color: Color(0xFF4A633F), size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: textGray.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.isEmpty ? 'Not set' : value,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: value.isEmpty ? Colors.grey : const Color(0xFF181C1A),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller, 
    String hint, {
    bool showVisibilityToggle = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.manrope(
            color: Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: showVisibilityToggle
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                    size: 22,
                  ),
                  onPressed: _togglePasswordVisibility,
                )
              : const Icon(Icons.lock_outline, color: Colors.grey, size: 22),
        ),
        style: GoogleFonts.manrope(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: darkGreen,
        ),
      ),
    );
  }
}