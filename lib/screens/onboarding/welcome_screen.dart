import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/root_screen.dart';

class InitializationScreen extends StatefulWidget {
  final String firstName;
  final VoidCallback onFinished;

  const InitializationScreen({
    super.key,
    required this.firstName,
    required this.onFinished,
    });

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  bool _isInitialized = false;

  // Design Constants
  final Color _primaryGreen = const Color(0xFF064439);
  final Color _accentGreen = const Color(0xFFB2D98D);
  final Color _bgLight = const Color(0xFFF9FBF9);

  @override
  void initState() {
    super.initState();
    // Start the transition timer
    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: Stack(
        children: [
          // 1. Subtle Radial Halo Background Effect
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _accentGreen.withValues(alpha: 0.15),
                    _bgLight.withValues(alpha: 0.0),
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top Greeting
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: 'Hi, '),
                          TextSpan(
                            text: '${widget.firstName.toUpperCase()}!',
                            style: TextStyle(color: _accentGreen),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Character Image
                    Image.asset(
                      'assets/images/nobg-gardo.png',
                      height: MediaQuery.of(context).size.height * 0.4,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 40),

                    // Animated Content Switcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _isInitialized ? _buildWelcomeState() : _buildLoadingState(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // State 1: Initializing View
  Widget _buildLoadingState() {
    return Column(
      key: const ValueKey('loading'),
      children: [
        Text(
          'Initializing\nYour Farm',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _primaryGreen,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your farm is now being initialized\nfor you to manage.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        // Custom Dot Indicator Pattern
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < 3 ? _primaryGreen : _accentGreen.withValues(alpha: 0.5),
              ),
            );
          }),
        ),
      ],
    );
  }

  // State 2: Welcome View
  Widget _buildWelcomeState() {
    return Column(
      key: const ValueKey('welcome'),
      children: [
        Text(
          'Welcome to\nVISAIA',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _primaryGreen,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Your farm is now ready for intelligent monitoring. Let's grow smarter, together.",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 48),
        // Action Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: () {
              // Navigate to RootLayout directly from here
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RootLayout()),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: _primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Explore Dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 10),
                Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ],
    );
  }
}