import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/widgets/custom_nav_bar.dart';
import 'package:visaia/screens/monitoring/monitoring_dashboard_screen.dart';
import 'package:visaia/screens/reporting/pest_report_submission_screen.dart';
import 'package:visaia/screens/map/map_screen.dart';

class RootLayout extends StatefulWidget {
  const RootLayout({super.key});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  int _selectedIndex = 2; // Default to MonitoringDashboard (Start Cycle)

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Your Farm',
      'label': 'Live Monitoring Active',
      'widget': const MapViewScreen(),
    },
    {
      'title': 'INFESTATION REPORT',
      'label': 'Pest Analysis',
      'widget': const SubmitPestReportPage(),
    },
    {
      'title': 'FARM ECOSYSTEM',
      'label': 'VISAAIA Monitor',
      'widget': const MonitoringDashboard(),
    },
    {
      'title': 'ACTION HISTORY',
      'label': 'Treatment Logs',
      'widget': const Center(child: Text('History Content', style: TextStyle(color: Colors.white))),
    },
    {
      'title': 'MITIGATION HUB',
      'label': 'Risk Control',
      'widget': const Center(child: Text('Mitigation Content', style: TextStyle(color: Colors.white))),
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      extendBody: _selectedIndex == 0,
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
      body: Stack(
        children: [
          // Background Glows (Shared)
          Positioned(top: -150, left: -100, child: _buildBlurCircle(300, const Color(0xFF8DBA60).withValues(alpha: 0.03))),
          Positioned(bottom: 50, right: -100, child: _buildBlurCircle(400, const Color(0xFF2E8B57).withValues(alpha: 0.05))),
          
          // Content Layer
          Positioned.fill(
            child: Column(
              children: [
                if (_selectedIndex != 0) 
                  SafeArea(bottom: false, child: _buildDynamicHeader())
                else
                  const SizedBox.shrink(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages.map((p) => p['widget'] as Widget).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Floating Header Overlay (Only for Map Screen to allow overlap)
          if (_selectedIndex == 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(bottom: false, child: _buildDynamicHeader()),
            ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDynamicHeader() {
    final page = _pages[_selectedIndex];
    
    if (_selectedIndex == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page['title'],
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    page['label'],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8DBA60),
                    ),
                  ),
                ],
              ),
            ),
            _buildProfileBadge(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedIndex = 0),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _capitalizeTitle(page['title']),
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white, size: 32),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  String _capitalizeTitle(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildProfileBadge() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF8DBA60),
            child: Icon(Icons.person, color: Colors.black, size: 18),
          ),
          SizedBox(width: 8),
          Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 16),
          SizedBox(width: 4),
        ],
      ),
    );
  }
}
