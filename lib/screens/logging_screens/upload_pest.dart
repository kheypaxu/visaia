import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visaia/screens/logging_screens/analyzing.dart';

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

  static const _green = Color(0xFF1A5C30);
  static const _lightGreen = Color(0xFFEAF3DE);
  static const _accentGreen = Color(0xFF4E9F3D);
  static const _bgColor = Color(0xFFF7F8F5);
  static const _mutedText = Color(0xFF5E6266);
  static const _borderColor = Color(0xFFE8EAE5);
  static const _cardWhite = Color(0xFFFFFFFF);

  Future<void> _pickFromCamera() async {
    final XFile? image = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 88);
    if (image != null) _onImageSelected(image);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 88);
    if (image != null) _onImageSelected(image);
  }

  void _onImageSelected(XFile image) {
    setState(() => _image = image);
    _processImage(File(image.path));
  }

  void _retakePhoto() => setState(() => _image = null);

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor:
            isError ? const Color(0xFFBA1A1A) : const Color(0xFF1B5E37),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Future<void> _processImage(File imageFile) async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      _showSnackBar('Error: User ID not available', isError: true);
      return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => AnalyzingScreen(
          imageFile: imageFile,
          userId: widget.userId!,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildHeaderText(),
              const SizedBox(height: 20),
              _buildPhotoCard(),
              const SizedBox(height: 14),
              _buildActionButtons(),
              const SizedBox(height: 20),
              _buildTipsCard(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bgColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back,
                color: Color(0xFF2D3132), size: 18),
          ),
        ),
      ),
      centerTitle: true,
      title: const Text(
        'Pest Identifier',
        style: TextStyle(
          color: Color(0xFF1A1C1E),
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome,
                    color: _accentGreen, size: 13),
                const SizedBox(width: 5),
                Text(
                  'AI-Powered',
                  style: GoogleFonts.manrope(
                      color: _green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Identify crop pests\ninstantly.',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1C1E),
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload or capture a photo of the affected plant or pest for an AI-powered analysis.',
          style: GoogleFonts.manrope(
            fontSize: 14,
            color: _mutedText.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          if (_image != null)
            BoxShadow(
              color: _accentGreen.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _image != null ? _buildImagePreview() : _buildEmptyState(),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(_image!.path), fit: BoxFit.cover),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 0.8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(
                  'Photo ready',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _retakePhoto,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Retake',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _lightGreen.withValues(alpha: 0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: _accentGreen, size: 26),
        ),
        const SizedBox(height: 14),
        Text(
          'No photo selected',
          style: GoogleFonts.manrope(
            color: const Color(0xFF1A1C1E),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose an option below to get started',
          style: GoogleFonts.manrope(
              color: _mutedText.withValues(alpha: 0.6), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            sublabel: 'Take a new photo',
            onTap: _pickFromCamera,
            isPrimary: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionButton(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            sublabel: 'Choose existing',
            onTap: _pickFromGallery,
            isPrimary: false,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: isPrimary ? _green : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? _green.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isPrimary ? 12 : 4,
              offset: isPrimary
                  ? const Offset(0, 4)
                  : const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withValues(alpha: 0.12)
                    : _lightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isPrimary ? Colors.white : _accentGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.manrope(
                      color: isPrimary ? Colors.white : const Color(0xFF1A1C1E),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    sublabel,
                    style: GoogleFonts.manrope(
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.6)
                          : _mutedText.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = [
      (
        Icons.straighten_rounded,
        'Get within 15–20 cm of the affected area or pest'
      ),
      (
        Icons.wb_sunny_outlined,
        'Use natural light — avoid harsh shadows or flash glare'
      ),
      (
        Icons.pest_control_rounded,
        'Focus on visible damage, egg masses, larvae, or the pest itself'
      ),
      (
        Icons.motion_photos_off_outlined,
        'Hold steady — blur reduces identification accuracy'
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _lightGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tips_and_updates_rounded,
                    color: _accentGreen, size: 15),
              ),
              const SizedBox(width: 8),
              Text(
                'PHOTO TIPS',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _mutedText.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tips.asMap().entries.map((e) {
            final isLast = e.key == tips.length - 1;
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _lightGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          Icon(e.value.$1, color: _accentGreen, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          e.value.$2,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: const Color(0xFF52705E),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                        height: 1, color: _borderColor),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}