import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A finite, entirely local intro; no network assets or repeating timers.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          Navigator.pushReplacementNamed(context, '/get-started');
        }
      });
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.duration = const Duration(milliseconds: 150);
      }
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(double start, double end) => Curves.easeOutCubic.transform(
    ((_controller.value - start) / (end - start)).clamp(0.0, 1.0),
  );

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFF0F1B0D),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1B0D),
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final reveal = reducedMotion ? 1.0 : _phase(0, 0.55);
            final logo = reducedMotion ? 1.0 : _phase(0.12, 0.58);
            final words = reducedMotion ? 1.0 : _phase(0.35, 0.7);
            return Stack(
              fit: StackFit.expand,
              children: [
                Transform.scale(
                  scale: reducedMotion ? 1 : 1.1 - reveal * 0.1,
                  child: Image.asset(
                    'assets/images/login-bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
                ColoredBox(
                  color: const Color(0xFF07180E).withValues(alpha: 0.88),
                ),
                Center(
                  child: Opacity(
                    opacity: reveal,
                    child: Container(
                      width: 380,
                      height: 380,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [Color(0x554F9C53), Color(0x004F9C53)],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              for (var i = 0; i < 6; i++)
                                Builder(
                                  builder: (context) {
                                    final progress = reducedMotion
                                        ? 1.0
                                        : _phase(
                                            0.08 + i * 0.045,
                                            0.48 + i * 0.045,
                                          );
                                    final angle = i * math.pi / 3 - math.pi / 2;
                                    final radius = 116.0 + (1 - progress) * 22;
                                    return Transform.translate(
                                      offset: Offset(
                                        math.cos(angle) * radius,
                                        math.sin(angle) * radius,
                                      ),
                                      child: Opacity(
                                        opacity: progress * 0.65,
                                        child: Transform.rotate(
                                          angle: reducedMotion
                                              ? 0
                                              : (1 - progress) * 0.5,
                                          child: Icon(
                                            [
                                              Icons.eco_outlined,
                                              Icons.grass_rounded,
                                              Icons.spa_outlined,
                                            ][i % 3],
                                            color: const Color(0xFFBADA9B),
                                            size: i.isEven ? 30 : 23,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              Transform.scale(
                                scale: 0.78 + logo * 0.22,
                                child: Opacity(
                                  opacity: logo,
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.07,
                                      ),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFBADA9B,
                                        ).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 112,
                                      height: 112,
                                      semanticLabel: 'Visaia logo',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: words,
                          child: Transform.translate(
                            offset: Offset(0, (1 - words) * 16),
                            child: const Column(
                              children: [
                                Text(
                                  'VISAIA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 7,
                                  ),
                                ),
                                SizedBox(height: 14),
                                Text(
                                  'ROOTED IN CARE. GROWN WITH INTELLIGENCE.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFFBADA9B),
                                    fontSize: 9,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
