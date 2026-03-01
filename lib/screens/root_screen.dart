import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/widgets/custom_nav_bar.dart';
import 'package:visaia/screens/monitoring/monitoring_dashboard_screen.dart';
import 'package:visaia/screens/reporting/pest_report_submission_screen.dart';
import 'package:visaia/screens/map/map_screen.dart';
import 'package:visaia/screens/history/action_history_screen.dart';
import 'package:visaia/screens/mitigation/mitigation_screen.dart';
import 'package:visaia/screens/onboarding/onboarding_screens.dart';

class VisaiaAppRoot extends StatefulWidget {
  const VisaiaAppRoot({super.key});

  @override
  State<VisaiaAppRoot> createState() => _VisaiaAppRootState();
}

class _VisaiaAppRootState extends State<VisaiaAppRoot> {
  bool _showOnboarding = true; // Set to true to start with onboarding

  void _completeOnboarding() {
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      // Pass the completion callback to your onboarding screen
      return OnboardingScreen(onFinish: _completeOnboarding);
    }
    return const RootLayout();
  }
}

class RootLayout extends StatefulWidget {
  const RootLayout({super.key});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  int _selectedIndex = 2;

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
      'widget': const ActionHistoryScreen(),
    },
    {
      'title': 'MITIGATION HUB',
      'label': 'Risk Control',
      'widget': const MitigationProtocolScreen(),
    },
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  String _capitalizeTitle(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
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

    // Specialized Header for Map View (overlapping style)
    if (_selectedIndex == 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page['title'],
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  page['label'],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF8DBA60),
                  ),
                ),
              ],
            ),
            _buildTopActionGroup(),
          ],
        ),
      );
    }

    // Centered Header for all other screens
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back Button (Left)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = 2), // Navigate back to Dashboard
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
            ),
          ),

          // Centered Title
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _capitalizeTitle(page['title']),
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              if (page['label'] != null)
                Text(
                  page['label'].toString().toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8DBA60),
                    letterSpacing: 1.2,
                  ),
                ),
            ],
          ),

          // Notification & Profile (Right)
          Align(
            alignment: Alignment.centerRight,
            child: _buildTopActionGroup(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionGroup() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Notification Icon with Badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none_outlined, color: Colors.white70, size: 24),
              onPressed: () {},
            ),
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF8DBA60),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        // Profile Placeholder
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            image: const DecorationImage(
              image: NetworkImage('https://via.placeholder.com/150'), // Placeholder
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }
}