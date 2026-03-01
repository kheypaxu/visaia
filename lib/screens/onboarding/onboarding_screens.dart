import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;

  // Configuration for the 4 screens
  final List<Map<String, dynamic>> _pageData = [
    {
      'topNormalText': "Welcome ",
      'topHighlightText': "New Farmer!",
      'imagePath': 'assets/images/onboarding1.png',
      'bottomNormalText': "Welcome to the ",
      'bottomHighlightText': "Future\nof Farming!",
      'description': "We're glad to have you, Farmer. Let's set up your digital field and start protecting your harvest with VISAIA.",
      'buttonLabel': "Get Started",
      'showSkip': false,
    },
    {
      'topNormalText': "Total Field Awareness,\n",
      'topHighlightText': "Right in Your Pocket.",
      'imagePath': 'assets/images/onboarding2.png',
      'bottomNormalText': "Monitor ",
      'bottomHighlightText': "Your Crops",
      'description': "Keep a close eye on your crops and farmland. Our system provides real-time updates on field conditions to give you total control over your farm's performance.",
      'buttonLabel': "Next",
      'showSkip': true,
    },
    {
      'topNormalText': "Smart Eyes for ",
      'topHighlightText': "Every\nPest.",
      'imagePath': 'complex_stack', // Marker for the special layout
      'bottomNormalText': "Pest Detection and ",
      'bottomHighlightText': "Identification",
      'description': "Stop the spread before it starts. Snap a photo of any insect to get an instant diagnosis and a targeted plan to save your crop.",
      'buttonLabel': "Next",
      'showSkip': true,
    },
    {
      'topNormalText': "One Community, ",
      'topHighlightText': "Zero Infestations.",
      'imagePath': 'assets/images/onboarding4.png',
      'bottomNormalText': "Ready to ",
      'bottomHighlightText': "Grow?",
      'description': "Receive alerts about local infestations and community reports to stay one step ahead of the threat.",
      'buttonLabel': "Finish",
      'showSkip': false,
    },
  ];

  void _nextPage() {
    if (_currentIndex < _pageData.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      widget.onFinish();
    }
  }

  void _skipToEnd() {
    setState(() {
      _currentIndex = _pageData.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final data = _pageData[_currentIndex];
    const double curveDepth = 100.0;
    final double whiteAreaHeight = size.height * 0.58;

    return Scaffold(
      body: Stack(
        children: [
          // 1. STATIC BACKGROUND LAYER
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF142F1B), Color(0xFF050D07)],
              ),
            ),
          ),

          // 2. STATIC GLOW EFFECT
          Positioned(
            top: whiteAreaHeight - 120,
            left: -60,
            child: Container(
              width: 172,
              height: 162,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF8DBA60),
                    blurRadius: 150,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. ANIMATED BOTTOM TEXT CONTENT
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.2, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        key: ValueKey<int>(_currentIndex),
                        padding: const EdgeInsets.symmetric(horizontal: 27),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              textAlign: TextAlign.left,
                              text: TextSpan(
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF), height: 1.2),
                                children: [
                                  TextSpan(text: data['bottomNormalText']),
                                  TextSpan(text: data['bottomHighlightText'], style: const TextStyle(color: Color(0xFF8DBA60))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            RichText(
                              textAlign: TextAlign.justify,
                              text: TextSpan(
                                style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14, height: 1.5),
                                children: [
                                  if (_currentIndex == 0) ...[
                                    const TextSpan(text: "We're glad to have you, Farmer. Let's set up your digital field and start protecting your harvest with "),
                                    const TextSpan(text: "VISAIA.", style: TextStyle(color: Color(0xFF8DBA60))),
                                  ] else
                                    TextSpan(text: data['description']),
                                ],
                              ),
                            ),
                            const SizedBox(height: 130), // Space for buttons below
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. STATIC BUTTON AREA (Does not animate)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFFFFF),
                        foregroundColor: const Color(0xFF000000),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      child: Text(data['buttonLabel'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: data['showSkip']
                      ? TextButton(
                          onPressed: _skipToEnd,
                          child: const Text("Skip", style: TextStyle(color: Color(0xB3FFFFFF))),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // 5. STATIC WHITE TOP SECTION WITH CURVE
          CustomPaint(
            painter: CurveShadowPainter(curveDepth: curveDepth),
            child: ClipPath(
              clipper: WhiteTopCurveClipper(curveDepth: curveDepth),
              child: Container(
                width: double.infinity,
                height: whiteAreaHeight,
                color: const Color(0xFFFFFFFF),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Progress bar stays intact and fixed
                      _buildProgressIndicator(_currentIndex + 1),
                      const SizedBox(height: 25),
                      
                      // ANIMATED TOP CONTENT (Title and Image)
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Column(
                            key: ValueKey<int>(_currentIndex),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF000000), height: 1.2),
                                    children: [
                                      TextSpan(text: data['topNormalText']),
                                      TextSpan(text: data['topHighlightText'], style: const TextStyle(color: Color(0xFF8DBA60))),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: _buildAnimatedImage(data['imagePath']),
                                ),
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedImage(String path) {
    if (path == 'complex_stack') {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: constraints.maxWidth * 0.60,
                top: constraints.maxHeight * 0.01,
                width: 150,
                height: 178,
                child: Image.asset('assets/images/onboarding3.1.png', fit: BoxFit.contain),
              ),
              Positioned(
                left: constraints.maxWidth * 0.01,
                top: constraints.maxHeight * 0.01,
                width: 210,
                height: 210,
                child: Image.asset('assets/images/onboarding3.2.png', fit: BoxFit.contain),
              ),
              Positioned(
                left: constraints.maxWidth * 0.35,
                top: constraints.maxHeight * 0.55,
                width: 133,
                height: 164,
                child: Image.asset('assets/images/onboarding3.3.png', fit: BoxFit.contain),
              ),
            ],
          );
        },
      );
    }
    return Image.asset(path, fit: BoxFit.contain);
  }

  Widget _buildProgressIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        height: 5, width: 35,
        decoration: BoxDecoration(
          color: index < count ? const Color(0xFF8DC63F) : const Color(0x4D9E9E9E),
          borderRadius: BorderRadius.circular(10),
        ),
      )),
    );
  }
}

// --- CLIPPERS AND PAINTERS (UNTOUCHED) ---

class WhiteTopCurveClipper extends CustomClipper<Path> {
  final double curveDepth;
  WhiteTopCurveClipper({required this.curveDepth});
  @override
  Path getClip(Size size) {
    Path path = Path();
    double startHeight = size.height - curveDepth;
    path.lineTo(0, startHeight);
    path.quadraticBezierTo(size.width / 2, size.height + (curveDepth * 0.8), size.width, startHeight);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class CurveShadowPainter extends CustomPainter {
  final double curveDepth;
  CurveShadowPainter({required this.curveDepth});
  @override
  void paint(Canvas canvas, Size size) {
    Path path = Path();
    double startHeight = size.height - curveDepth;
    path.lineTo(0, startHeight);
    path.quadraticBezierTo(size.width / 2, size.height + (curveDepth * 0.8), size.width, startHeight);
    path.lineTo(size.width, 0);
    path.close();
    canvas.drawShadow(path, const Color(0x4D000000), 15.0, true);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}