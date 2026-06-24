import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

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
  String _profileImageBase64 = '';
  bool _isLoading = true;
  bool _isSaving = false;
  
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
        setState(() {
          _fullName = data['fullName'] ?? '';
          _email = data['email'] ?? user.email ?? '';
          _rsbsaId = data['rsbsaId'] ?? '';
          _profileImageBase64 = data['profileImage'] ?? '';
          
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

  Future<void> _saveUserData() async {
    try {
      setState(() => _isSaving = true);
      
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('farmers')
          .doc(user.uid)
          .set({
            'fullName': _fullNameController.text,
            'email': _emailController.text,
            'rsbsaId': _rsbsaIdController.text,
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
              backgroundImage: _profileImageBase64.isNotEmpty
                  ? MemoryImage(base64Decode(_profileImageBase64))
                  : null,
              child: _profileImageBase64.isEmpty
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