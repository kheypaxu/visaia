import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFF9FBF7)),
      home: const HomeScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// YOUR EXISTING SCREENS GO HERE (Example below)
// ─────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Agritech App')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF162B0D),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
          onPressed: () => showAssignLogSheet(context), // <--- TRIGGER IT HERE
          child: Text(
            'Open Assign Log',
            style: GoogleFonts.manrope(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE SNACKBAR / BOTTOM SHEET COMPONENT
// ─────────────────────────────────────────────────────────────

/// Call this function from any button's onTap:
/// `showAssignLogSheet(context);`
void showAssignLogSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Allows taking up full height
    backgroundColor: Colors.transparent, // Removes default dark background
    builder: (context) => const AssignLogSheetContent(),
  );
}

class AssignLogSheetContent extends StatefulWidget {
  const AssignLogSheetContent({super.key});

  @override
  State<AssignLogSheetContent> createState() => _AssignLogSheetContentState();
}

class _AssignLogSheetContentState extends State<AssignLogSheetContent> {
  String? selectedField;
  String? selectedCycle;

  final List<String> fields = ['North Wheat Block', 'South Corn Plot', 'East Rice Paddy', 'West Soybean Field'];
  final List<String> cycles = ['Rabi 2024–2025', 'Kharif 2024', 'Zaid 2024'];

  @override
  Widget build(BuildContext context) {
    // Takes up 95% of the screen height to eliminate whitespace
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      height: screenHeight * 0.95,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBF7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Padding(
            padding: EdgeInsets.only(top: topPadding > 0 ? 12 : 20, bottom: 8),
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF162B0D).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Scrollable Content Area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ── Header ──
                  Text(
                    'Assign Log',
                    style: GoogleFonts.epilogue(
                      fontSize: 32, // Enlarged
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF162B0D),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select where this record belongs',
                    style: GoogleFonts.manrope(
                      fontSize: 15, // Enlarged
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF8E9A88),
                    ),
                  ),
                  const SizedBox(height: 40), // Extra space

                  // ── Report Card ──
                  _buildReportCard(),
                  const SizedBox(height: 44), // Extra space

                  // ── Field Selection Dropdown ──
                  _buildDropdownLabel('FIELD SELECTION'),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    value: selectedField,
                    hint: 'Choose specific field',
                    items: fields,
                    onChanged: (val) => setState(() => selectedField = val),
                  ),
                  const SizedBox(height: 32), // Extra space

                  // ── Active Cropping Cycle Dropdown ──
                  _buildDropdownLabel('ACTIVE CROPPING CYCLE'),
                  const SizedBox(height: 12),
                  _buildDropdown(
                    value: selectedCycle,
                    hint: 'Select active cycle',
                    items: cycles,
                    onChanged: (val) => setState(() => selectedCycle = val),
                  ),
                  const SizedBox(height: 100), // Space for button
                ],
              ),
            ),
          ),

          // ── Pinned Save Button at very bottom ──
          Container(
            width: double.infinity,
            color: const Color(0xFFF9FBF7),
            padding: EdgeInsets.fromLTRB(28, 16, 28, 24 + MediaQuery.of(context).padding.bottom),
            child: _buildSaveButton(),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Report Card ──────────────────────────
  Widget _buildReportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24), // Enlarged padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8DE), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF162B0D).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52, // Enlarged icon
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFC6F097),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.description_outlined, size: 26, color: Color(0xFF162B0D)),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F097),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'NEW DRAFT',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF162B0D),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Soil Analysis Report #024',
                  style: GoogleFonts.manrope(
                    fontSize: 17, // Enlarged
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF162B0D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Recorded: Today, 08:45 AM',
                  style: GoogleFonts.manrope(
                    fontSize: 14, // Enlarged
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8E9A88),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────── Dropdown Label ──────────────────────────
  Widget _buildDropdownLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF162B0D),
        letterSpacing: 1.2,
      ),
    );
  }

  // ────────────────────────── Styled Dropdown ──────────────────────────
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F0),
        borderRadius: BorderRadius.circular(14), // Enlarged radius
        border: Border.all(
          color: value != null
              ? const Color(0xFF162B0D).withOpacity(0.3)
              : const Color(0xFFE2E8DE),
          width: 1.5,
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint, style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF8E9A88))),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF162B0D), size: 24),
        isExpanded: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16), // Enlarged padding
        ),
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(14),
        style: GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF162B0D)),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ────────────────────────── Save Button ──────────────────────────
  Widget _buildSaveButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Dismiss the sheet and show a small success indicator
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Log saved successfully!', style: GoogleFonts.manrope(fontWeight: FontWeight.w500)),
              backgroundColor: const Color(0xFF162B0D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
        borderRadius: BorderRadius.circular(50),
        child: Container(
          width: double.infinity,
          height: 64, // Enlarged button
          decoration: BoxDecoration(
            color: const Color(0xFF162B0D),
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF162B0D).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.save_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                'Save Log',
                style: GoogleFonts.manrope(
                  fontSize: 17, // Enlarged
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}