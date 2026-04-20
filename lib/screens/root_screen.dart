import 'package:flutter/material.dart';
import 'package:visaia/screens/map/map_screen.dart';
import 'package:visaia/screens/dashboard_screens/dashboard.dart';
import 'package:visaia/screens/mitigation/mitigation_screen.dart';
import 'package:visaia/screens/onboarding/farm_area_setup.dart';
import 'package:visaia/screens/profile_screens/profile_screen.dart';
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
        'hasFields': false,
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

class _RootLayoutState extends State<RootLayout>
    with SingleTickerProviderStateMixin {
  NavItem _selectedItem = NavItem.cycle;
  NavItem _previousItem = NavItem.cycle;
  late AnimationController _navController;

  static const _navItems = [
    NavItem.mitigation,
    NavItem.home,
    NavItem.cycle,
    NavItem.map,
    NavItem.profile,
  ];

  static const List<Widget> _pages = [
    MitigationProtocolScreen(),
    VisaiaDashboard(),
    Center(child: Text("Cycle")),
    MapViewScreen(),
    ProfileScreen(),
  ];

  // Each item: (inactive icon, active icon, label)
  static const _itemMeta = [
    (Icons.shield_outlined,       Icons.shield,               'MITIGATION'),
    (Icons.eco_outlined,          Icons.eco,                  'HOME'),
    (Icons.recycling_rounded,     Icons.recycling_rounded,    'CYCLE'),
    (Icons.map_outlined,          Icons.map,                  'MAP'),
    (Icons.person_outline_rounded,Icons.person_rounded,       'PROFILE'),
  ];

  bool get _isMapScreen => _selectedItem == NavItem.map;

  @override
  void initState() {
    super.initState();
    _navController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;
  }

  @override
  void dispose() {
    _navController.dispose();
    super.dispose();
  }

  void _onNavTapped(NavItem item) {
    if (item == _selectedItem) return;
    setState(() {
      _previousItem = _selectedItem;
      _selectedItem = item;
    });
    _navController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF102216),
      appBar: _isMapScreen
          ? null
          : AppBar(
              leading: const Icon(Icons.menu, color: Color(0xFF0C503C)),
              title: const Text(
                'VISAIA',
                style: TextStyle(
                  color: Color(0xFF0C503C),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              centerTitle: false,
              backgroundColor: Colors.white,
              elevation: 0,
              actions: [
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.notifications_none, color: Colors.black54),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 10,
                            minHeight: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 16),
              ],
            ),
      body: Stack(
        children: [
          IndexedStack(
            index: _navItems.indexOf(_selectedItem),
            children: _pages,
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

  Widget _buildNavBar() {
    // Bubble radius = 28, pill top = 28px from SizedBox top
    // So bubble center sits exactly on the pill's top edge
    const double bubbleRadius = 28.0;
    const double barHeight = 68.0;
    // Total height = bubble diameter + bar, minus the overlap
    const double overlapAbovePill = bubbleRadius; // bubble peeks up by its radius
    const double totalHeight = barHeight + overlapAbovePill;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── White pill — starts at overlapAbovePill from top ─────────────
          Positioned(
            top: overlapAbovePill,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            ),
          ),

          // ── Tap targets + labels row (inside the pill area) ──────────────
          Positioned(
            top: overlapAbovePill,
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: List.generate(_navItems.length, (i) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onNavTapped(_navItems[i]),
                    behavior: HitTestBehavior.opaque,
                    child: _buildLabel(i),
                  ),
                );
              }),
            ),
          ),

          // ── Sliding bubble + icon ─────────────────────────────────────────
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _navItems.length;
                final currentIndex = _navItems.indexOf(_selectedItem);
                final previousIndex = _navItems.indexOf(_previousItem);

                return AnimatedBuilder(
                  animation: _navController,
                  builder: (context, _) {
                    final t = Curves.easeInOut.transform(_navController.value);
                    final cx = _lerpD(
                      previousIndex * itemWidth + itemWidth / 2,
                      currentIndex * itemWidth + itemWidth / 2,
                      t,
                    );

                    // Bubble top stays fixed at y=0 (peeks above pill)
                    const double bubbleTop = 0;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Circle
                        Positioned(
                          left: cx - bubbleRadius,
                          top: bubbleTop,
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
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Icon centered in bubble
                        Positioned(
                          left: cx - 13,
                          top: bubbleTop + bubbleRadius - 13,
                          child: Icon(
                            _itemMeta[currentIndex].$2,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(int index) {
    final item = _navItems[index];
    final isNowActive = _selectedItem == item;
    final wasActive = _previousItem == item;
    final (inactiveIcon, _, label) = _itemMeta[index];

    return AnimatedBuilder(
      animation: _navController,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_navController.value);

        double activeWeight;
        if (isNowActive && wasActive) {
          activeWeight = 1.0;
        } else if (isNowActive) {
          activeWeight = t;
        } else if (wasActive) {
          activeWeight = 1.0 - t;
        } else {
          activeWeight = 0.0;
        }

        // Active item: icon is hidden (bubble covers it), label turns green
        // Inactive item: icon visible gray, label visible gray
        final iconOpacity = (1.0 - activeWeight).clamp(0.0, 1.0);
        final labelColor = Color.lerp(
          const Color(0xFF9E9E9E),
          const Color(0xFF1A5C30),
          activeWeight,
        )!;
        final labelWeight = activeWeight > 0.5
            ? FontWeight.w700
            : FontWeight.w500;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Reserve space for icon even when invisible (keeps layout stable)
            Opacity(
              opacity: iconOpacity,
              child: Icon(inactiveIcon, color: const Color(0xFF9E9E9E), size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: labelColor,
                fontSize: 9,
                fontWeight: labelWeight,
                letterSpacing: 0.3,
              ),
            ),
          ],
        );
      },
    );
  }
}

double _lerpD(double a, double b, double t) => a + (b - a) * t;