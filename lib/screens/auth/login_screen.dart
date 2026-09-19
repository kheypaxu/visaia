import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/auth/forgot_password_screen.dart';
import 'package:visaia/screens/auth/registration_screen.dart';
import 'package:visaia/services/auth_service.dart';
import 'package:visaia/screens/root_screen.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/connectivity_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // =========================================================================
  // ADJUSTABLE LAYOUT & SPACING SETTINGS
  // Modify these values to adjust the position and size of screen components
  // =========================================================================
  static const double logoSize = 85.0; // Size (width & height) of the logo
  static const double spacingAboveLoginContainer = 80.0; // Gap above the login container card
  static const double topSpacingBelowBackButton = 8.0; // Gap between back button and logo
  static const double spacingBelowLogo = 10.0; // Gap between logo and brand text
  static const double spacingBelowBrand = 4.0; // Gap between brand text and tagline
  // =========================================================================

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Password visibility state
  bool _obscurePassword = true;

  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isLoading = false;
  bool _didCheckArgs = false;

  @override
  void initState() {
    super.initState();
    final cachedEmail = AuthCacheService().cachedEmail;
    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      _emailController.text = cachedEmail;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCheckArgs) {
      _didCheckArgs = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['email'] != null && (args['email'] as String).isNotEmpty) {
          _emailController.text = args['email'] as String;
        }
        if (args['autoFillMessage'] != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    args['autoFillMessage'] as String,
                    style: GoogleFonts.epilogue(),
                  ),
                  backgroundColor: const Color(0xFF1A5C30),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Handles both online Firebase auth and offline cached auth
      await _authService.signInAndVerify(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final isOnline = _connectivityService.isOnline;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle : Icons.offline_pin_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isOnline ? 'Login Successful!' : 'Offline Login Successful!',
                  style: GoogleFonts.epilogue(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A5C30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VisaiaAppRoot()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.epilogue(),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge transparent system overlay for true full screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B0D),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Fullscreen background image layer (covers entire display)
          Positioned.fill(
            child: Image.asset(
              'assets/images/login-bg.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              alignment: Alignment.center,
            ),
          ),

          // 2. Subtle gradient overlay for readability and depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),

          // 3. Scrollable content layout with safe area
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top Navigation Row
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacementNamed(context, '/get-started');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: topSpacingBelowBackButton),

                          // Official App Logo Image
                          Image.asset(
                            'assets/images/logo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),

                          const SizedBox(height: spacingBelowLogo),

                          // VISAI A Text Logo in Epilogue Font
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.epilogue(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.8,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              children: const [
                                TextSpan(
                                  text: 'VIS',
                                  style: TextStyle(color: Colors.white),
                                ),
                                TextSpan(
                                  text: 'AI',
                                  style: TextStyle(color: Color(0xFF1B6A2D)),
                                ),
                                TextSpan(
                                  text: 'A',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: spacingBelowBrand),

                          // Tagline in Epilogue Font
                          Text(
                            'SMART CROP PROTECTION',
                            style: GoogleFonts.epilogue(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                              color: const Color(0xFF1B5E20),
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),

                          // Adjustable Spacing above the login container card
                          const SizedBox(height: spacingAboveLoginContainer),

                          // Glassmorphic Login Card
                          ClipRRect(
                            borderRadius: BorderRadius.circular(30.0),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 28.0,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E3E24).withValues(alpha: 0.62),
                                  borderRadius: BorderRadius.circular(30.0),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 30,
                                      offset: const Offset(0, 15),
                                    ),
                                  ],
                                ),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // "Welcome, Farmer" in Epilogue Font
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.epilogue(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Welcome, '),
                                            TextSpan(
                                              text: 'Farmer',
                                              style: GoogleFonts.epilogue(
                                                fontSize: 27,
                                                fontWeight: FontWeight.w800,
                                                fontStyle: FontStyle.italic,
                                                color: const Color(0xFF2EAA4D),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Sign in to manage your ecosystem',
                                        style: GoogleFonts.epilogue(
                                          fontSize: 13.5,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),

                                      // Offline notice banner if offline
                                      ValueListenableBuilder<bool>(
                                        valueListenable: _connectivityService.isOnlineNotifier,
                                        builder: (context, isOnline, _) {
                                          if (isOnline) return const SizedBox(height: 22);
                                          return Container(
                                            margin: const EdgeInsets.only(top: 14, bottom: 12),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF452205).withValues(alpha: 0.9),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFFFB74D),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.wifi_off_rounded,
                                                  color: Color(0xFFFFB74D),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Offline Mode: Using cached credentials.',
                                                    style: GoogleFonts.epilogue(
                                                      color: const Color(0xFFFFE0B2),
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),

                                      // Email or Phone Label
                                      Text(
                                        'EMAIL OR PHONE',
                                        style: GoogleFonts.epilogue(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Email Field
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType: TextInputType.emailAddress,
                                        style: GoogleFonts.epilogue(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        cursorColor: const Color(0xFF2EAA4D),
                                        decoration: InputDecoration(
                                          hintText: 'Enter your credentials',
                                          hintStyle: GoogleFonts.epilogue(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            fontSize: 14,
                                          ),
                                          filled: true,
                                          fillColor: Colors.black.withValues(alpha: 0.22),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 16,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.22),
                                              width: 1.0,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF2EAA4D),
                                              width: 1.5,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Colors.redAccent,
                                              width: 1.2,
                                            ),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Colors.redAccent,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your email or phone';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 18),

                                      // Password Label Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'PASSWORD',
                                            style: GoogleFonts.epilogue(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.8,
                                              color: Colors.white.withValues(alpha: 0.85),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => const ForgotPasswordScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              'Forgot password?',
                                              style: GoogleFonts.epilogue(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF81C784),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // Password Field
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        style: GoogleFonts.epilogue(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: _obscurePassword ? 2.0 : 0.0,
                                        ),
                                        cursorColor: const Color(0xFF2EAA4D),
                                        decoration: InputDecoration(
                                          hintText: '••••••••',
                                          hintStyle: GoogleFonts.epilogue(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            fontSize: 14,
                                            letterSpacing: 2.0,
                                          ),
                                          filled: true,
                                          fillColor: Colors.black.withValues(alpha: 0.22),
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 16,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: BorderSide(
                                              color: Colors.white.withValues(alpha: 0.22),
                                              width: 1.0,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF2EAA4D),
                                              width: 1.5,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Colors.redAccent,
                                              width: 1.2,
                                            ),
                                          ),
                                          focusedErrorBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            borderSide: const BorderSide(
                                              color: Colors.redAccent,
                                              width: 1.5,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 26),

                                      // Login Button in Epilogue Font
                                      SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF1B6A2D),
                                            elevation: 4,
                                            shadowColor: Colors.black.withValues(alpha: 0.35),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 22,
                                                  width: 22,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.2,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Login',
                                                      style: GoogleFonts.epilogue(
                                                        color: Colors.white,
                                                        fontSize: 16.5,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    const Icon(
                                                      Icons.arrow_forward_rounded,
                                                      color: Colors.white,
                                                      size: 19,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),

                                      const SizedBox(height: 22),

                                      // Footer: New to the ecosystem? Create account in Epilogue Font
                                      Center(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const RegistrationPage(),
                                              ),
                                            );
                                          },
                                          child: RichText(
                                            text: TextSpan(
                                              style: GoogleFonts.epilogue(
                                                fontSize: 13.5,
                                                color: Colors.white.withValues(alpha: 0.8),
                                              ),
                                              children: [
                                                const TextSpan(text: 'New to the ecosystem? '),
                                                TextSpan(
                                                  text: 'Create\naccount',
                                                  style: GoogleFonts.epilogue(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
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
    );
  }
}