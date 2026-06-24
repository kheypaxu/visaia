import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visaia/core/providers/farm_provider.dart';
import 'package:visaia/screens/report_history/report_details.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'All';
  final List<String> _filterOptions = [
    'All',
    'Pending',
    'Validated',
    'Resolved',
    'Rejected',
  ];

  // Color constants
  static const _forestGreen = Color(0xFF1B3015);
  static const _cream = Color(0xFFF8F5EF);

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _cream,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Sign in to view reports',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final farmProvider = context.watch<FarmProvider>();
    final activeFarmId = farmProvider.activeFarmId;

    return Scaffold(
      backgroundColor: _cream,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildSliverAppBar(innerBoxIsScrolled),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('validations')
              .where('farmerId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_forestGreen),
                ),
              );
            }

            final allValidations = snapshot.data?.docs ?? [];

            // Sort by timestamp descending
            final sortedReports = allValidations.toList()
              ..sort((a, b) {
                final aTime =
                    (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                final bTime =
                    (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

            // Filter by active farm
            final farmFiltered = activeFarmId != null
                ? sortedReports.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return d['farmId'] == null || d['farmId'] == activeFarmId;
                  }).toList()
                : sortedReports;

            // Filter by status
            final filteredReports = _filterReports(farmFiltered);

            if (filteredReports.isEmpty) {
              return _buildEmptyState(allValidations, farmFiltered);
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: filteredReports.length,
              itemBuilder: (context, index) {
                final doc = filteredReports[index];
                final data = doc.data() as Map<String, dynamic>;
                return _ReportCard(
                  reportId: doc.id,
                  data: data,
                  onTap: () => _navigateToDetail(doc.id, data),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Sliver App Bar ────────────────────────────────────────────────

  Widget _buildSliverAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      floating: true,
      snap: true,
      pinned: false,
      forceElevated: innerBoxIsScrolled,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(color: Colors.white),
      ),
      expandedHeight: 110,
      collapsedHeight: 56,
      title: Row(
        children: [
          const SizedBox(width: 10),
          Text(
            'Field Reports',
            style: GoogleFonts.epilogue(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _forestGreen,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _forestGreen.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, size: 18, color: _forestGreen),
            ),
            onPressed: _showFilterBottomSheet,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          child: _buildFilterChips(),
        ),
      ),
    );
  }

  // ─── Filter Chips ──────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;
          final chipColor = _getFilterChipColor(filter);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? chipColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? chipColor : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getFilterChipColor(String filter) {
    switch (filter) {
      case 'Pending':
        return Colors.orange;
      case 'Validated':
        return Colors.blue;
      case 'Resolved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return _forestGreen;
    }
  }

  // ─── Empty State ───────────────────────────────────────────────────

  Widget _buildEmptyState(
    List<QueryDocumentSnapshot> allValidations,
    List<QueryDocumentSnapshot> farmFiltered,
  ) {
    String headline = 'No reports yet';
    String sub = 'Pest detections will be logged here automatically.';
    IconData icon = Icons.eco_rounded;

    if (allValidations.isNotEmpty && farmFiltered.isEmpty) {
      headline = 'No reports for this farm';
      sub = 'Switch to a different farm to see its history.';
      icon = Icons.agriculture_rounded;
    } else if (farmFiltered.isNotEmpty && _selectedFilter != 'All') {
      headline = 'No ${_selectedFilter.toLowerCase()} reports';
      sub = 'Change the filter above to see other reports.';
      icon = Icons.filter_list_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _forestGreen.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: _forestGreen.withOpacity(0.4)),
            ),
            const SizedBox(height: 20),
            Text(
              headline,
              style: GoogleFonts.epilogue(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Error State ───────────────────────────────────────────────────

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load reports',
              style: GoogleFonts.epilogue(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Sheet ──────────────────────────────────────────────────

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Filter by status',
              style: GoogleFonts.epilogue(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 16),
            ..._filterOptions.map((filter) {
              final isSelected = _selectedFilter == filter;
              return InkWell(
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _forestGreen.withOpacity(0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getFilterChipColor(filter),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          filter,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? _forestGreen : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: _forestGreen,
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Filter Logic ──────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _filterReports(
      List<QueryDocumentSnapshot> reports) {
    if (_selectedFilter == 'All') return reports;
    return reports.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      return status == _selectedFilter.toLowerCase();
    }).toList();
  }

  // ─── Navigation ────────────────────────────────────────────────────

  void _navigateToDetail(String reportId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          reportId: reportId,
          reportData: data,
        ),
      ),
    );
  }
}

// ─── Report Card ───────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ReportCard({
    required this.reportId,
    required this.data,
    required this.onTap,
  });

  static const _forestGreen = Color(0xFF1B3015);

  @override
  Widget build(BuildContext context) {
    final detection =
        data['detection'] ?? data['originalDetection'] ?? 'Unknown Pest';
    final risk = data['risk'] ?? 'Unknown';
    final status = data['status'] ?? 'pending';
    final timestamp = data['timestamp'];
    final lifeStage =
        data['lifeStage'] ?? data['originalLifeStage'] ?? 'Unknown';
    final confidence = (data['confidence'] ?? 0.0) as num;
    final areaName = data['areaName'] ?? data['fieldName'] ?? 'Unknown location';
    final farmName = data['farmName'] ?? '';

    final statusColor = _statusColor(status);
    final riskColor = _riskColor(risk);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left status accent strip ──
                Container(width: 5, color: statusColor),

                // ── Card body ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: name + status badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                detection,
                                style: GoogleFonts.epilogue(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: _forestGreen,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(status: status, color: statusColor),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Meta row: risk + life stage
                        Row(
                          children: [
                            _MiniPill(
                              label: risk.toUpperCase(),
                              color: riskColor,
                            ),
                            const SizedBox(width: 6),
                            _MiniPill(
                              label: lifeStage,
                              color: Colors.grey.shade500,
                              outlined: true,
                            ),
                            const Spacer(),
                            // Confidence arc indicator
                            _ConfidenceDot(value: confidence.toDouble()),
                            const SizedBox(width: 4),
                            Text(
                              '${(confidence * 100).toInt()}%',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Bottom row: location + date
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                farmName.isNotEmpty
                                    ? '$farmName · $areaName'
                                    : areaName,
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              _fmtDate(timestamp),
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      if (ts is Timestamp) return DateFormat('MMM d').format(ts.toDate());
    } catch (_) {}
    return '';
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'validated':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _riskColor(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return const Color(0xFFD94F3D);
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// ─── Small reusable widgets ────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool outlined;
  const _MiniPill({
    required this.label,
    required this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ConfidenceDot extends StatelessWidget {
  final double value; // 0.0 – 1.0
  const _ConfidenceDot({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value > 0.75
        ? Colors.green
        : value > 0.5
            ? Colors.orange
            : Colors.red;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}