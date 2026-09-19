import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:visaia/screens/auth/veri_form.dart';
import 'package:visaia/services/auth_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  // =========================================================================
  // ADJUSTABLE LAYOUT & SPACING SETTINGS
  // Modify these values to adjust the position and size of screen components
  // =========================================================================
  static const double logoSize = 85.0; // Size (width & height) of the logo
  static const double spacingAboveContainer = 50.0; // Gap above the registration container card
  static const double topSpacingBelowBackButton = 8.0; // Gap between back button and logo
  static const double spacingBelowLogo = 10.0; // Gap between logo and brand text
  static const double spacingBelowBrand = 4.0; // Gap between brand text and tagline
  // =========================================================================

  // Form key for validation
  final _formKey = GlobalKey<FormState>();

  // Text editing controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Checkbox state for terms and conditions
  bool _agreeToTerms = false;

  // Password visibility state
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You must agree to the terms and conditions.',
            style: GoogleFonts.epilogue(),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Account created. Please complete verification.',
                  style: GoogleFonts.epilogue(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A5C30),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Navigate to verification form
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const VerificationFormScreen(),
          ),
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

                          // Adjustable Spacing above the registration container card
                          const SizedBox(height: spacingAboveContainer),

                          // Glassmorphic Registration Card
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
                                      // "Create Account" in Epilogue Font
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.epilogue(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Create '),
                                            TextSpan(
                                              text: 'Account',
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
                                        'Join the digital farm community today',
                                        style: GoogleFonts.epilogue(
                                          fontSize: 13.5,
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                      const SizedBox(height: 22),

                                      // Email Label
                                      Text(
                                        'EMAIL ADDRESS',
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
                                          hintText: 'e.g., farmer@domain.com',
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
                                            return 'Please enter your email';
                                          }
                                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                                            return 'Please enter a valid email address';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 18),

                                      // Password Label
                                      Text(
                                        'PASSWORD',
                                        style: GoogleFonts.epilogue(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
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
                                            return 'Please enter a password';
                                          }
                                          if (value.length < 6) {
                                            return 'Password must be at least 6 characters long';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 18),

                                      // Confirm Password Label
                                      Text(
                                        'CONFIRM PASSWORD',
                                        style: GoogleFonts.epilogue(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Confirm Password Field
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        style: GoogleFonts.epilogue(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: _obscureConfirmPassword ? 2.0 : 0.0,
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
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_outlined
                                                  : Icons.visibility_off_outlined,
                                              color: Colors.white.withValues(alpha: 0.6),
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword = !_obscureConfirmPassword;
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
                                            return 'Please confirm your password';
                                          }
                                          if (value != _passwordController.text) {
                                            return 'Passwords do not match';
                                          }
                                          return null;
                                        },
                                      ),

                                      const SizedBox(height: 16),

                                      // Terms and Conditions Checkbox
                                      Row(
                                        children: [
                                          Transform.scale(
                                            scale: 0.95,
                                            child: Checkbox(
                                              value: _agreeToTerms,
                                              onChanged: (bool? value) {
                                                setState(() {
                                                  _agreeToTerms = value ?? false;
                                                });
                                              },
                                              activeColor: const Color(0xFF2EAA4D),
                                              checkColor: Colors.white,
                                              side: BorderSide(
                                                color: Colors.white.withValues(alpha: 0.4),
                                                width: 1.5,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              'I agree to the Terms of Service and Privacy Policy.',
                                              style: GoogleFonts.epilogue(
                                                fontSize: 12.5,
                                                color: Colors.white.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 22),

                                      // Register Button in Epilogue Font
                                      SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _register,
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
                                                      'Register',
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

                                      // Footer: Already have an account? Login
                                      Center(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => const LoginPage(),
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
                                                const TextSpan(text: 'Already have an account? '),
                                                TextSpan(
                                                  text: 'Login',
                                                  style: GoogleFonts.epilogue(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    decoration: TextDecoration.underline,
                                                    decorationColor: Colors.white.withValues(alpha: 0.6),
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