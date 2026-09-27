import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/dashboard_screens/spread_risk_sheet.dart';
import 'package:visaia/screens/dashboard_screens/threat_details.dart';
import 'package:visaia/screens/report_history/report_details.dart';
import 'package:visaia/services/auth_cache_service.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  // --- Brand Palette ---
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color forestGreen = Color(0xFF1B4332);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color background = Color(0xFFF6F8F5);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textGray = Color(0xFF64748B);

  // Status colors
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color successEmerald = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color rejectRose = Color(0xFFE11D48);
  static const Color rejectBg = Color(0xFFFFF1F2);

  String _selectedFilter = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isMarkingAllRead = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final unreadDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'unread';
    }).toList();

    if (unreadDocs.isEmpty || _isMarkingAllRead) return;

    setState(() => _isMarkingAllRead = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in unreadDocs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.done_all_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Marked ${unreadDocs.length} alert(s) as read'),
              ],
            ),
            backgroundColor: darkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark alerts as read: $e'),
            backgroundColor: dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAllRead = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId =
        FirebaseAuth.instance.currentUser?.uid ??
        AuthCacheService().cachedUid;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: textGray),
              const SizedBox(height: 12),
              Text(
                'Please log in to view alerts.',
                style: GoogleFonts.inter(color: textDark, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alerts')
              .where('farmerId', isEqualTo: currentUserId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: darkGreen),
              );
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
            docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
              final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime(1970);
              return bTime.compareTo(aTime);
            });

            // Calculate category counts
            int unreadCount = 0;
            int criticalCount = 0;
            int outbreakCount = 0;
            int validatedCount = 0;
            int advisoryCount = 0;

            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'unread') unreadCount++;

              final type = (data['type'] ?? '').toString().toLowerCase();
              final risk = (data['risk'] ?? '').toString().toLowerCase();

              if (type.contains('validation_confirmed') || type.contains('validated') || type.contains('validation_rejected')) {
                validatedCount++;
              } else if (risk == 'high') {
                criticalCount++;
              } else if (risk == 'moderate' || data['distanceKm'] != null) {
                outbreakCount++;
              } else {
                advisoryCount++;
              }
            }

            // Filter docs
            final filteredDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = (data['type'] ?? '').toString().toLowerCase();
              final risk = (data['risk'] ?? '').toString().toLowerCase();
              final title = (data['title'] ?? '').toString().toLowerCase();
              final message = (data['message'] ?? '').toString().toLowerCase();
              final detection = (data['detection'] ?? '').toString().toLowerCase();
              final farm = (data['farmName'] ?? '').toString().toLowerCase();

              // Search query check
              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                final matches = title.contains(q) || message.contains(q) || detection.contains(q) || farm.contains(q);
                if (!matches) return false;
              }

              // Category filter check
              switch (_selectedFilter) {
                case 'Critical':
                  return risk == 'high' && !type.contains('validation');
                case 'Outbreak':
                  return (risk == 'moderate' || data['distanceKm'] != null) && !type.contains('validation');
                case 'Validated':
                  return type.contains('validation_confirmed') || type.contains('validated') || type.contains('validation_rejected');
                case 'Advisory':
                  return (risk == 'low' || risk.isEmpty) && data['distanceKm'] == null && !type.contains('validation');
                default:
                  return true;
              }
            }).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(
                    context: context,
                    totalCount: docs.length,
                    unreadCount: unreadCount,
                    onMarkAllRead: () => _markAllAsRead(docs),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchBar(),
                ),
                SliverToBoxAdapter(
                  child: _buildFilterChips(
                    total: docs.length,
                    critical: criticalCount,
                    outbreak: outbreakCount,
                    validated: validatedCount,
                    advisory: advisoryCount,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (filteredDocs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                      child: _buildEmptyState(docs.isEmpty),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = filteredDocs[index];
                          return _buildAlertCard(context, doc);
                        },
                        childCount: filteredDocs.length,
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

  // --- HEADER ---
  Widget _buildHeader({
    required BuildContext context,
    required int totalCount,
    required int unreadCount,
    required VoidCallback onMarkAllRead,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: surface,
                  padding: const EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: border, width: 1),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: darkGreen),
                onPressed: () => Navigator.pop(context),
              ),
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: _isMarkingAllRead ? null : onMarkAllRead,
                  icon: _isMarkingAllRead
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: darkGreen),
                        )
                      : const Icon(Icons.done_all_rounded, size: 16, color: darkGreen),
                  label: Text(
                    'Mark all as read',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: darkGreen,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: lightGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alerts & Intelligence',
                      style: GoogleFonts.epilogue(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: darkGreen,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time pest detections, validation notices & advisories.',
                      style: GoogleFonts.inter(fontSize: 13, color: textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Unread Banner / Stats Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: unreadCount > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: unreadCount > 0 ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  unreadCount > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                  size: 18,
                  color: unreadCount > 0 ? const Color(0xFFB45309) : textGray,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    unreadCount > 0
                        ? '$unreadCount unread notification${unreadCount > 1 ? 's' : ''} require your attention'
                        : 'All notifications are up to date ($totalCount total)',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: unreadCount > 0 ? const Color(0xFF92400E) : textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SEARCH BAR ---
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: GoogleFonts.inter(fontSize: 14, color: textDark),
          decoration: InputDecoration(
            hintText: 'Search alerts by pest, farm, or message...',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: textGray),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: textGray),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18, color: textGray),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // --- FILTER CHIPS ---
  Widget _buildFilterChips({
    required int total,
    required int critical,
    required int outbreak,
    required int validated,
    required int advisory,
  }) {
    final filters = [
      {'label': 'All', 'count': total, 'icon': Icons.all_inbox_rounded},
      {'label': 'Critical', 'count': critical, 'icon': Icons.warning_amber_rounded, 'color': dangerRed},
      {'label': 'Outbreak', 'count': outbreak, 'icon': Icons.bug_report_rounded, 'color': warningAmber},
      {'label': 'Validated', 'count': validated, 'icon': Icons.verified_outlined, 'color': successEmerald},
      {'label': 'Advisory', 'count': advisory, 'icon': Icons.info_outline_rounded, 'color': infoBlue},
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = filters[index];
          final label = item['label'] as String;
          final count = item['count'] as int;
          final icon = item['icon'] as IconData;
          final selected = _selectedFilter == label;

          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? darkGreen : surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? darkGreen : border,
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: darkGreen.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: selected ? Colors.white : (item['color'] as Color? ?? textGray),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Colors.white : textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : textGray,
                      ),
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

  // --- ALERT CARD BUILDER ---
  Widget _buildAlertCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final isUnread = data['status'] == 'unread';
    final alertId = doc.id;

    // Time string
    String timeString = '';
    if (data['createdAt'] != null) {
      final date = (data['createdAt'] as Timestamp).toDate();
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 7) {
        timeString = '${date.day}/${date.month}/${date.year}';
      } else if (diff.inDays > 0) {
        timeString = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeString = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        timeString = '${diff.inMinutes}m ago';
      } else {
        timeString = 'Just now';
      }
    }

    // Determine type styling
    final type = (data['type'] ?? '').toString().toLowerCase();
    final risk = (data['risk'] ?? 'Moderate').toString().toLowerCase();
    final double? distance = data['distanceKm'] is num ? (data['distanceKm'] as num).toDouble() : null;

    String category;
    IconData alertIcon;
    Color accentColor;
    Color accentBg;

    if (type.contains('validation_rejected')) {
      category = 'VALIDATION REJECTED';
      alertIcon = Icons.cancel_outlined;
      accentColor = rejectRose;
      accentBg = rejectBg;
    } else if (type.contains('validation_confirmed') || type.contains('validated')) {
      category = 'RCPC VALIDATED';
      alertIcon = Icons.verified_rounded;
      accentColor = successEmerald;
      accentBg = successBg;
    } else if (risk == 'high') {
      category = 'CRITICAL THREAT';
      alertIcon = Icons.warning_amber_rounded;
      accentColor = dangerRed;
      accentBg = dangerBg;
    } else if (risk == 'moderate' || distance != null) {
      category = 'NEARBY OUTBREAK';
      alertIcon = Icons.bug_report_rounded;
      accentColor = warningAmber;
      accentBg = warningBg;
    } else {
      category = 'ADVISORY';
      alertIcon = Icons.campaign_rounded;
      accentColor = infoBlue;
      accentBg = infoBg;
    }

    final String title = data['title'] ?? 'Pest Alert';
    final String message = data['message'] ?? 'No details provided';
    final String? crop = data['cropAffected'] ?? data['cropType'];
    final String? lifeStage = data['lifeStage'];
    final String? farmName = data['farmName'];
    final String? reportId = data['reportId']?.toString();
    final String? reportType = data['reportType']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnread ? accentColor.withValues(alpha: 0.5) : border,
          width: isUnread ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? accentColor.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: isUnread ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            if (isUnread) {
              await doc.reference.update({'status': 'read'});
            }
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ThreatDetailsScreen(alertId: alertId)),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Badge + Unread Indicator + Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(alertIcon, size: 13, color: accentColor),
                          const SizedBox(width: 5),
                          Text(
                            category,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (isUnread) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: dangerRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'NEW',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: textGray),
                        const SizedBox(width: 4),
                        Text(
                          timeString,
                          style: GoogleFonts.inter(fontSize: 11.5, color: textGray, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15.5,
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                    color: textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Message snippet
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textGray,
                    height: 1.45,
                  ),
                ),

                // Metadata Chips Row (Pest / Crop / Distance / Farm)
                if (crop != null || lifeStage != null || distance != null || farmName != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (crop != null)
                        _buildMetaTag(Icons.eco_outlined, crop, const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
                      if (lifeStage != null)
                        _buildMetaTag(Icons.scatter_plot_outlined, lifeStage, const Color(0xFF6B21A8), const Color(0xFFF3E8FF)),
                      if (distance != null)
                        _buildMetaTag(Icons.near_me_outlined, '${distance.toStringAsFixed(1)} km away', warningAmber, warningBg),
                      if (farmName != null && farmName.isNotEmpty)
                        _buildMetaTag(Icons.storefront_outlined, farmName, darkGreen, lightGreen),
                    ],
                  ),
                ],

                // Action Footer Buttons
                if (reportId != null || distance != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (distance != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            showSpreadRiskSheet(
                              context,
                              pestName: data['detection'] ?? title,
                              riskLevel: risk,
                              distanceKm: distance,
                              cropAffected: crop,
                              lifeStage: lifeStage,
                            );
                          },
                          icon: const Icon(Icons.map_outlined, size: 14),
                          label: const Text('Spread Map'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: warningAmber,
                            side: const BorderSide(color: Color(0xFFFDE68A)),
                            backgroundColor: warningBg,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (distance != null && reportId != null) const SizedBox(width: 8),
                      if (reportId != null)
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (isUnread) {
                              await doc.reference.update({'status': 'read'});
                            }
                            if (!context.mounted) return;
                            _openReportDetails(context, reportId, reportType);
                          },
                          icon: const Icon(Icons.description_outlined, size: 14),
                          label: const Text('View Report'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
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

  Widget _buildMetaTag(IconData icon, String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openReportDetails(BuildContext context, String reportId, String? reportType) async {
    try {
      if (reportType == 'clustered') {
        final snap = await FirebaseFirestore.instance.collection('clustered_reports').doc(reportId).get();
        if (snap.exists && context.mounted) {
          final rData = snap.data()!;
          rData['reportType'] = 'clustered';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReportDetailScreen(reportId: reportId, reportData: rData, reportType: 'clustered'),
            ),
          );
          return;
        }
      }

      final regSnap = await FirebaseFirestore.instance.collection('reports').doc(reportId).get();
      if (regSnap.exists && context.mounted) {
        final rData = regSnap.data()!;
        rData['reportType'] = 'regular';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReportDetailScreen(reportId: reportId, reportData: rData, reportType: 'regular'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error navigating to report: $e');
    }
  }

  // --- EMPTY & ERROR STATES ---
  Widget _buildEmptyState(bool isCompletelyEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: isCompletelyEmpty ? lightGreen : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompletelyEmpty ? Icons.check_circle_outline_rounded : Icons.filter_alt_off_outlined,
              size: 44,
              color: isCompletelyEmpty ? darkGreen : textGray,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isCompletelyEmpty ? "You're all caught up!" : 'No matching alerts found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompletelyEmpty
                ? 'No active pest threats, outbreaks, or pending validation notices in your farm zone.'
                : 'Try adjusting your search query or selecting a different filter category above.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13.5, color: textGray, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: dangerBg, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: dangerRed),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load alerts',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: textGray),
            ),
          ],
        ),
      ),
    );
  }
}