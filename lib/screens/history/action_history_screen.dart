import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum ActionType { treatment, fertilization, harvest, detection, maintenance }

class ActionItem {
  final String title;
  final String description;
  final DateTime timestamp;
  final ActionType type;
  final String status; // e.g., "Completed", "Match 96%", "Scheduled"

  ActionItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    required this.status,
  });
}

class ActionHistoryScreen extends StatefulWidget {
  const ActionHistoryScreen({super.key});

  @override
  State<ActionHistoryScreen> createState() => _ActionHistoryScreenState();
}

class _ActionHistoryScreenState extends State<ActionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Mock Data - In a real app, you'd pass this via the constructor or a Provider
  final List<ActionItem> _allActions = [
    ActionItem(
      title: "Pesticide Application",
      description: "Applied Neem Oil to Sector C Corn Field.",
      timestamp: DateTime.now(),
      type: ActionType.treatment,
      status: "COMPLETED",
    ),
    ActionItem(
      title: "Fall Armyworm Detected",
      description: "Visual analysis identified larvae in Sector A.",
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      type: ActionType.detection,
      status: "98% MATCH",
    ),
    ActionItem(
      title: "Soil Fertilization",
      description: "Organic compost spread across North Quadrant.",
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: ActionType.fertilization,
      status: "COMPLETED",
    ),
    ActionItem(
      title: "General Maintenance",
      description: "Irrigation system check and filter cleaning.",
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: ActionType.maintenance,
      status: "ROUTINE",
    ),
  ];

  List<ActionItem> _filteredActions = [];

  @override
  void initState() {
    super.initState();
    _filteredActions = _allActions;
  }

  void _filterList(String query) {
    setState(() {
      _filteredActions = _allActions
          .where((action) =>
              action.title.toLowerCase().contains(query.toLowerCase()) ||
              action.description.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by RootLayout
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _filteredActions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredActions.length,
                    itemBuilder: (context, index) {
                      return _buildActionCard(_filteredActions[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: TextField(
        controller: _searchController,
        onChanged: _filterList,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search logs or actions...",
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.03),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(ActionItem action) {
    Color typeColor;
    IconData typeIcon;

    switch (action.type) {
      case ActionType.treatment:
        typeColor = const Color(0xFFCEA265); // Gold
        typeIcon = Icons.medical_services_outlined;
        break;
      case ActionType.detection:
        typeColor = Colors.redAccent;
        typeIcon = Icons.bug_report_outlined;
        break;
      case ActionType.fertilization:
        typeColor = const Color(0xFF8DBA60); // Green
        typeIcon = Icons.grass_outlined;
        break;
      default:
        typeColor = Colors.blueAccent;
        typeIcon = Icons.settings_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Indicator & Icon
          Column(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(height: 8),
              // Vertical dash line for timeline feel
              Container(width: 2, height: 30, color: Colors.white10),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      action.status,
                      style: GoogleFonts.inter(
                        color: action.type == ActionType.detection ? Colors.redAccent : const Color(0xFF8DBA60),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(action.timestamp),
                      style: GoogleFonts.inter(color: Colors.white24, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  action.title,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  action.description,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                Text(
                  DateFormat('MMM dd, yyyy').format(action.timestamp),
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, color: Colors.white.withValues(alpha: 0.05), size: 64),
          const SizedBox(height: 16),
          Text("No recent activities found.", style: GoogleFonts.inter(color: Colors.white24)),
        ],
      ),
    );
  }
}