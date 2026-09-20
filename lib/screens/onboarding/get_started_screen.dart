import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/connectivity_service.dart';

class GetStartedPage extends StatefulWidget {
  const GetStartedPage({super.key});

  @override
  State<GetStartedPage> createState() => _GetStartedPageState();
}

class _GetStartedPageState extends State<GetStartedPage> {
  final _cache = AuthCacheService();
  String? _savedName;
  bool _hasSavedAccount = false;
  bool _checking = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSavedAccount();
  }

  Future<void> _checkSavedAccount() async {
    await _cache.init();
    final user = FirebaseAuth.instance.currentUser;
    final cacheMatches = user == null || user.uid == _cache.cachedUid;
    String? name = cacheMatches ? _cache.cachedName : null;
    if (name == null || name.trim().isEmpty) name = user?.displayName;
    final hasAccount = user != null || _cache.hasSavedAccount;
    if (!mounted) return;
    // Publish local identity immediately, including on offline cold starts.
    setState(() {
      _savedName = name;
      _hasSavedAccount = hasAccount;
      _checking = false;
    });
    if (!hasAccount || (name != null && name.trim().isNotEmpty)) return;
    final uid = user?.uid ?? _cache.cachedUid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('farmers')
          .doc(uid)
          .get(
            GetOptions(
              source: ConnectivityService().isOnline
                  ? Source.serverAndCache
                  : Source.cache,
            ),
          )
          .timeout(const Duration(seconds: 4));
      final data = doc.data();
      final profileName = data?['name'] ?? data?['fullName'];
      if (profileName is String && profileName.trim().isNotEmpty) {
        if (_cache.cachedUid == uid) {
          await _cache.updateProfile(name: profileName.trim());
        }
        if (mounted) setState(() => _savedName = profileName.trim());
      }
    } catch (_) {
      // An unavailable profile must never block the locally saved session.
    }
  }

  Future<void> _openLogin() async {
    await Navigator.pushNamed(context, '/login');
    if (mounted) await _checkSavedAccount();
  }

  Future<void> _continueSavedSession() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_cache.cachedUid == user.uid) await _cache.continueSavedSession();
        if (mounted) Navigator.pushReplacementNamed(context, '/root');
      } else if (!ConnectivityService().isOnline &&
          await _cache.continueSavedSession()) {
        if (mounted) Navigator.pushReplacementNamed(context, '/root');
      } else if (mounted) {
        await Navigator.pushNamed(
          context,
          '/login',
          arguments: {
            'email': _cache.cachedEmail,
            'autoFillMessage':
                'Welcome back! Please enter your password to sign in.',
          },
        );
        if (mounted) await _checkSavedAccount();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to restore your session. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _savedName?.trim();
    final displayName = name != null && name.isNotEmpty
        ? name.split(RegExp(r'\s+')).first
        : 'Farmer';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0F1B0D),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1B0D),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/login-bg.png', fit: BoxFit.cover),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x220F1B0D),
                    Color(0x550F1B0D),
                    Color(0xDD0F1B0D),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 48).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              width: 78,
                              height: 78,
                              semanticLabel: 'Visaia logo',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'VISAIA',
                              style: GoogleFonts.epilogue(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'SMART CROP PROTECTION',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.epilogue(
                                color: const Color(0xFFD5E8BC),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 56),
                            const Spacer(),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 18,
                                    sigmaY: 18,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(26),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2E3E24,
                                      ).withValues(alpha: 0.72),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.spa_outlined,
                                              color: Color(0xFFBADA9B),
                                              size: 19,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _hasSavedAccount
                                                    ? 'WELCOME BACK'
                                                    : 'GROW WITH CONFIDENCE',
                                                style: GoogleFonts.epilogue(
                                                  color: const Color(
                                                    0xFFBADA9B,
                                                  ),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          'A little care.\nA thriving farm.',
                                          style: GoogleFonts.epilogue(
                                            color: Colors.white,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            height: 1.15,
                                            letterSpacing: -1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _hasSavedAccount
                                              ? 'Your crops, your community, your next season. Pick up where you left off.'
                                              : 'Keep an eye on your crops and connect with a community that grows together.',
                                          style: GoogleFonts.epilogue(
                                            color: const Color(0xFFDCE4D6),
                                            fontSize: 14,
                                            height: 1.65,
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: _checking || _isLoading
                                                ? null
                                                : (_hasSavedAccount
                                                      ? _continueSavedSession
                                                      : _openLogin),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF1B6A2D,
                                              ),
                                              foregroundColor: Colors.white,
                                              disabledBackgroundColor:
                                                  const Color(0xFF31563A),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 18,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(28),
                                              ),
                                            ),
                                            child: _checking || _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Flexible(
                                                        child: Text(
                                                          _hasSavedAccount
                                                              ? 'Continue as $displayName'
                                                              : 'Get started',
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              GoogleFonts.epilogue(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        size: 19,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Center(
                                          child: TextButton(
                                            onPressed: _checking || _isLoading
                                                ? null
                                                : (_hasSavedAccount
                                                      ? _openLogin
                                                      : () =>
                                                            Navigator.pushNamed(
                                                              context,
                                                              '/register',
                                                            )),
                                            child: Text(
                                              _hasSavedAccount
                                                  ? 'Use another account'
                                                  : 'Create an account',
                                              style: GoogleFonts.epilogue(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Rooted in care. Ready for tomorrow.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.epilogue(
                                color: const Color(0xFFC8D4BD),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
