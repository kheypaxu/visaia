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

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
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
  static const _textMuted = Color(0xFF8A9B8F);

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return _buildUnauthorizedState();
    }

    final farmProvider = context.watch<FarmProvider>();
    final activeFarmId = farmProvider.activeFarmId;

    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          // ─── Header Section ──────────────────────────────────────────────
          _buildHeader(),
          // ─── Filter Chips ────────────────────────────────────────────────
          _buildFilterChips(),
          // ─── Report List ─────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('reports')
                  .where('farmerId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                final allReports = snapshot.data?.docs ?? [];

                // Sort by timestamp descending
                final sortedReports = allReports.toList()
                  ..sort((a, b) {
                    final aTime =
                        (a.data() as Map<String, dynamic>)['timestamp']
                            as Timestamp?;
                    final bTime =
                        (b.data() as Map<String, dynamic>)['timestamp']
                            as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  });

                // Filter by active farm
                final farmFiltered = activeFarmId != null
                    ? sortedReports.where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return d['farmId'] == null ||
                            d['farmId'] == activeFarmId;
                      }).toList()
                    : sortedReports;

                // Filter by status
                final filteredReports = _filterReports(farmFiltered);

                if (filteredReports.isEmpty) {
                  return _buildEmptyState(allReports, farmFiltered);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) {
                    final doc = filteredReports[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return ReportCard(
                      reportId: doc.id,
                      data: data,
                      onTap: () => _navigateToDetail(doc.id, data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _forestGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.history_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report history',
                  style: GoogleFonts.epilogue(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Track every detection from review to resolution.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('reports')
                .where('farmerId', isEqualTo: _auth.currentUser?.uid ?? '')
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.article_rounded,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ──────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filterOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = _filterOptions[index];
            final isSelected = _selectedFilter == filter;
            final chipColor = _getFilterChipColor(filter);

            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? chipColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? chipColor : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    Text(
                      filter,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
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

  // ─── States ──────────────────────────────────────────────────────────────

  Widget _buildUnauthorizedState() {
    return Scaffold(
      backgroundColor: _cream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to view reports',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your pest detection reports will appear here',
              style: GoogleFonts.manrope(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_forestGreen),
          ),
          SizedBox(height: 16),
          Text(
            'Loading reports...',
            style: TextStyle(color: _textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    List<QueryDocumentSnapshot> allReports,
    List<QueryDocumentSnapshot> farmFiltered,
  ) {
    String headline = 'No reports yet';
    String sub = 'Pest detections from your AI scans will appear here.';
    IconData icon = Icons.eco_rounded;

    if (allReports.isNotEmpty && farmFiltered.isEmpty) {
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _forestGreen.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 44,
                color: _forestGreen.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              headline,
              style: GoogleFonts.epilogue(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sub,
              style: GoogleFonts.manrope(fontSize: 15, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: Colors.red[300],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t load reports',
              style: GoogleFonts.epilogue(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Filter Logic ──────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _filterReports(
    List<QueryDocumentSnapshot> reports,
  ) {
    if (_selectedFilter == 'All') return reports;
    return reports.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString().toLowerCase() ?? 'pending';
      return status == _selectedFilter.toLowerCase();
    }).toList();
  }

  // ─── Navigation ────────────────────────────────────────────────────────

  void _navigateToDetail(String reportId, Map<String, dynamic> data) {
    // Report history always opens its own detail view. Besides presenting the
    // complete AI result, that screen owns report lifecycle actions such as
    // marking a validated/pending report as resolved.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ReportDetailScreen(reportId: reportId, reportData: data),
      ),
    );
  }
}

// ─── Report Card ───────────────────────────────────────────────────────────────

class ReportCard extends StatelessWidget {
  final String reportId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
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
    final areaName =
        data['areaName'] ?? data['fieldName'] ?? 'Unknown location';
    final farmName = data['farmName'] ?? '';

    final statusColor = _statusColor(status);
    final riskColor = _riskColor(risk);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: Name + Status ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          detection,
                          style: GoogleFonts.epilogue(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _forestGreen,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _StatusBadge(status: status, color: statusColor),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Risk + Life Stage row ──
                  Row(
                    children: [
                      _MiniPill(label: risk.toUpperCase(), color: riskColor),
                      const SizedBox(width: 6),
                      _MiniPill(
                        label: lifeStage,
                        color: Colors.grey.shade500,
                        outlined: true,
                      ),
                      const Spacer(),
                      // Confidence
                      Row(
                        children: [
                          _ConfidenceDot(value: confidence.toDouble()),
                          const SizedBox(width: 6),
                          Text(
                            '${(confidence * 100).toInt()}%',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Divider ──
                  Divider(height: 1, color: Colors.grey.shade100),

                  const SizedBox(height: 10),

                  // ── Bottom: Location + Date ──
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
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
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _fmtDate(timestamp),
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        status.toString().toLowerCase() == 'resolved'
                            ? 'Resolution details'
                            : 'Open report',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _forestGreen,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: _forestGreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      if (ts is Timestamp) return DateFormat('MMM d, yyyy').format(ts.toDate());
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10,
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
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: outlined
            ? Border.all(color: color.withValues(alpha: 0.3))
            : null,
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
  final double value;
  const _ConfidenceDot({required this.value});

  @override
  Widget build(BuildContext context) {
    final color = value > 0.75
        ? Colors.green
        : value > 0.5
        ? Colors.orange
        : Colors.red;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
