import 'package:flutter/material.dart';

class CycleDetailsScreen extends StatelessWidget {
  final String cycleId;

  const CycleDetailsScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const Icon(Icons.arrow_back, color: Color(0xFF1A1C1E)),
        title: const Text(
          'Cycle Detail',
          style: TextStyle(
            color: Color(0xFF1B5E37),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            _buildHeader(),
            const SizedBox(height: 24),
            _buildGrowthProgress(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildRiskAlert(),
            const SizedBox(height: 20),
            _buildMapPreview(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Soybean\nSummer',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900, // Maximum boldness
                color: Color(0xFF1A1C1E),
                height: 1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFBCF491),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1B5E37),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E37),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
            SizedBox(width: 4),
            Text(
              'Field A • Soybeans',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGrowthProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Growth Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Day 45 of 127', style: TextStyle(color: Colors.black87)),
              const Text(
                '82 days remaining',
                style: TextStyle(color: Color(0xFF1B5E37), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: 45 / 127,
              minHeight: 10,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B5E37)),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DateInfo(label: 'PLANTED', date: 'June 10'),
              _DateInfo(label: 'EXPECTED HARVEST', date: 'Oct 12', alignEnd: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildActionButton(
          icon: Icons.eco_outlined,
          title: 'Monitoring',
          subtitle: 'Weekly logs and trap records',
          color: const Color(0xFF1B5E37),
          isDark: true,
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.shopping_basket_outlined,
          title: 'Harvest',
          subtitle: 'Record yield and losses',
          color: Colors.white,
          isDark: false,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lightbulb_outline, size: 20,
              color: Color.fromARGB(255, 240, 192, 2),
          ),
              SizedBox(width: 8),
              Text('Recommendations: Suggested actions', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha:0.1) : const Color(0xFFF1F3F1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? Colors.white : const Color(0xFF1B5E37)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B5E37),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskAlert() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'High Risk Detected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Immediate attention required for Plot 4B. Review recent scouting data.',
                  style: TextStyle(color: const Color(0xFF991B1B).withValues(alpha:0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://placeholder_field_aerial_view.jpg'), // Replace with local asset
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          // Simulated Polygon Highlight
          Center(
            child: CustomPaint(
              size: const Size(200, 120),
              painter: FieldPolygonPainter(),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.map_outlined, size: 16),
                  SizedBox(width: 4),
                  Text('Map View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(
            icon: Icons.assignment_outlined,
            title: 'Monitoring Log added',
            time: '2 hours ago',
            iconColor: const Color(0xFF1B5E37),
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.bug_report_outlined,
            title: 'Pest Uploaded',
            time: '5 hours ago',
            iconColor: const Color(0xFFDC2626),
          ),
          const Divider(height: 24),
          _buildActivityItem(
            icon: Icons.track_changes_outlined,
            title: 'Trap Checked',
            time: 'Yesterday',
            iconColor: const Color(0xFF1B5E37),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String time,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _DateInfo extends StatelessWidget {
  final String label;
  final String date;
  final bool alignEnd;

  const _DateInfo({required this.label, required this.date, this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class FieldPolygonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFACC15).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.8)
      ..lineTo(size.width * 0.1, size.height * 0.3)
      ..lineTo(size.width * 0.5, size.width * 0.1)
      ..lineTo(size.width * 0.9, size.height * 0.7)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
    
    // Draw central dot
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.4), 4, Paint()..color = Colors.orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}