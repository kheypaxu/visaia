import 'package:flutter/material.dart';

/// Only the explanation is pending; detection and treatment stay usable.
class ExplanationLoading extends StatefulWidget {
  const ExplanationLoading({super.key});

  @override
  State<ExplanationLoading> createState() => _ExplanationLoadingState();
}

class _ExplanationLoadingState extends State<ExplanationLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 1;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label:
        'Preparing your image explanation. Detection and treatment are ready.',
    child: ExcludeSemantics(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeTransition(
              opacity: _pulse.drive(Tween<double>(begin: 0.8, end: 1)),
              child: const Text(
                'Preparing your image explanation…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A5C30),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your detection and treatment are ready. The explanation will appear here when it is complete.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF3D5247),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
