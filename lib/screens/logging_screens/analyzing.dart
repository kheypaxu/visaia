import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/services/api_service.dart';
import 'package:visaia/screens/logging_screens/ai_result.dart';
import 'package:geolocator/geolocator.dart';  // Add this
import 'package:geocoding/geocoding.dart';  

/// Full-screen cinematic loading overlay shown while the AI analyzes the image.
/// Push this as a transparent route over UploadPestScreen, then it will
/// automatically navigate to AIResultScreen on completion.
class AnalyzingScreen extends StatefulWidget {
  final File imageFile;
  final String userId;
  final String? sourceContext;
  final String? pestType;

  const AnalyzingScreen({
    super.key,
    required this.imageFile,
    required this.userId,
    this.sourceContext,
    this.pestType,
  });

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen>
    with TickerProviderStateMixin {
  // ── Colors ──────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF081A10);
  static const _green = Color(0xFF1A5C30);
  static const _accentGreen = Color(0xFF4DBD74);
  static const _dimGreen = Color(0xFF1E3A28);

  // ── Animators ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late AnimationController _dotCtrl;
  late AnimationController _fadeInCtrl;
  late AnimationController _ringCtrl;

  late Animation<double> _pulseAnim;
  late Animation<double> _scanAnim;
  late Animation<double> _fadeInAnim;
  late Animation<double> _ringAnim;

  // ── State ────────────────────────────────────────────────────────────────
  int _stepIndex = 0;
  int _dotCount = 1;
  bool _done = false;

  final List<_AnalysisStep> _steps = const [
    _AnalysisStep(
      icon: Icons.image_search_rounded,
      title: 'Reading image',
      description: 'Extracting visual features and pixel data…',
    ),
    _AnalysisStep(
      icon: Icons.biotech_rounded,
      title: 'Identifying species',
      description: 'Matching patterns against pest database…',
    ),
    _AnalysisStep(
      icon: Icons.analytics_rounded,
      title: 'Assessing severity',
      description: 'Evaluating infestation level and risk…',
    ),
    _AnalysisStep(
      icon: Icons.healing_rounded,
      title: 'Generating report',
      description: 'Preparing treatment recommendations…',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _fadeInCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _fadeInAnim =
        CurvedAnimation(parent: _fadeInCtrl, curve: Curves.easeOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.linear);

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.linear);

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _dotCount = (_dotCount % 3) + 1);
          _dotCtrl.forward(from: 0);
        }
      })
      ..forward();

    _startAnalysis();
    _stepTimer();
  }

  void _stepTimer() async {
    // Advance the visual step every ~1.4s (cosmetic only)
    for (int i = 1; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1450));
      if (!mounted || _done) return;
      setState(() => _stepIndex = i);
    }
  }

  Future<void> _startAnalysis() async {
    try {
      final result = await ApiService.sendImage(widget.imageFile);
      if (!mounted) return;
      setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      // Get current location
      final locationData = await _getCurrentLocation();
      
      // Ensure scientificName is not null
      final scientificName = result.scientificName.isNotEmpty 
          ? result.scientificName 
          : _getScientificNameForPest(result.pestName);
      
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => AIResultScreen(
            pestName: result.pestName,
            scientificName: scientificName,
            severity: _mapRiskToSeverity(result.riskLevel),
            confidencePercent: _calculateConfidence(result.boxes),
            detectionStage: result.lifeStage,
            cropAffected: result.cropAffected.isNotEmpty ? result.cropAffected : 'Maize',
            analysis: result.analysis,
            treatment: result.treatment,
            historicalContext: result.historicalContext.isNotEmpty 
                ? result.historicalContext 
                : 'AI analysis from uploaded image.',
            imageFile: widget.imageFile,
            annotatedImageUrl: result.annotatedImageUrl,
            userId: widget.userId,
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            areaName: locationData.areaName,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // back to upload screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Analysis failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // Helper method to map risk level to severity format
  String _mapRiskToSeverity(String riskLevel) {
    final risk = riskLevel.toLowerCase();
    if (risk == 'high' || risk == 'critical' || risk == 'severe') {
      return 'High';
    } else if (risk == 'medium' || risk == 'moderate') {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  // Helper method to get scientific name based on pest name
  String _getScientificNameForPest(String pestName) {
    final pestMap = {
      'Fall Armyworm': 'Spodoptera frugiperda',
      'African Armyworm': 'Spodoptera exempta',
      'Corn Earworm': 'Helicoverpa zea',
      'European Corn Borer': 'Ostrinia nubilalis',
      'Cotton Bollworm': 'Helicoverpa armigera',
      'Diamondback Moth': 'Plutella xylostella',
    };
    
    return pestMap[pestName] ?? 'Species unidentified';
  }

  // Add this method to get current location
  Future<LocationData> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return LocationData(latitude: 0.0, longitude: 0.0, areaName: 'Unknown');
      }
      
      // Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions denied');
          return LocationData(latitude: 0.0, longitude: 0.0, areaName: 'Unknown');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions permanently denied');
        return LocationData(latitude: 0.0, longitude: 0.0, areaName: 'Unknown');
      }
      
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Get area name from coordinates (reverse geocoding)
      String areaName = 'Unknown Area';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        // Replace the areaName fallback in _getCurrentLocation()
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          List<String> locationParts = [];
          
          if (place.subLocality?.isNotEmpty == true) locationParts.add(place.subLocality!);
          if (place.locality?.isNotEmpty == true) locationParts.add(place.locality!);
          if (place.administrativeArea?.isNotEmpty == true) locationParts.add(place.administrativeArea!);
          if (place.country?.isNotEmpty == true) locationParts.add(place.country!); // add country as last resort
          
          areaName = locationParts.isNotEmpty ? locationParts.join(', ') : 'Location ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } catch (e) {
        debugPrint('Reverse geocoding error: $e');
      }
      
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        areaName: areaName,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return LocationData(latitude: 0.0, longitude: 0.0, areaName: 'Unknown');
    }
  }

  int _calculateConfidence(List<BoundingBox> boxes) {
    if (boxes.isEmpty) return 85;
    double sum = boxes.fold(0.0, (s, b) => s + b.confidence);
    return (sum / boxes.length * 100).round();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _dotCtrl.dispose();
    _fadeInCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FadeTransition(
        opacity: _fadeInAnim,
        child: Stack(
          children: [
            _buildBackgroundOrbs(),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _buildTopBar(),
                  const Spacer(),
                  _buildCenterVisual(),
                  const SizedBox(height: 40),
                  _buildStepsList(),
                  const Spacer(),
                  _buildBottomHint(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundOrbs() {
    return Stack(
      children: [
        // Top-left orb
        Positioned(
          top: -80,
          left: -60,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: _pulseAnim.value,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _green.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Bottom-right orb
        Positioned(
          bottom: -100,
          right: -80,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Transform.scale(
              scale: 2.0 - _pulseAnim.value,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentGreen.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _dimGreen,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentGreen,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'AI Processing',
                  style: GoogleFonts.dmSans(
                    color: _accentGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'VisAIA',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withOpacity(0.3),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterVisual() {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating outer ring
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) => Transform.rotate(
              angle: _ringAnim.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(220, 220),
                painter: _DashedRingPainter(
                  color: _accentGreen.withOpacity(0.25),
                  strokeWidth: 1.2,
                  dashCount: 32,
                ),
              ),
            ),
          ),
          // Counter-rotating middle ring
          AnimatedBuilder(
            animation: _ringAnim,
            builder: (_, __) => Transform.rotate(
              angle: -_ringAnim.value * 2 * math.pi * 0.6,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _DashedRingPainter(
                  color: _accentGreen.withOpacity(0.4),
                  strokeWidth: 1.8,
                  dashCount: 20,
                ),
              ),
            ),
          ),
          // Image thumbnail with scan line
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.cover),
                  Container(
                      color: _bg.withOpacity(0.45)), // dark tint over image
                  // Scan line
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) {
                      final y = _scanAnim.value * 140;
                      return Positioned(
                        top: y - 1,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _accentGreen.withOpacity(0.9),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Center icon overlay
                  Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        _steps[_stepIndex].icon,
                        key: ValueKey(_stepIndex),
                        color: Colors.white.withOpacity(0.9),
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Pulse ring
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 155 * _pulseAnim.value,
              height: 155 * _pulseAnim.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _accentGreen.withOpacity(
                      0.15 * (2 - _pulseAnim.value)),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Column(
              key: ValueKey(_stepIndex),
              children: [
                Text(
                  _steps[_stepIndex].title,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _steps[_stepIndex].description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Step dots / progress
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_steps.length, (i) {
              final isActive = i == _stepIndex;
              final isDone = i < _stepIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: isActive ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isDone
                      ? _accentGreen.withOpacity(0.5)
                      : isActive
                          ? _accentGreen
                          : Colors.white.withOpacity(0.15),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHint() {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) => Text(
        'Analyzing${'.' * _dotCount}',
        style: GoogleFonts.dmSans(
          color: Colors.white.withOpacity(0.25),
          fontSize: 12,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────

class _AnalysisStep {
  final IconData icon;
  final String title;
  final String description;
  const _AnalysisStep(
      {required this.icon, required this.title, required this.description});
}

// ── Custom Painter ───────────────────────────────────────────────────────────

class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;
    final dashAngle = (2 * math.pi) / (dashCount * 2);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * 2 * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// Helper class for location data
class LocationData {
  final double latitude;
  final double longitude;
  final String areaName;
  
  LocationData({
    required this.latitude,
    required this.longitude,
    required this.areaName,
  });
}