import 'package:flutter/material.dart';
import 'package:visaia/screens/map/map_screen.dart';
import 'package:visaia/screens/dashboard_screens/dashboard.dart';
import 'package:visaia/screens/mitigation/mitigation_screen.dart';
import 'package:visaia/screens/onboarding/farm_area_setup.dart';
import 'package:visaia/screens/profile_screens/profile_screen.dart';
import 'package:visaia/screens/dashboard_screens/notifications.dart';
import 'package:visaia/screens/dashboard_screens/full_analysis.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

enum NavItem { mitigation, home, cycle, map, profile }

// ─── App Root ────────────────────────────────────────────────────────────────
class VisaiaAppRoot extends StatefulWidget {
  const VisaiaAppRoot({super.key});

  @override
  State<VisaiaAppRoot> createState() => _VisaiaAppRootState();
}

class _VisaiaAppRootState extends State<VisaiaAppRoot> {
  bool? _isFarmSetupComplete;

  @override
  void initState() {
    super.initState();
    _checkFarmSetup();
  }

  Future<void> _checkFarmSetup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          final hasFarm = doc.data()?['hasFarm'] as bool? ?? false;
          final hasFields = doc.data()?['hasFields'] as bool? ?? false;
          
          setState(() => _isFarmSetupComplete = hasFarm && hasFields);
        } else {
          setState(() => _isFarmSetupComplete = false);
        }
      } else {
        setState(() => _isFarmSetupComplete = false);
      }
    } catch (e) {
      setState(() => _isFarmSetupComplete = false);
    }
  }

  Future<void> _completeFarmSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'hasFarm': true,
        'hasFields': true,
      }, SetOptions(merge: true));
    }
    setState(() => _isFarmSetupComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFarmSetupComplete == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8DBA60)),
        ),
      );
    }
    if (_isFarmSetupComplete == false) {
      return FarmAreaSetup(onFinished: _completeFarmSetup);
    }
    return const RootLayout();
  }
}

