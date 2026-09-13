import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/services/auth_cache_service.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final AuthCacheService _cacheService = AuthCacheService();
  String? _savedName;
  bool _hasSavedAccount = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSavedAccount();
  }

  Future<void> _checkSavedAccount() async {
    await _cacheService.init();

    String? name = _cacheService.cachedName;
    bool hasAccount = _cacheService.hasSavedAccount;

    // Also check Firebase current user if online
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      hasAccount = true;
      if (name == null || name.trim().isEmpty) {
        name = firebaseUser.displayName;
      }
    }

    // Try to load farmer name from Firestore if missing
    if (hasAccount && (name == null || name.trim().isEmpty)) {
      final uid = firebaseUser?.uid ?? _cacheService.cachedUid;
      if (uid != null && uid.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('farmers').doc(uid).get();
          if (doc.exists) {
            name = doc.data()?['name'] ?? doc.data()?['fullName'];
            if (name != null && name.trim().isNotEmpty) {
              await _cacheService.updateProfile(name: name.trim());
            }
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _hasSavedAccount = hasAccount;
        _savedName = name;
      });
    }
  }

  Future<void> _continueSavedSession() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _cacheService.continueSavedSession();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/root');
      }
    } catch (_) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/root');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Make the app fullscreen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final displayName = _savedName != null && _savedName!.trim().isNotEmpty
        ? _savedName!.trim().split(' ').first
        : 'Farmer';

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            // Dark overlay for better text visibility
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo and brand name at the top
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo image
                        Image.asset(
                          'assets/images/logo.png',
                          width: 40,
                          height: 40,
                        ),
                        const SizedBox(width: 10),
                        // Brand name
                        Text(
                          'VISAIA',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Main tagline with colored "Protected 24/7"
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      children: const [
                        TextSpan(text: 'Rest Easy Knowing\nYour Crops Are\n'),
                        TextSpan(
                          text: 'Protected 24/7.',
                          style: TextStyle(color: Color(0xFF8DBA60)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Row with text container and images
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Square container with text
                      Container(
                        width: 110,
                        height: 150,
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Join farmers sharing alerts and solutions.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF333333),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // First crop image
                      Container(
                        width: 110,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/img1.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Second crop image
                      Container(
                        width: 110,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: const DecorationImage(
                            image: AssetImage('assets/images/img2.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Action buttons
                  if (_hasSavedAccount) ...[
                    // Continue as [Name] button
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _continueSavedSession,
                          icon: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          label: Text(
                            _isLoading ? 'Loading...' : 'Continue as $displayName',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: Text(
                          'Switch or use another account',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Standard Start Farming button
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Start Farming',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}