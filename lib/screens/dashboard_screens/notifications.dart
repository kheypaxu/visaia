import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/threat_details.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/services/auth_cache_service.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  // --- Brand Palette ---
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);
  static const Color background = Color(0xFFF3F5EE);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E5DC);

  static const Color dangerRed = Color(0xFFBA1A1A);
  static const Color dangerBg = Color(0xFFFFEBEE);
  static const Color amber = Color(0xFFB8860B);
  static const Color amberBg = Color(0xFFFFF3E0);
  static const Color safeBg = Color(0xFFE8F5E9);

  String _selectedFilter = 'All';

  final List<Map<String, dynamic>> _filters = const [
    {'label': 'All', 'icon': Icons.apps_rounded},
    {'label': 'Critical', 'icon': Icons.warning_amber_rounded},
    {'label': 'Outbreak', 'icon': Icons.bug_report_rounded},
    {'label': 'Advisory', 'icon': Icons.agriculture_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final String? currentUserId =
        FirebaseAuth.instance.currentUser?.uid ??
        AuthCacheService().cachedUid;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Text(
            'Please log in to view alerts.',
            style: GoogleFonts.manrope(color: textGray, fontSize: 15),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildFilterChips()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            _buildAlertsStream(currentUserId),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // --- HEADER ---
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: surface,
              padding: const EdgeInsets.all(10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.arrow_back, color: darkGreen),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 24),
          Text(
            'Alerts & Intel',
            style: GoogleFonts.epilogue(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: darkGreen,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Real-time agricultural intelligence and actionable\nnotifications for your managed zones.',
            style: GoogleFonts.manrope(fontSize: 14, color: textGray, height: 1.6),
          ),
        ],
      ),
    );
  }

  // --- FILTER CHIPS ---
  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final bool selected = _selectedFilter == filter['label'];
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter['label'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? darkGreen : surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: selected ? darkGreen : border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter['icon'] as IconData,
                    size: 16,
                    color: selected ? Colors.white : textGray,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    filter['label'] as String,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : textGray,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- FIRESTORE STREAM ---
  Widget _buildAlertsStream(String currentUserId) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        // No .orderBy() here on purpose — avoids needing a composite index.
        // Sorting is done client-side below.
        stream: FirebaseFirestore.instance
            .collection('alerts')
            .where('farmerId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator(color: darkGreen)),
            );
          }

          if (snapshot.hasError) {
            return _buildMessageState(
              icon: Icons.error_outline,
              iconColor: dangerRed,
              iconBg: dangerBg,
              title: 'Something went wrong',
              subtitle: '${snapshot.error}',
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildMessageState(
              icon: Icons.notifications_none_rounded,
              iconColor: darkGreen,
              iconBg: safeBg,
              title: 'No alerts yet',
              subtitle: 'When pests are detected near your farm,\nyou\'ll see them here.',
            );
          }

          final alerts = snapshot.data!.docs;
          alerts.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

          final filtered = alerts.where((doc) {
            if (_selectedFilter == 'All') return true;
            final data = doc.data() as Map<String, dynamic>;
            final risk = (data['risk'] ?? 'Moderate').toString().toLowerCase();
            switch (_selectedFilter) {
              case 'Critical':
                return risk == 'high';
              case 'Outbreak':
                return risk == 'moderate';
              case 'Advisory':
                return risk == 'low';
              default:
                return true;
            }
          }).toList();

          final unreadCount = alerts
              .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'unread')
              .length;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unreadCount > 0) _buildUnreadBanner(unreadCount),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _buildMessageState(
                      icon: Icons.filter_alt_off_outlined,
                      iconColor: textGray,
                      iconBg: border,
                      title: 'No alerts in this category',
                      subtitle: 'Try a different filter above.',
                    ),
                  )
                else
                  ...filtered.map((doc) => _buildAlertCard(context, doc)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnreadBanner(int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: darkGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count new alert${count > 1 ? 's' : ''} need your attention',
              style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w700, color: darkGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w700, color: headingBlack),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 13.5, color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
    );
  }

  // --- CARD BUILDER (maps Firestore doc -> styled card) ---
  Widget _buildAlertCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    String timeString = '';
    if (data['createdAt'] != null) {
      final date = (data['createdAt'] as Timestamp).toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        timeString = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeString = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        timeString = '${diff.inMinutes}m ago';
      } else {
        timeString = 'Just now';
      }
    }

    String category;
    IconData alertIcon;
    Color accentColor;
    Color accentBg;

    final risk = (data['risk'] ?? 'Moderate').toString().toLowerCase();
    if (risk == 'high') {
      category = 'CRITICAL THREAT';
      alertIcon = Icons.warning_amber_rounded;
      accentColor = dangerRed;
      accentBg = dangerBg;
    } else if (risk == 'moderate') {
      category = 'NEARBY OUTBREAK';
      alertIcon = Icons.bug_report_rounded;
      accentColor = amber;
      accentBg = amberBg;
    } else {
      category = 'ADVISORY';
      alertIcon = Icons.agriculture_rounded;
      accentColor = darkGreen;
      accentBg = safeBg;
    }

    final bool isSpreadRisk = data['distanceKm'] != null;

    return AlertCard(
      alertId: doc.id,
      category: category,
      title: data['title'] ?? 'Pest Alert',
      description: data['message'] ?? 'No additional details',
      time: timeString,
      icon: alertIcon,
      accentColor: accentColor,
      accentBg: accentBg,
      isNew: data['status'] == 'unread',
      isSpreadRisk: isSpreadRisk,
      onTap: () async {
        await doc.reference.update({'status': 'read'});
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ThreatDetailsScreen(alertId: doc.id)),
          );
        }
      },
    );
  }
}

// --- ALERT CARD COMPONENT ---
class AlertCard extends StatelessWidget {
  final String alertId;
  final String category;
  final String title;
  final String description;
  final String time;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final bool isNew;
  final bool isSpreadRisk;
  final VoidCallback onTap;

  const AlertCard({
    super.key,
    required this.alertId,
    required this.category,
    required this.title,
    required this.description,
    required this.time,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    this.isNew = false,
    this.isSpreadRisk = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: accentBg, borderRadius: BorderRadius.circular(14)),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category,
                                  style: GoogleFonts.manrope(
                                    color: accentColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              if (isNew)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                ),
                              Text(time, style: GoogleFonts.manrope(fontSize: 11, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            style: GoogleFonts.manrope(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1C18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(fontSize: 13.5, color: const Color(0xFF43483E), height: 1.5),
                ),
                if (isSpreadRisk) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to view spread risk map',
                        style: GoogleFonts.manrope(fontSize: 11.5, fontWeight: FontWeight.w700, color: accentColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}