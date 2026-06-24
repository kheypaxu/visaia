import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic> reportData;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.reportData,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isResolving = false;

  // Design tokens
  static const _forestGreen = Color(0xFF1B3015);
  static const _gold = Color(0xFFC8A84B);
  static const _cream = Color(0xFFF8F5EF);

  @override
  Widget build(BuildContext context) {
    final data = widget.reportData;
    final detection = data['detection'] ?? 'Unknown Pest';
    final scientificName = data['scientificName'] ?? '';
    final risk = (data['risk'] ?? 'Unknown') as String;
    final status = (data['status'] ?? 'pending') as String;
    final confidence = (data['confidence'] ?? 0.0) as num;
    final lifeStage = data['lifeStage'] ?? 'Unknown';
    final cropAffected = data['cropAffected'] ?? 'Corn';
    final analysis = data['analysis'] ?? '';
    final treatment = data['treatment'] ?? '';
    final historicalContext = data['historicalContext'] ?? '';
    final imageBase64 = data['imageBase64'];
    final annotatedImageUrl = data['annotatedImageUrl'];
    final timestamp = data['timestamp'];
    final farmName = data['farmName'] ?? 'Unknown Farm';
    final fieldName = data['fieldName'] ?? 'Unknown Field';
    final location = data['location'] as Map<String, dynamic>?;

    final isResolved = status.toLowerCase() == 'resolved';
    final isRejected = status.toLowerCase() == 'rejected';
    final statusColor = _statusColor(status);

    return Scaffold(
      backgroundColor: _cream,
      body: CustomScrollView(
        slivers: [
          // ─── Hero image app bar ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: _forestGreen,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.3),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              if (!isResolved && !isRejected)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: _isResolving
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : TextButton(
                          onPressed: _showResolveConfirmation,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Resolve',
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or gradient background
                  _buildHeroImage(imageBase64, annotatedImageUrl),
                  // Gradient overlay bottom
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.4, 1.0],
                        colors: [Colors.transparent, _forestGreen],
                      ),
                    ),
                  ),
                  // Bottom content overlay
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusChip(status: status, color: statusColor),
                            const SizedBox(width: 8),
                            _StatusChip(
                              status: risk.toUpperCase(),
                              color: _riskColor(risk),
                              icon: Icons.warning_amber_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          detection,
                          style: GoogleFonts.epilogue(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        if (scientificName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            scientificName,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── Body content ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status banner
                  _StatusBanner(status: status, color: statusColor),

                  const SizedBox(height: 16),

                  // Quick stats row
                  _QuickStatsRow(
                    confidence: confidence.toDouble(),
                    lifeStage: lifeStage,
                    cropAffected: cropAffected,
                    timestamp: timestamp,
                  ),

                  const SizedBox(height: 16),

                  // Location card
                  _InfoCard(
                    icon: Icons.pin_drop_rounded,
                    title: 'Location',
                    accentColor: _gold,
                    children: [
                      _Row('Farm', farmName),
                      _Row('Field', fieldName),
                      if (location?['areaName'] != null)
                        _Row('Area', location!['areaName']),
                      if (location?['lat'] != null && location?['lng'] != null)
                        _Row(
                          'Coordinates',
                          '${location!['lat']?.toStringAsFixed(5)}, ${location['lng']?.toStringAsFixed(5)}',
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Analysis
                  if (analysis.isNotEmpty) ...[
                    _ExpandableCard(
                      icon: Icons.analytics_outlined,
                      title: 'AI Analysis',
                      accentColor: Colors.blue,
                      child: MarkdownBody(
                        data: analysis,
                        styleSheet: _mdStyle(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Treatment
                  if (treatment.isNotEmpty) ...[
                    _ExpandableCard(
                      icon: Icons.healing_outlined,
                      title: 'Treatment Plan',
                      accentColor: Colors.green,
                      initiallyExpanded: true,
                      child: MarkdownBody(
                        data: treatment,
                        styleSheet: _mdStyle(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Historical context
                  if (historicalContext.isNotEmpty) ...[
                    _ExpandableCard(
                      icon: Icons.history_rounded,
                      title: 'Historical Context',
                      accentColor: _gold,
                      child: Text(
                        historicalContext,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          height: 1.65,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Resolve CTA
                  if (!isResolved && !isRejected) ...[
                    const SizedBox(height: 8),
                    _ResolveCTA(
                      isResolving: _isResolving,
                      onNotYet: () => Navigator.pop(context),
                      onResolve: _showResolveConfirmation,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero Image ─────────────────────────────────────────────────────

  Widget _buildHeroImage(String? base64, String? networkUrl) {
    if (base64 != null) {
      try {
        final bytes = base64Decode(
          base64.startsWith('data:image') ? base64.split(',').last : base64,
        );
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (networkUrl != null) {
      return Image.network(
        networkUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _heroPlaceholder(),
      );
    }
    return _heroPlaceholder();
  }

  Widget _heroPlaceholder() {
    return Container(
      color: _forestGreen,
      child: Center(
        child: Icon(
          Icons.bug_report_outlined,
          size: 64,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  // ─── Resolve ────────────────────────────────────────────────────────

  void _showResolveConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.green,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mark as Resolved?',
              style: GoogleFonts.epilogue(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _forestGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirm you have successfully treated this pest issue and the crops are healthy again.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Not Yet',
                      style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _markAsResolved();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Yes, Resolved',
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsResolved() async {
    setState(() => _isResolving = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      await _firestore.collection('reports').doc(widget.reportId).update({
        'status': 'resolved',
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': user.uid,
        'resolvedByUserName': await _getUserName(user.uid),
      });

      final validationsSnap = await _firestore
          .collection('validations')
          .where('reportId', isEqualTo: widget.reportId)
          .get();

      for (final doc in validationsSnap.docs) {
        await doc.reference.update({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Report marked as resolved',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        setState(() => widget.reportData['status'] = 'resolved');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('farmers').doc(userId).get();
      return doc.data()?['fullName'] ?? doc.data()?['name'] ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────

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

  MarkdownStyleSheet _mdStyle() => MarkdownStyleSheet(
        p: GoogleFonts.manrope(
            fontSize: 14, height: 1.65, color: Colors.grey[700]),
        h1: GoogleFonts.epilogue(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _forestGreen),
        h2: GoogleFonts.epilogue(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _forestGreen),
        h3: GoogleFonts.epilogue(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _forestGreen),
        strong: GoogleFonts.manrope(
            fontWeight: FontWeight.w800, color: _forestGreen),
        listBullet:
            GoogleFonts.manrope(fontSize: 14, color: Colors.grey[700]),
        blockquote: GoogleFonts.manrope(
            fontSize: 14,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic),
        blockquoteDecoration: BoxDecoration(
          border: Border(
              left: BorderSide(color: Colors.grey[300]!, width: 3)),
          color: Colors.grey[50],
        ),
      );
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final Color color;
  final IconData? icon;
  const _StatusChip({required this.status, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            status,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBanner({required this.status, required this.color});

  String get _label {
    switch (status.toLowerCase()) {
      case 'resolved':
        return 'Issue resolved';
      case 'validated':
        return 'Validated by expert — action recommended';
      case 'pending':
        return 'Awaiting expert review';
      case 'rejected':
        return 'Rejected by expert';
      default:
        return status;
    }
  }

  IconData get _icon {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Icons.check_circle_rounded;
      case 'validated':
        return Icons.verified_rounded;
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color.darken(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _ColorDarken on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

class _QuickStatsRow extends StatelessWidget {
  final double confidence;
  final String lifeStage;
  final String cropAffected;
  final dynamic timestamp;

  const _QuickStatsRow({
    required this.confidence,
    required this.lifeStage,
    required this.cropAffected,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final date = _fmtDate(timestamp);
    return Row(
      children: [
        _StatTile(
          value: '${(confidence * 100).toInt()}%',
          label: 'Confidence',
          color: confidence > 0.75
              ? Colors.green
              : confidence > 0.5
                  ? Colors.orange
                  : Colors.red,
        ),
        const SizedBox(width: 8),
        _StatTile(value: lifeStage, label: 'Life stage', emoji: '🐛'),
        const SizedBox(width: 8),
        _StatTile(value: cropAffected, label: 'Crop', emoji: '🌽'),
        if (date.isNotEmpty) ...[
          const SizedBox(width: 8),
          _StatTile(value: date, label: 'Detected'),
        ],
      ],
    );
  }

  String _fmtDate(dynamic ts) {
    if (ts == null) return '';
    try {
      if (ts is Timestamp) return DateFormat('MMM d').format(ts.toDate());
    } catch (_) {}
    return '';
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color? color;
  final String? emoji;

  const _StatTile({
    required this.value,
    required this.label,
    this.color,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: color != null
              ? color!.withOpacity(0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color != null
                ? color!.withOpacity(0.15)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              emoji != null ? '$emoji $value' : value,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color ?? const Color(0xFF1B3015),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.epilogue(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B3015),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final Widget child;
  final bool initiallyExpanded;

  const _ExpandableCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.epilogue(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B3015),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey[400],
          ),
          children: [
            Divider(color: Colors.grey.shade100, height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ResolveCTA extends StatelessWidget {
  final bool isResolving;
  final VoidCallback onNotYet;
  final VoidCallback onResolve;

  const _ResolveCTA({
    required this.isResolving,
    required this.onNotYet,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Has this pest issue been treated?',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B3015),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Mark as resolved once crops are healthy again.',
            style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onNotYet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Not Yet',
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isResolving ? null : onResolve,
                  icon: isResolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Mark Resolved',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B3015),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}