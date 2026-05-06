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

  // Brand Colors
  static const _green = Color(0xFF1A5C30);
  static const _darkGreen = Color(0xFF0C3D28);
  static const _lightGreen = Color(0xFFEAF3DE);
  static const _accentGreen = Color(0xFF4E9F3D);
  static const _bgColor = Color(0xFFF2F6F3);
  static const _mutedText = Color(0xFF8FA99A);
  static const _borderColor = Color(0xFFDDE9E2);
  static const _cardWhite = Color(0xFFFFFFFF);

  Future<void> _pickFromCamera() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (image != null) _onImageSelected(image);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (image != null) _onImageSelected(image);
  }

  void _onImageSelected(XFile image) {
    setState(() => _image = image);
    _processImage(File(image.path));
  }

  void _retakePhoto() => setState(() => _image = null);

  Future<void> _processImage(File imageFile) async {
    // Validate userId before proceeding
    if (widget.userId == null || widget.userId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User ID not available')),
      );
      return;
    }

    // Push the cinematic analyzing screen on top
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
              const SizedBox(height: 16),
              _buildActionButtons(),
              const SizedBox(height: 24),
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
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _darkGreen, size: 16),
        ),
      ),
      title: Text(
        'Pest Identifier',
        style: GoogleFonts.spaceGrotesk(
          color: _darkGreen,
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: false,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _lightGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.eco_rounded, color: _accentGreen, size: 13),
              const SizedBox(width: 5),
              Text('AI-Powered',
                  style: GoogleFonts.dmSans(
                      color: _green, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildHeaderText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identify crop pests\ninstantly.',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _darkGreen,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Upload or capture a photo of the affected plant or pest for an AI-powered analysis.',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: _mutedText,
            height: 1.55,
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
        border: Border.all(
          color: _image != null ? _accentGreen.withOpacity(0.4) : _borderColor,
          width: _image != null ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
        // Gradient overlay at bottom
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
                colors: [Colors.black.withOpacity(0.55), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 14,
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                'Photo ready',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: GestureDetector(
            onTap: _retakePhoto,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3), width: 0.8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text('Retake',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      )),
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _lightGreen,
            shape: BoxShape.circle,
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: const Icon(Icons.add_photo_alternate_outlined,
              color: _accentGreen, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          'No photo selected',
          style: GoogleFonts.spaceGrotesk(
            color: _darkGreen,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose an option below to get started',
          style: GoogleFonts.dmSans(color: _mutedText, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _bigActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            sublabel: 'Take a new photo',
            onTap: _pickFromCamera,
            isPrimary: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _bigActionButton(
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

  Widget _bigActionButton({
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isPrimary ? _green : _cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? _green : _borderColor,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: _green.withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  )
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isPrimary
                    ? Colors.white.withOpacity(0.15)
                    : _lightGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: isPrimary ? Colors.white : _accentGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: isPrimary ? Colors.white : _darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  sublabel,
                  style: GoogleFonts.dmSans(
                    color: isPrimary
                        ? Colors.white.withOpacity(0.7)
                        : _mutedText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = [
      (Icons.straighten_rounded, 'Get within 15–20 cm of the affected area or pest'),
      (Icons.wb_sunny_outlined, 'Use natural light — avoid harsh shadows or flash glare'),
      (Icons.pest_control_rounded, 'Focus on visible damage, egg masses, larvae, or the pest itself'),
      (Icons.motion_photos_off_outlined, 'Hold steady — blur reduces identification accuracy'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_rounded,
                  color: _accentGreen, size: 15),
              const SizedBox(width: 7),
              Text(
                'PHOTO TIPS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _mutedText,
                  letterSpacing: 1.0,
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
                      child: Icon(e.value.$1, color: _accentGreen, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          e.value.$2,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: const Color(0xFF52705E),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Divider(
                        height: 1, color: _borderColor.withOpacity(0.8)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}