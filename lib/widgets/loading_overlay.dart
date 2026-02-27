import 'dart:async';
import 'package:flutter/material.dart';

class AnalysisLoadingOverlay extends StatefulWidget {
  const AnalysisLoadingOverlay({super.key});

  @override
  State<AnalysisLoadingOverlay> createState() => _AnalysisLoadingOverlayState();
}

class _AnalysisLoadingOverlayState extends State<AnalysisLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  int step = 0;

  // --- CHANGE: Reduced step duration to 1.5 seconds ---
  static const _stepDuration = Duration(milliseconds: 1500); 
  final List<String> _steps = [
    "Running MobileNet Model...",
    "Running YOLO Model...",
    "Generating AI Report..."
  ];
  final List<IconData> _icons = [
    Icons.tune,
    Icons.bug_report,
    Icons.analytics,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _timer = Timer.periodic(_stepDuration, (timer) {
      if (mounted) {
        if (step < _steps.length - 1) {
          setState(() {
            step++;
          });
        } else {
          // We've reached the last step, cancel the timer.
          timer.cancel();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _controller,
              child: Icon(
                _icons[step],
                size: 80,
                color: const Color(0xFF8DBA60),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _steps[step],
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              color: Color(0xFF8DBA60),
              strokeWidth: 4,
            )
          ],
        ),
      ),
    );
  }
}