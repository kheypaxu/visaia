import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MitigationProtocolScreen extends StatefulWidget {
  const MitigationProtocolScreen({super.key});

  @override
  State<MitigationProtocolScreen> createState() => _MitigationProtocolScreenState();
}

class _MitigationProtocolScreenState extends State<MitigationProtocolScreen> {
  int _activeTab = 0; // 0 for Biological Agents, 1 for Pheromone Traps

  // Matching ResultPage Palette
  static const Color bgDark = Color(0xFF102216);
  static const Color cardBg = Color(0xFF232C26);
  static const Color primaryBtn = Color(0xFF8DBA60); // Your ResultPage green
  static const Color successGreen = Color(0xFF76CA22);
  static const Color greyText = Color(0xFF878787);
  static const Color white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            _buildTabToggle(),
            const SizedBox(height: 24),
            _activeTab == 0 ? _buildBiologicalTab() : _buildPheromoneTab(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _toggleButton("Biological", 0),
          _toggleButton("Pheromones", 1),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, int index) {
    bool isSelected = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryBtn : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? bgDark : greyText,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiologicalTab() {
    return Column(
      children: [
        _buildHeroSolutionCard("Spinetoram", "Target: Late-stage larvae & egg masses"),
        const SizedBox(height: 20),
        _buildSectionHeader("DOSAGE & PREPARATION"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildStatBox("10ml", "PER 16L WATER", true),
              const SizedBox(width: 12),
              _buildStatBox("2.5L", "TOTAL/HECTARE", false),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("APPLICATION STEPS"),
        _buildStepItem(1, "Focus on the Whorl", "Direct spray downward into the central corn whorl for deep penetration."),
        _buildStepItem(2, "Optimal Timing", "Best applied 6:00-9:00 AM or 4:00-6:00 PM for maximum stability."),
        const SizedBox(height: 20),
        _buildActionButton("Confirm Application"),
      ],
    );
  }

  Widget _buildPheromoneTab() {
    return Column(
      children: [
        _buildHeroSolutionCard("4 - 5 Traps", "Recommended density per Hectare"),
        const SizedBox(height: 20),
        _buildSectionHeader("TRAP SPECIFICATIONS"),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _buildStatBox("1.5m", "POLE HEIGHT", true),
              const SizedBox(width: 12),
              _buildStatBox("30 Days", "LURE LIFESPAN", false),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("DEPLOYMENT STEPS"),
        _buildStepItem(1, "Zigzag Distribution", "Install in a zigzag pattern across the field, at least 20m apart."),
        _buildStepItem(2, "Windward Side", "Place traps on the windward side to maximize pheromone plume coverage."),
        const SizedBox(height: 20),
        _buildActionButton("Confirm Installation"),
      ],
    );
  }

  Widget _buildHeroSolutionCard(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("RECOMMENDED", style: TextStyle(color: greyText, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                Text(title, style: GoogleFonts.inter(color: white, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: successGreen, fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: bgDark, shape: BoxShape.circle),
            child: const Icon(Icons.biotech_outlined, color: primaryBtn, size: 28),
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Text(
        title,
        style: GoogleFonts.inter(color: greyText, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildStatBox(String val, String label, bool isPrimary) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isPrimary ? primaryBtn.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Column(
          children: [
            Text(val, style: GoogleFonts.inter(color: isPrimary ? primaryBtn : white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: greyText, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(int number, String title, String desc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("#$number", style: GoogleFonts.inter(color: primaryBtn, fontWeight: FontWeight.w900)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: greyText, fontSize: 13, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBtn,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {},
          child: Text(
            label,
            style: GoogleFonts.inter(color: bgDark, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }
}