// ─── Root Layout ─────────────────────────────────────────────────────────────
class RootLayout extends StatefulWidget {
  const RootLayout({super.key});

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> with TickerProviderStateMixin {
  NavItem _selectedItem = NavItem.home;
  NavItem _previousItem = NavItem.home;
  
  // Animation for the sliding bubble
  late AnimationController _navController;
  // Animation for the 4 emitting buttons
  late AnimationController _menuController;
  bool _isMenuOpen = false;

  // Reordered Items (4 in the bar)
  static const _navItems = [
    NavItem.home,
    NavItem.cycle,
    NavItem.map,
    NavItem.mitigation,
  ];

  // All possible pages (including Profile)
  static const List<Widget> _pages = [
    VisaiaDashboard(),
    Center(child: Text("Cycle")),
    MapViewScreen(),
    MitigationProtocolScreen(),
    ProfileScreen(),
  ];

  // Meta for the 4 bottom items
  static const _itemMeta = [
    (Icons.eco_outlined, Icons.eco, 'HOME'),
    (Icons.recycling_rounded, Icons.recycling_rounded, 'CYCLE'),
    (Icons.map_outlined, Icons.map, 'MAP'),
    (Icons.shield_outlined, Icons.shield, 'MITIGATION'),
  ];

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;

    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _navController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  void _onNavTapped(NavItem item) {
    if (item == _selectedItem) return;
    if (_isMenuOpen) _toggleMenu(); // Close menu if navigating
    setState(() {
      _previousItem = _selectedItem;
      _selectedItem = item;
    });
    _navController.forward(from: 0);
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      _isMenuOpen ? _menuController.forward() : _menuController.reverse();
    });
  }

  int _getCurrentStackIndex() {
    switch (_selectedItem) {
      case NavItem.home:
        return 0;
      case NavItem.cycle:
        return 1;
      case NavItem.map:
        return 2;
      case NavItem.mitigation:
        return 3;
      case NavItem.profile:
        return 4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final bool isMapScreen = _selectedItem == NavItem.map;

    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      appBar: isMapScreen ? null : AppBar(
        leading: const Icon(Icons.menu, color: Color(0xFF0C503C)),
        title: Text('VISAIA', style: GoogleFonts.inter(color: const Color(0xFF0C503C), fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black54), onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AlertsPage(),
              ),
            ),
          },
        ),
          // Profile Action Placeholder
          GestureDetector(
            onTap: () => _onNavTapped(NavItem.profile),
            child: Container(
              margin: const EdgeInsets.only(right: 16, left: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFF0F0F0),
                child: Icon(Icons.person_outline, size: 20, color: _selectedItem == NavItem.profile ? const Color(0xFF1A5C30) : Colors.black54),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(
            index: _getCurrentStackIndex(),
            children: _pages,
          ),
          
          // The Circular Menu overlay
          if (_isMenuOpen || _menuController.isAnimating)
            IgnorePointer(
              ignoring: !_isMenuOpen,
              child: _buildCircularMenu(bottomPadding),
            ),

          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding,
            child: _buildNavBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularMenu(double bottomPadding) {
    return AnimatedBuilder(
      animation: _menuController,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(_menuController.value);

        final List<Map<String, dynamic>> actions = [
          {
            "icon": Icons.shutter_speed_outlined,
            "label": "Upload\nPest",
            "onTap": null, // safe placeholder
          },
          {
            "icon": Icons.description_outlined,
            "label": "Add Logs",
            "onTap": null,
          },
          {
            "icon": Icons.eco_outlined,
            "label": "Start Cycle",
            "onTap": null,
          },
          {
            "icon": Icons.pie_chart_outline,
            "label": "Full\nAnalysis",
            "onTap": () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const IncomeEstimationScreen(),
                ),
              );
            }
          },
        ];

        final offsets = [
          const Offset(-110, -50),
          const Offset(-45, -110),
          const Offset(45, -110),
          const Offset(110, -50),
        ];

        return Stack(
          children: [
            // BACKDROP (safe touch blocker)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withOpacity(0.3 * _menuController.value),
              ),
            ),

            // BUTTONS
            ...List.generate(actions.length, (index) {
              final action = actions[index];
              final offset = offsets[index];

              return Positioned(
                bottom: 80 + (offset.dy * progress).abs(),
                left: MediaQuery.of(context).size.width / 2 +
                    (offset.dx * progress) -
                    30,
                child: Opacity(
                  opacity: _menuController.value,
                  child: Transform.scale(
                    scale: progress,
                    child: GestureDetector(
                      onTap: () {
                        _toggleMenu();
                        final VoidCallback? onTap = action["onTap"];
                        onTap?.call();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action["label"],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 54,
                            height: 54,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              action["icon"],
                              color: const Color(0xFF1A5C30),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildNavBar() {
    const double bubbleRadius = 28.0;
    const double barHeight = 68.0;
    const double totalHeight = barHeight + bubbleRadius;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // White Pill Background
          Positioned(
            top: bubbleRadius,
            left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 16, offset: const Offset(0, -2))],
              ),
            ),
          ),

          // Tap targets with labels
          Positioned(
            top: bubbleRadius,
            left: 0, right: 0, bottom: 0,
            child: Row(
              children: [
                Expanded(child: _buildNavItem(0)), // Home
                Expanded(child: _buildNavItem(1)), // Cycle
                const Expanded(child: SizedBox()), // Hole for Add Button
                Expanded(child: _buildNavItem(2)), // Map
                Expanded(child: _buildNavItem(3)), // Mitigation
              ],
            ),
          ),

          // Sliding Bubble Logic
          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / 5;
              final currentIndex = _navItems.indexOf(_selectedItem);
              if (currentIndex < 0) return const SizedBox.shrink();
              final previousIndex = _navItems.indexOf(_previousItem);
              if (previousIndex < 0) return const SizedBox.shrink();
              
              // We adjust the index to skip the middle slot (index 2)
              double getSlotX(int navIndex) => (navIndex < 2 ? navIndex : navIndex + 1) * slotWidth + (slotWidth / 2);

              return AnimatedBuilder(
                animation: _navController,
                builder: (context, _) {
                  if (!_navItems.contains(_selectedItem)) return const SizedBox.shrink();

                  final t = Curves.easeInOut.transform(_navController.value);
                  final cx = _lerpD(getSlotX(previousIndex), getSlotX(currentIndex), t);

                  return Stack(
                    children: [
                      Positioned(
                        left: cx - bubbleRadius,
                        top: 0,
                        child: Container(
                          width: bubbleRadius * 2, height: bubbleRadius * 2,
                          decoration: const BoxDecoration(color: Color(0xFF1A5C30), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x551A5C30), blurRadius: 10, offset: Offset(0, 3))]),
                        ),
                      ),
                      Positioned(
                        left: cx - 13,
                        top: bubbleRadius - 13,
                        child: Icon(_itemMeta[currentIndex].$2, color: Colors.white, size: 26),
                      ),
                    ],
                  );
                },
              );
            }),
          ),

          // The Permanent Add Button (Centered)
          Positioned(
            top: 0,
            left: MediaQuery.of(context).size.width / 2 - 32,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 300),
                turns: _isMenuOpen ? 0.125 : 0,
                child: Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: Color(0xFF0C503C), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))]),
                  child: const Icon(Icons.add, color: Colors.white, size: 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isNowActive = _selectedItem == item;
    final wasActive = _previousItem == item;
    final (inactiveIcon, _, label) = _itemMeta[index];

    return GestureDetector(
      onTap: () => _onNavTapped(item),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _navController,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_navController.value);
          double activeWeight = isNowActive && wasActive ? 1.0 : isNowActive ? t : wasActive ? 1.0 - t : 0.0;

          final iconOpacity = (1.0 - activeWeight).clamp(0.0, 1.0);
          final labelColor = Color.lerp(const Color(0xFF9E9E9E), const Color(0xFF1A5C30), activeWeight)!;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(opacity: iconOpacity, child: Icon(inactiveIcon, color: const Color(0xFF9E9E9E), size: 22)),
              const SizedBox(height: 4),
              Text(label, style: GoogleFonts.inter(color: labelColor, fontSize: 9, fontWeight: activeWeight > 0.5 ? FontWeight.w700 : FontWeight.w500)),
            ],
          );
        },
      ),
    );
  }
}

double _lerpD(double a, double b, double t) => a + (b - a) * t;