import 'package:flutter/material.dart';

class VisaiaDashboard extends StatefulWidget {
  const VisaiaDashboard({super.key});

  @override
  State<VisaiaDashboard> createState() => _VisaiaDashboardState();
}

class _VisaiaDashboardState extends State<VisaiaDashboard> {

  final List<PestCardData> _pestData = [
    PestCardData(
        icon: Icons.bug_report,
        name: 'Fall Armyworm',
        location: 'Sector 7B',                                                        
        severity: 'High Severity',
        bgColor: Colors.red.shade100,
        iconColor: Colors.red.shade700),
    PestCardData(
        icon: Icons.bug_report_outlined,
        name: 'Corn Borer',
        location: 'North Plot',
        severity: 'Moderate Severity',
        bgColor: Colors.pink.shade50,
        iconColor: Colors.pink.shade400),
    PestCardData(
        icon: Icons.grass,
        name: 'Aphids',
        location: 'South Greenhouse',
        severity: 'Low Severity',
        bgColor: const Color(0xFF7E7D2E).withValues(alpha: 0.2),
        iconColor: const Color(0xFF7E7D2E)),
    PestCardData(
        icon: Icons.camera,
        name: 'Spider Mites',
        location: 'East Field',
        severity: 'Monitoring',
        bgColor: const Color(0xFF8D7F5C).withOpacity(0.2),
        iconColor: const Color(0xFF8D7F5C)),
    PestCardData(
        icon: Icons.flight,
        name: 'Locusts',
        location: 'Regional Warning',
        severity: 'Alert Only',
        bgColor: Colors.grey.shade200,
        iconColor: Colors.grey.shade600),
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Stats Cards Row
              const Row(
                children: [
                  Expanded(
                      child: StatCard(
                          title: 'NET INCOME',
                          value: '\$12,450',
                          icon: Icons.account_balance_wallet_outlined,
                          isLarge: true)),
                  SizedBox(width: 16),
                  Expanded(
                      child: StatCard(
                          title: 'TOTAL YIELD',
                          value: '2,840 kg',
                          icon: Icons.agriculture)),
                ],
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(
                      child: StatCard(
                          title: 'ACTIVE CYCLE',
                          value: '14 days',
                          icon: Icons.show_chart)),
                  SizedBox(width: 16),
                  Expanded(
                      child: StatCard(
                          title: 'FIELD COUNT', value: '42', icon: Icons.crop)),
                ],
              ),

              const SizedBox(height: 32),

              // Active Pests Section
              _buildSectionHeader(
                  context, 'Active Pests', 'Critical monitoring required'),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pestData.length,
                itemBuilder: (context, index) {
                  final pest = _pestData[index];
                  return PestListItem(pest: pest);
                },
              ),

              const SizedBox(height: 32),

              // Recent Activity Section
              _buildSectionHeader(context, 'Recent Activity', ''),
              const SizedBox(height: 12),
              ActivityListItem(
                icon: Icons.water_drop,
                title: 'Irrigation Cycle Completed',
                subtitle: 'Sector 7B • Optimal Soil Health',
                time: '2H AGO',
                iconColor: Colors.lightGreen,
              ),
              const SizedBox(height: 8),
              ActivityListItem(
                icon: Icons.grass,
                title: 'Fertilizer Applied',
                subtitle: 'North Plot • Nitrogen Mix',
                time: '5H AGO',
                iconColor: const Color(0xFFA5926B),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        if (subtitle.isNotEmpty)
          Text(subtitle,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool isLarge;

  const StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor;
    Color textColor;
    if (isLarge) {
      cardColor = const Color(0xFF0C503C); // Dark green
      textColor = Colors.white;
    } else if (title.contains('FIELD')) {
      cardColor = const Color(0xFFF7E9AA); // Yellowish
      textColor = Colors.black;
    } else {
      cardColor = const Color(0xFFA6C9A2); // Light green
      textColor = Colors.black;
    }

    return AspectRatio(
      aspectRatio: 1.1, // Control the card shape
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: textColor.withOpacity(isLarge ? 0.7 : 0.5)),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
            Row(
              children: [
                Text(
                  value.contains(' ') ? value.split(' ')[0] : value,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                ),
                if (value.contains(' ')) const SizedBox(width: 4),
                if (value.contains(' '))
                  Text(
                    value.split(' ')[1],
                    style: TextStyle(
                        color: textColor.withOpacity(0.6), fontSize: 12),
                  )
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'VIEW DETAILS',
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PestCardData {
  final IconData icon;
  final String name;
  final String location;
  final String severity;
  final Color bgColor;
  final Color iconColor;

  PestCardData({
    required this.icon,
    required this.name,
    required this.location,
    required this.severity,
    required this.bgColor,
    required this.iconColor,
  });
}

class PestListItem extends StatelessWidget {
  final PestCardData pest;

  const PestListItem({required this.pest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: pest.bgColor, shape: BoxShape.circle),
          child: Icon(pest.icon, color: pest.iconColor),
        ),
        title: Text(pest.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('${pest.location} • ${pest.severity}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100, // Explicit height as in design
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF7F8F7), // Match Scaffold
              child: Icon(icon, color: const Color(0xFF0C503C)),
            ),
            const SizedBox(height: 12),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class ActivityListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color iconColor;

  const ActivityListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Text(time,
            style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 10,
                letterSpacing: 0.5)),
      ),
    );
  }
}