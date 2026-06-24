import 'package:flutter/material.dart';

class FieldScoutingScreen extends StatelessWidget {
  const FieldScoutingScreen({super.key});

  // Common Constants
  static const Color primaryGreen = Color(0xFF114D32);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardBgColor = Colors.white;
  static const Color textDark = Color(0xFF212529);
  static const Color textMuted = Color(0xFF6C757D);
  static const Color lightGreenBg = Color(0xFFE8F0EC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {  Navigator.pop(context); },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How to Perform Field Scouting',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'FAW Monitoring Guide',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Why Scout Section
            _buildWhyScoutCard(),
            const SizedBox(height: 24),

            // Section Header
            const Center(
              child: Text(
                'Step-by-Step Guide',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Timeline Steps
            _buildStepBadge(1),
            _buildStepCard(
              icon: Icons.alt_route,
              title: 'Walk Through the Field',
              description: 'Move through the field in a zigzag or W pattern to cover the whole area comprehensively.',
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: CustomPaint(
                  painter: ZigZagPainter(),
                ),
              ),
            ),

            _buildStepBadge(2),
            _buildStepCard(
              icon: Icons.location_on,
              title: 'Stop at 5 Inspection Points',
              description: 'Stop at five different locations in the field. These will become your inspection stations.',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) => _buildStationCircle(index + 1)),
              ),
            ),

            _buildStepBadge(3),
            _buildStepCard(
              icon: Icons.search,
              title: 'Inspect 10 Plants',
              description: 'At each station, inspect at least 10 plants carefully. Look specifically for:',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: (constraints.maxWidth / 2) / 48,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildGridChip(Icons.eco_outlined, 'Leaf damage'),
                      _buildGridChip(Icons.blur_circular, 'Holes'),
                      _buildGridChip(Icons.grid_on, 'Frass'),
                      _buildGridChip(Icons.bug_report_outlined, 'Visible pests'),
                    ],
                  );
                },
              ),
            ),

            _buildStepBadge(4),
            _buildStepCard(
              icon: Icons.assignment,
              title: 'Record Damage',
              description: 'Count how many plants show FAW damage. Mark if damage is present.',
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCounterMetric('10', 'INSPECTED', textDark),
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.shade300),
                    Expanded(
                      child: _buildCounterMetric('2', 'DAMAGED', Colors.red.shade700),
                    ),
                  ],
                ),
              ),
            ),

            _buildStepBadge(5),
            _buildStepCard(
              icon: Icons.pest_control,
              title: 'Count Pest Stages',
              description: 'Record the number of different pest life stages observed.',
              child: Column(
                children: [
                  _buildPillRow(Icons.opacity, 'Egg masses'),
                  const SizedBox(height: 8),
                  _buildPillRow(Icons.bug_report_outlined, 'Larvae'),
                  const SizedBox(height: 8),
                  _buildPillRow(Icons.layers, 'Pupae'),
                ],
              ),
            ),

            _buildStepBadge(6),
            _buildStepCard(
              icon: Icons.camera_alt,
              title: 'Take Photo if Needed',
              description: 'Take a photo if you see unusual damage or insects for documentation and later verification.',
            ),

            _buildStepBadge(7),
            _buildStepCard(
              icon: Icons.cloud_upload,
              title: 'Submit Weekly Report',
              description: 'After checking all 5 stations, save your report in the app to track field history.',
            ),

            const SizedBox(height: 16),

            // Example Scouting Pattern Section
            _buildPatternCard(),
            const SizedBox(height: 24),

            // Pro Tips Section
            _buildProTipsCard(),
            const SizedBox(height: 32),

            // Bottom CTA Button
            ElevatedButton(
              onPressed: () {  Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Got It',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // UI Builder Helper Methods

  Widget _buildWhyScoutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreenBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco, color: primaryGreen, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why Scout?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryGreen,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Field scouting helps detect Fall Armyworm early by checking different parts of the field every week. Consistent monitoring is key to preventing crop loss.',
                  style: TextStyle(fontSize: 14, color: textDark, height: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStepBadge(int stepNumber) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 16, bottom: 8),
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: primaryGreen,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$stepNumber',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard({
    required IconData icon,
    required String title,
    required String description,
    Widget? child,
  }) {
    return Card(
      color: cardBgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryGreen, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: textMuted, height: 1.4),
            ),
            if (child != null) ...[
              const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStationCircle(int index) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Center(
        child: Text(
          '$index',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildGridChip(IconData icon, String label) {
    Color itemColor = textDark;
    if (label == 'Leaf damage') itemColor = const Color(0xFF8B6508);
    if (label == 'Holes') itemColor = const Color(0xFF8B6508);
    if (label == 'Visible pests') itemColor = const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: itemColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13, 
                color: textDark, 
                fontWeight: FontWeight.w600
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillRow(IconData icon, String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: textDark, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterMetric(String value, String label, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildPatternCard() {
  return Card(
    color: const Color(0xFFF1F3F5),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Example Scouting Pattern',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDark),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/zigzag.png',
              height: 160,
              width: double.infinity,
              fit: BoxFit.fill, // Stretches the image to perfectly fill the box dimensions completely
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 160,
                  color: Colors.grey.shade300,
                  alignment: Alignment.center,
                  child: const Text(
                    'Missing assets/images/zigzag.png',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Zigzag pattern covering distinct areas of the plot.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildProTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2EE),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryGreen.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: primaryGreen, size: 22),
              SizedBox(width: 8),
              Text(
                'Pro Tips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTipRow('Inspect early morning if possible when pests are most active.'),
          _buildTipRow('Check under leaves carefully; egg masses are often hidden there.'),
          _buildTipRow('Look deep inside plant whorls where larvae prefer to feed.'),
          _buildTipRow('Record findings every week for consistent data.', isLast: true),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, color: primaryGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: textDark, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class ZigZagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade500
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.lineTo(size.width * 0.3, size.height * 0.3);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    path.lineTo(size.width * 0.7, size.height * 0.3);
    path.lineTo(size.width * 0.9, size.height * 0.7);

    double dashWidth = 5, dashSpace = 5, distance = 0;
    for (final unresolvedPathMetric in path.computeMetrics()) {
      while (distance < unresolvedPathMetric.length) {
        canvas.drawPath(
          unresolvedPathMetric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.yellowAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final points = [
      Offset(size.width * 0.15, size.height * 0.2),
      Offset(size.width * 0.25, size.height * 0.8),
      Offset(size.width * 0.48, size.height * 0.45),
      Offset(size.width * 0.72, size.height * 0.85),
      Offset(size.width * 0.82, size.height * 0.2),
    ];

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    for (int i = 0; i < points.length; i++) {
      final circlePaint = Paint()..color = Colors.white;
      canvas.drawCircle(points[i], 12, circlePaint);
      
      final borderPaint = Paint()
        ..color = const Color(0xFF114D32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(points[i], 12, borderPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(color: Color(0xFF114D32), fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, points[i] - Offset(textPainter.width / 2, textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}