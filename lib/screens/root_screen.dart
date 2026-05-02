import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/map/map_screen.dart';
import 'package:visaia/screens/dashboard_screens/dashboard.dart';
import 'package:visaia/screens/onboarding/farm_area_setup.dart';
import 'package:visaia/screens/profile_screens/profile_screen.dart';
import 'package:visaia/screens/dashboard_screens/notifications.dart';
import 'package:visaia/screens/dashboard_screens/full_analysis.dart';
import 'package:visaia/screens/mitigation_screens/mitigation_screen.dart';
import 'package:visaia/screens/logging_screens/daily_log_screen.dart';
import 'package:visaia/screens/logging_screens/field_scouting_screen.dart';
import 'package:visaia/screens/logging_screens/inspect_trap_screen.dart';
import 'package:visaia/screens/cycle_screens/start_cycle.dart';
import 'package:visaia/screens/dashboard_screens/cycles_screen.dart';

enum NavItem { mitigation, home, cycle, map, profile }

// ─── Add Log Modal ────────────────────────────────────────────────────────────

void showAddLogModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AddLogModal(),
  );
}

class _AddLogModal extends StatelessWidget {
  final user = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Text(
            'Add a Log',
            style: GoogleFonts.inter(
              color: const Color(0xFF0C503C),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'What would you like to record?',
            style: GoogleFonts.inter(
              color: const Color(0xFF9E9E9E),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 20),

          // Option tiles
          _LogOptionTile(
            icon: Icons.edit_note_rounded,
            title: 'Daily Log',
            description: 'Record routine farm activities',
            onTap: () {
              Navigator.pop(context);

              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DailyLogFormScreen(
                    userId: user!.uid,
                    cycleId: '',
                    shouldAssignCycle: true,
                    )),
              );
            },
          ),
          const SizedBox(height: 12),
          _LogOptionTile(
            icon: Icons.grass_rounded,
            title: 'Field Scouting',
            description: 'Weekly crop inspection',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FieldScoutingFormScreen(
                  userId: user!.uid,
                  cycleId: '',
                )),
              );
            },
          ),
          const SizedBox(height: 12),
          _LogOptionTile(
            icon: Icons.pest_control_rounded,
            title: 'Inspect Trap',
            description: 'Weekly pheromone trap check',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InspectTrapScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LogOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _LogOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDDEEE4), width: 1.2),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF1A5C30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0C503C),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF9E9E9E),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDBDBD), size: 22),
          ],
        ),
      ),
    );
  }
}

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

  late AnimationController _navController;
  late AnimationController _menuController;
  bool _isMenuOpen = false;

  static const _navItems = [
    NavItem.home,
    NavItem.cycle,
    NavItem.map,
    NavItem.mitigation,
  ];

  static const List<Widget> _pages = [
    HomeDashboard(),
    CroppingCyclesScreen(),
    MapViewScreen(),
    MitigationScreen(),
    ProfileScreen(),
  ];

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
    if (_isMenuOpen) _toggleMenu();
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
      appBar: isMapScreen
          ? null
          : AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,

              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Color(0xFF0C503C), size: 28),
                onPressed: () {},
              ),
              title: Text('VISAIA',
                  style: GoogleFonts.epilogue(
                      color: const Color(0xFF0C503C),
                      fontWeight: FontWeight.w800,
                      fontSize: 22)),
              actions: [
                GestureDetector (
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AlertsPage())
                    );
                  },
                  child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8, right: 8),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF0C503C),
                        size: 28,
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 10,
                      child: Container(
                        height: 10,
                        width: 10,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    )
                  ],
                ),
              ),        

              const SizedBox(width: 8),

              // ─── PROFILE (KEPT YOUR NAV LOGIC) ───
              GestureDetector(
                onTap: () => _onNavTapped(NavItem.profile),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFE0E0E0),
                  backgroundImage: NetworkImage(
                    'https://ui-avatars.com/api/?background=0D4D33&color=fff&name=AJ',
                  ),
                ),
              ),

              const SizedBox(width: 16),
            ],
          ),    
      body: Stack(
        children: [
          IndexedStack(
            index: _getCurrentStackIndex(),
            children: _pages,
          ),

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
            "onTap": null,
          },
          {
            "icon": Icons.description_outlined,
            "label": "Add Logs",
            // ── KEY CHANGE: opens the modal ──────────────────────────────
            "onTap": () {
              showAddLogModal(context);
            },
          },
          {
            "icon": Icons.eco_outlined,
            "label": "Start New Cycle",
            "onTap": () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => StartCroppingCycleScreen()));
            },
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
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withOpacity(0.3 * _menuController.value),
              ),
            ),

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
          Positioned(
            top: bubbleRadius,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: const Offset(0, -2))
                ],
              ),
            ),
          ),

          Positioned(
            top: bubbleRadius,
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: [
                Expanded(child: _buildNavItem(0)),
                Expanded(child: _buildNavItem(1)),
                const Expanded(child: SizedBox()),
                Expanded(child: _buildNavItem(2)),
                Expanded(child: _buildNavItem(3)),
              ],
            ),
          ),

          Positioned.fill(
            child: LayoutBuilder(builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / 5;
              final currentIndex = _navItems.indexOf(_selectedItem);
              if (currentIndex < 0) return const SizedBox.shrink();
              final previousIndex = _navItems.indexOf(_previousItem);
              if (previousIndex < 0) return const SizedBox.shrink();

              double getSlotX(int navIndex) =>
                  (navIndex < 2 ? navIndex : navIndex + 1) * slotWidth +
                  (slotWidth / 2);

              return AnimatedBuilder(
                animation: _navController,
                builder: (context, _) {
                  if (!_navItems.contains(_selectedItem)) {
                    return const SizedBox.shrink();
                  }

                  final t = Curves.easeInOut.transform(_navController.value);
                  final cx = _lerpD(
                      getSlotX(previousIndex), getSlotX(currentIndex), t);

                  return Stack(
                    children: [
                      Positioned(
                        left: cx - bubbleRadius,
                        top: 0,
                        child: Container(
                          width: bubbleRadius * 2,
                          height: bubbleRadius * 2,
                          decoration: const BoxDecoration(
                              color: Color(0xFF1A5C30),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x551A5C30),
                                    blurRadius: 10,
                                    offset: Offset(0, 3))
                              ]),
                        ),
                      ),
                      Positioned(
                        left: cx - 13,
                        top: bubbleRadius - 13,
                        child: Icon(_itemMeta[currentIndex].$2,
                            color: Colors.white, size: 26),
                      ),
                    ],
                  );
                },
              );
            }),
          ),

          Positioned(
            top: 0,
            left: MediaQuery.of(context).size.width / 2 - 32,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFF0C503C),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedIcon(
                    icon: AnimatedIcons.add_event,
                    progress: _menuController,
                    color: Colors.white,
                    size: 32,
                  ),
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
          double activeWeight = isNowActive && wasActive
              ? 1.0
              : isNowActive
                  ? t
                  : wasActive
                      ? 1.0 - t
                      : 0.0;

          final iconOpacity = (1.0 - activeWeight).clamp(0.0, 1.0);
          final labelColor = Color.lerp(
              const Color(0xFF9E9E9E), const Color(0xFF1A5C30), activeWeight)!;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                  opacity: iconOpacity,
                  child: Icon(inactiveIcon,
                      color: const Color(0xFF9E9E9E), size: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: GoogleFonts.inter(
                      color: labelColor,
                      fontSize: 9,
                      fontWeight: activeWeight > 0.5
                          ? FontWeight.w700
                          : FontWeight.w500)),
            ],
          );
        },
      ),
    );
  }
}

double _lerpD(double a, double b, double t) => a + (b - a) * t;