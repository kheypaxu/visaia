import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:visaia/core/models/crop_type.dart';
import 'package:visaia/screens/monitoring/detection_history_details_screen.dart';

class DetectionHistoryListScreen extends StatefulWidget {
  final FarmArea farmArea;

  const DetectionHistoryListScreen({
    Key? key,
    required this.farmArea,
  }) : super(key: key);

  @override
  State<DetectionHistoryListScreen> createState() => _DetectionHistoryListScreenState();
}

class _DetectionHistoryListScreenState extends State<DetectionHistoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  late List<PestDetection> _filteredDetections;

  @override
  void initState() {
    super.initState();
    _filteredDetections = widget.farmArea.detectionHistory.reversed.toList();
  }

  void _applyFilters() {
    String keyword = _searchController.text.toLowerCase();
    setState(() {
      _filteredDetections = widget.farmArea.detectionHistory.reversed.where((detection) {
        bool matchesSearch = detection.label.toLowerCase().contains(keyword);
        bool matchesDate = true;
        if (_selectedDate != null) {
          matchesDate = detection.timestamp.year == _selectedDate!.year &&
              detection.timestamp.month == _selectedDate!.month &&
              detection.timestamp.day == _selectedDate!.day;
        }
        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF8DBA60),
            onPrimary: Color(0xFF102216),
            surface: Color(0xFF1C2C22),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _applyFilters();
    }
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "TODAY";
    }
    return DateFormat('MMM dd, yyyy').format(date).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const Color bgDark = Color(0xFF102216);
    const Color primaryGreen = Color(0xFF8DBA60);

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Background Glow
          Positioned(top: -100, right: -100, child: _buildBlurCircle(300, primaryGreen.withValues(alpha: 0.05))),
          
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                _buildSearchAndFilter(primaryGreen, bgDark),
                
                Expanded(
                  child: _filteredDetections.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredDetections.length,
                        itemBuilder: (context, index) {
                          final detection = _filteredDetections[index];
                          bool showHeader = false;
                          
                          if (index == 0) {
                            showHeader = true;
                          } else {
                            final prevDate = _filteredDetections[index - 1].timestamp;
                            if (detection.timestamp.day != prevDate.day) showHeader = true;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader) _buildSectionHeader(_formatDateHeader(detection.timestamp)),
                              _buildDetectionCard(context, detection),
                            ],
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text('DETECTION HISTORY', 
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14, 
                letterSpacing: 2, 
                fontWeight: FontWeight.w900, 
                color: const Color(0xFF8DBA60)
              )
            ),
          ),
          const SizedBox(width: 48), // Spacer for balance
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(Color primary, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => _applyFilters(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Search pests or fields...",
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
          const SizedBox(height: 12),
          Row(
            children: [
              ActionChip(
                backgroundColor: _selectedDate == null ? Colors.white.withValues(alpha: 0.05) : primary,
                avatar: Icon(Icons.calendar_today, size: 14, color: _selectedDate == null ? Colors.white54 : bg),
                label: Text(
                  _selectedDate == null ? "Filter by Date" : DateFormat('MMM d').format(_selectedDate!),
                  style: TextStyle(color: _selectedDate == null ? Colors.white54 : bg, fontSize: 12, fontWeight: FontWeight.bold)
                ),
                onPressed: () => _selectDate(context),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                side: BorderSide.none,
              ),
              if (_selectedDate != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                  onPressed: () {
                    setState(() => _selectedDate = null);
                    _applyFilters();
                  },
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(title, 
        style: GoogleFonts.inter(color: const Color(0xFF8DBA60), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    );
  }

  Widget _buildDetectionCard(BuildContext context, PestDetection detection) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetectionHistoryDetailsScreen(detection: detection)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.bug_report, color: Colors.redAccent, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detection.label, 
                    style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text("LARVAE STAGE", // Replace with actual data if available
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFFCEA265), size: 12),
                      const SizedBox(width: 4),
                      Text(DateFormat('hh:mm a').format(detection.timestamp), 
                        style: GoogleFonts.inter(color: const Color(0xFFCEA265), fontSize: 11)),
                      const SizedBox(width: 12),
                      const Icon(Icons.verified, color: Color(0xFF13EC5B), size: 12),
                      const SizedBox(width: 4),
                      Text('${(detection.confidence * 100).toInt()}%', 
                        style: GoogleFonts.inter(color: const Color(0xFF13EC5B), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text("No records match your search", 
        style: GoogleFonts.inter(color: Colors.white24, fontSize: 14)),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    );
  }
}