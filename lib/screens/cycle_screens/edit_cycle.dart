import 'package:flutter/material.dart';
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
  // State variables to control overlays without navigating away from Screen 1
  bool _showSaveModal = false;
  bool _showArchiveModal = false;

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
        ],
      ),
    );
  }

  // SCREEN 1 implementation
  Widget _buildScreen1() {
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
                  _buildInputField("CYCLE NAME", "Soybean Summer"),
                  const SizedBox(height: 16),
                  _buildDropdownField("FARM / FIELD SELECTION", "East Basin - Sector 2"),
                  const SizedBox(height: 16),
                  _buildFieldPreview(),
                  const SizedBox(height: 32),
                  _sectionHeader("PHASE 02", "Botanical Details"),
                  const SizedBox(height: 16),
                  _buildIconInputField("CROP VARIETY", "Soybean Delta", Icons.spa_outlined),
                  const SizedBox(height: 16),
                  _buildIconInputField("PLANTING DATE", "06/10/2024", Icons.calendar_today_outlined),
                  const SizedBox(height: 16),
                  _buildIconInputField("EST. HARVEST", "10/12/2024", Icons.event_note_outlined),
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

  // MODIFIED: Title is now placed specifically in the top left
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: kPrimaryGreen),
            onPressed: () {},
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
          const Spacer(), // Pushes the Save button to the far right
          TextButton(
            onPressed: () => setState(() => _showSaveModal = true),
            child: const Text(
              "Save",
              style: TextStyle(
                color: kPrimaryGreen,
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
        Text(phase, style: const TextStyle(color: Color(0xFF27AE60), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(color: kPrimaryGreen, fontSize: 24, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildInputField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withValues(alpha:0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: kPrimaryGreen, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withValues(alpha:0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: const TextStyle(color: kTextDark, fontSize: 16, fontWeight: FontWeight.w600)),
              const Icon(Icons.keyboard_arrow_down, color: kTextGrey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconInputField(String label, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorderColor.withValues(alpha:0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kTextGrey, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, color: kPrimaryGreen, size: 20),
              const SizedBox(width: 12),
              Text(value, style: const TextStyle(color: kTextDark, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1500382017468-9049fed747ef?q=80&w=1000'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("FIELD PREVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryGreen)),
                  Icon(Icons.fullscreen, size: 16, color: kPrimaryGreen),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildArchiveButton() {
    return GestureDetector(
      onTap: () => setState(() => _showArchiveModal = true),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE5E5),
          borderRadius: BorderRadius.circular(32),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: kArchiveRed, size: 22),
            SizedBox(width: 10),
            Text(
              "Archive This Crop Cycle",
              style: TextStyle(color: kArchiveRed, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // HELPER: Modal Wrapper with Blur
  Widget _buildOverlayWrapper({required Widget child, required VoidCallback onDismiss}) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            color: Colors.black.withValues(alpha:0.1),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFC8F7DC), shape: BoxShape.circle),
            child: const Icon(Icons.assignment_turned_in_outlined, color: kPrimaryGreen, size: 32),
          ),
          const SizedBox(height: 24),
          const Text("Save Changes?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kTextDark)),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(color: kTextGrey, fontSize: 14, height: 1.5, fontFamily: 'Inter'),
              children: [
                TextSpan(text: "Are you sure you want to save the updates to "),
                TextSpan(text: "Soybean Summer", style: TextStyle(fontWeight: FontWeight.w800, color: kPrimaryGreen)),
                TextSpan(text: "? Previous parameters will be updated."),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _modalButton("Save Changes", kPrimaryGreen, Colors.white, () {}),
          const SizedBox(height: 12),
          _modalButton("Cancel", Colors.transparent, kTextGrey, () => setState(() => _showSaveModal = false), hasBorder: true),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFFFEBD2), shape: BoxShape.circle),
            child: const Icon(Icons.archive_outlined, color: Color(0xFF7E5700), size: 32),
          ),
          const SizedBox(height: 24),
          const Text("Archive This Crop Cycle?", textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kTextDark)),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              style: TextStyle(color: kTextGrey, fontSize: 14, height: 1.5, fontFamily: 'Inter'),
              children: [
                TextSpan(text: "This will move "),
                TextSpan(text: "'Soybean Summer'", style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
                TextSpan(text: " to your historical records. You will no longer be able to record active monitoring data for this field."),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _modalButton("Archive Cycle", const Color(0xFF5C3D00), Colors.white, () {}),
          const SizedBox(height: 12),
          _modalButton("Keep Active", const Color(0xFFE8ECEF), kTextDark, () => setState(() => _showArchiveModal = false)),
        ],
      ),
    );
  }

  Widget _modalButton(String text, Color bg, Color textColor, VoidCallback onTap, {bool hasBorder = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          border: hasBorder ? Border.all(color: kBorderColor) : null,
        ),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
    );
  }
}