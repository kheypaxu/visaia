import 'package:flutter/material.dart';

class MitigationScreen extends StatelessWidget {
  const MitigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F4),
        body: Column(
          children: [
            // Top Recommendation Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4F0),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: Color(0xFF0D4D33), width: 4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco_outlined, color: Color(0xFF0D4D33)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "VISAIA recommends starting with prevention and biological control before using chemical treatments.",
                        style: TextStyle(color: Colors.grey[800], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Custom Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                indicatorSize: TabBarIndicatorSize.label,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  _buildTab("Physical & Cultural"),
                  _buildTab("Biological"),
                  _buildTab("Chemical"),
                ],
              ),
            ),

            // Tab Content
            const Expanded(
              child: TabBarView(
                children: [
                  PhysicalCulturalTab(),
                  BiologicalTab(),
                  ChemicalTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: null, // Handled by TabBar labelColor/indicator logic via selection
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

// Helper to style the active tab background since TabBar lacks a simple "pill" background for active
// We override the theme specifically for this bar in a real app, or use a custom Container.
// For this demo, let's use a standard decoration:

// --- TAB 1: PHYSICAL & CULTURAL ---
class PhysicalCulturalTab extends StatelessWidget {
  const PhysicalCulturalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: "PAMS", subtitle: "Recommended first to prevent infestation"),
        const ActionCard(
          icon: Icons.local_shipping_outlined,
          title: "Plant Quarantine",
          tag: "PREVENTIVE",
          tagColor: Color(0xFFA6E38E),
          description: "Prevent movement of infested plants or materials between farms.",
          footer: "Recommended First",
        ),
        const ActionCard(
          icon: Icons.sync_outlined,
          title: "Crop Diversification",
          tag: "PREVENTIVE",
          tagColor: Color(0xFFA6E38E),
          description: "Use crop rotation or intercropping to reduce pest buildup.",
          footer: "Recommended First",
        ),
        const SectionHeader(title: "Direct Field Action", subtitle: "Use when pests are already visible"),
        const ActionCard(
          icon: Icons.front_hand_outlined,
          title: "Handpicking",
          tag: "IMMEDIATE ACTION",
          tagColor: Color(0xFFE6D5B8),
          description: "Manually remove visible larvae from plants.",
        ),
        const SizedBox(height: 20),
        const SuggestedActionFooter(),
      ],
    );
  }
}

// --- TAB 2: BIOLOGICAL ---
class BiologicalTab extends StatelessWidget {
  const BiologicalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ActionCard(
          icon: Icons.bug_report_outlined,
          title: "Pheromone Traps",
          tag: "ECO-FRIENDLY",
          tagColor: Color(0xFFA6E38E),
          description: "Use traps to monitor adult moth activity and reduce pest spread.",
        ),
        ActionCard(
          icon: Icons.pest_control_outlined,
          title: "Parasitoids",
          tag: "ECO-FRIENDLY",
          tagColor: Color(0xFFA6E38E),
          description: "Targets FAW eggs before they hatch.",
          italicDetails: "Trichogramma sp.\nTelenomus remus\nChelonus insularis",
        ),
      ],
    );
  }
}

// --- TAB 3: CHEMICAL ---
class ChemicalTab extends StatelessWidget {
  const ChemicalTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFB37400)),
              SizedBox(width: 12),
              Expanded(
                child: Text("Use only when infestation exceeds economic threshold."),
              )
            ],
          ),
        ),
        const SectionHeader(title: "Botanical Pesticides"),
        const ActionCard(
          icon: Icons.opacity_outlined,
          title: "Plant-based Insecticides",
          description: "Naturally derived active ingredients. Lower persistence in the environment.",
          italicDetails: "Neem oil, Garlic extract, Chili pepper extract",
        ),
      ],
    );
  }
}

// --- SHARED UI COMPONENTS ---

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? tag;
  final Color? tagColor;
  final String description;
  final String? footer;
  final String? italicDetails;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    this.tag,
    this.tagColor,
    required this.description,
    this.footer,
    this.italicDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFF0F4F0),
                  child: Icon(icon, color: const Color(0xFF0D4D33)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(tag!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (italicDetails != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(italicDetails!, style: const TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF0D4D33))),
              ),
            Text(description, style: TextStyle(color: Colors.grey[700], height: 1.4)),
            if (footer != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Color(0xFF0D4D33)),
                  const SizedBox(width: 6),
                  Text(footer!, style: const TextStyle(color: Color(0xFF0D4D33), fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}

class SuggestedActionFooter extends StatelessWidget {
  const SuggestedActionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D4D33),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("VISAIA SUGGESTED ACTION", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "Begin with PAMS methods, then apply biological control before considering chemicals.",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}