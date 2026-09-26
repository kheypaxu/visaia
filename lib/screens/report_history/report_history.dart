import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visaia/core/providers/farm_provider.dart';
import 'package:visaia/screens/report_history/report_details.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/widgets/database_image.dart';

// ══════════════════════════════════════════════════════════════════════════════
// UNIFIED REPORT MODEL
// ══════════════════════════════════════════════════════════════════════════════

class UnifiedReportItem {
  final String id;
  final String reportType; // 'regular' or 'clustered'
  final String title;
  final String? subtitle;
  final String? scientificName;
  final String risk;
  final String status; // 'pending', 'validated', 'resolved', 'rejected', 'pending_offline_sync'
  final DateTime timestamp;
  final String farmName;
  final String fieldName;
  final String? farmId;
  final String? fieldId;
  final String? imageSource;
  final double? confidence;
  final String? lifeStage;
  final String? cropAffected;
  // Clustered specifics
  final String? growthStage;
  final int? dap;
  final double? damagePercentage;
  final int? totalInspected;
  final int? totalDamaged;
  final Map<String, dynamic>? totals;
  final bool exceedsThreshold;
  // Validation specifics
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? validationNotes;
  final String? expertDiagnosis;
  final String? advisoryMessage;
  final String? rejectionReason;
  final String? resolutionExplanation;
  final Map<String, dynamic> rawData;

  UnifiedReportItem({
    required this.id,
    required this.reportType,
    required this.title,
    this.subtitle,
    this.scientificName,
    required this.risk,
    required this.status,
    required this.timestamp,
    required this.farmName,
    required this.fieldName,
    this.farmId,
    this.fieldId,
    this.imageSource,
    this.confidence,
    this.lifeStage,
    this.cropAffected,
    this.growthStage,
    this.dap,
    this.damagePercentage,
    this.totalInspected,
    this.totalDamaged,
    this.totals,
    this.exceedsThreshold = false,
    this.validatedBy,
    this.validatedAt,
    this.validationNotes,
    this.expertDiagnosis,
    this.advisoryMessage,
    this.rejectionReason,
    this.resolutionExplanation,
    required this.rawData,
  });

  factory UnifiedReportItem.fromRegularReport(String id, Map<String, dynamic> data) {
    final detection = data['detection'] ?? data['originalDetection'] ?? 'Unknown Pest';
    final risk = (data['risk'] ?? 'Low').toString();
    final status = (data['status'] ?? 'pending').toString();
    final rawTs = data['timestamp'] ?? data['createdAt'];
    DateTime ts = DateTime.now();
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is DateTime) {
      ts = rawTs;
    }

    final imageSrc = (data['imageBase64'] ?? data['annotatedImageUrl'] ?? data['annotated_url']) as String?;

    return UnifiedReportItem(
      id: id,
      reportType: 'regular',
      title: detection.toString(),
      subtitle: data['lifeStage'] != null ? '${data['lifeStage']} stage' : null,
      scientificName: data['scientificName'] as String?,
      risk: risk,
      status: status,
      timestamp: ts,
      farmName: (data['farmName'] ?? '').toString(),
      fieldName: (data['fieldName'] ?? data['areaName'] ?? 'Field').toString(),
      farmId: data['farmId'] as String?,
      fieldId: data['fieldId'] as String?,
      imageSource: imageSrc,
      confidence: (data['confidence'] as num?)?.toDouble(),
      lifeStage: (data['lifeStage'] ?? data['originalLifeStage']) as String?,
      cropAffected: data['cropAffected'] as String? ?? 'Corn',
      validatedBy: data['validatedBy'] as String?,
      validatedAt: (data['validatedAt'] as Timestamp?)?.toDate(),
      validationNotes: data['validationNotes'] as String?,
      expertDiagnosis: data['expertDiagnosis'] as String?,
      advisoryMessage: data['advisoryMessage'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      resolutionExplanation: data['resolutionExplanation'] as String?,
      rawData: {
        ...data,
        'reportType': 'regular',
      },
    );
  }

  factory UnifiedReportItem.fromClusteredReport(String id, Map<String, dynamic> data) {
    final growthStage = (data['growthStage'] ?? 'Corn').toString();
    final dap = data['dap'] is int ? data['dap'] as int : null;
    final risk = (data['riskLevel'] ?? data['severityLevel'] ?? (data['isHighLevel'] == true ? 'High' : 'Moderate')).toString();
    final status = (data['status'] ?? 'pending').toString();

    final rawTs = data['reportDate'] ?? data['timestamp'] ?? data['createdAt'];
    DateTime ts = DateTime.now();
    if (rawTs is Timestamp) {
      ts = rawTs.toDate();
    } else if (rawTs is DateTime) {
      ts = rawTs;
    }

    final totalInspected = data['totalInspected'] is num ? (data['totalInspected'] as num).toInt() : 100;
    final totalDamaged = data['totalDamaged'] is num ? (data['totalDamaged'] as num).toInt() : 0;
    final damagePercentage = data['damagePercentage'] is num
        ? (data['damagePercentage'] as num).toDouble()
        : (totalInspected > 0 ? (totalDamaged / totalInspected) * 100 : 0.0);
    final exceedsThreshold = data['exceedsThreshold'] == true || damagePercentage >= 10.0;

    // Pick first available image from capturedImages
    String? firstImage;
    final capturedImages = data['capturedImages'] as Map<String, dynamic>?;
    if (capturedImages != null) {
      for (final k in ['larvae', 'eggMasses', 'damage', 'pupae', 'moths']) {
        final list = capturedImages[k] as List?;
        if (list != null && list.isNotEmpty && list.first is String) {
          firstImage = list.first as String;
          break;
        }
      }
    }

    // If still null, check stationsData
    if (firstImage == null) {
      final stationsData = data['stationsData'] as List?;
      if (stationsData != null) {
        for (final s in stationsData) {
          if (s is Map<String, dynamic>) {
            final sImgs = s['capturedImages'] as Map<String, dynamic>?;
            if (sImgs != null) {
              for (final listEntry in sImgs.values) {
                if (listEntry is List && listEntry.isNotEmpty && listEntry.first is String) {
                  firstImage = listEntry.first as String;
                  break;
                }
              }
            }
          }
          if (firstImage != null) break;
        }
      }
    }

    return UnifiedReportItem(
      id: id,
      reportType: 'clustered',
      title: 'FAW Scouting ($growthStage)',
      subtitle: dap != null ? 'DAP $dap · ${damagePercentage.toStringAsFixed(1)}% Damage' : '${damagePercentage.toStringAsFixed(1)}% Damage',
      scientificName: 'Spodoptera frugiperda',
      risk: risk,
      status: status,
      timestamp: ts,
      farmName: (data['farmName'] ?? '').toString(),
      fieldName: (data['fieldName'] ?? 'Field').toString(),
      farmId: data['farmId'] as String?,
      fieldId: data['fieldId'] as String?,
      imageSource: firstImage,
      growthStage: growthStage,
      dap: dap,
      damagePercentage: damagePercentage,
      totalInspected: totalInspected,
      totalDamaged: totalDamaged,
      totals: data['totals'] as Map<String, dynamic>?,
      exceedsThreshold: exceedsThreshold,
      cropAffected: 'Corn',
      validatedBy: data['validatedBy'] as String?,
      validatedAt: (data['validatedAt'] as Timestamp?)?.toDate(),
      validationNotes: data['validationNotes'] as String?,
      expertDiagnosis: data['expertDiagnosis'] as String?,
      advisoryMessage: data['advisoryMessage'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      resolutionExplanation: data['resolutionExplanation'] as String?,
      rawData: {
        ...data,
        'reportType': 'clustered',
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORT HISTORY SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthCacheService _cacheService = AuthCacheService();

  String _selectedFilter = 'All';
  String _selectedType = 'All'; // 'All', 'AI Scans', 'Scouting'
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _statusFilters = [
    'All',
    'Pending',
    'Validated',
    'Resolved',
    'Rejected',
  ];

  // Colors
  static const _forestGreen = Color(0xFF1B3015);
  static const _cream = Color(0xFFF8F5EF);
  static const _textMuted = Color(0xFF8A9B8F);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Combined Stream for reports + clustered_reports ───────────────────────
  Stream<List<UnifiedReportItem>> _getUnifiedStream(String uid) {
    late StreamController<List<UnifiedReportItem>> controller;
    StreamSubscription? subReports;
    StreamSubscription? subClusteredFarmer;
    StreamSubscription? subClusteredUser;

    List<QueryDocumentSnapshot> reportsDocs = [];
    List<QueryDocumentSnapshot> clusteredFarmerDocs = [];
    List<QueryDocumentSnapshot> clusteredUserDocs = [];

    void emit() {
      if (controller.isClosed) return;
      final Map<String, UnifiedReportItem> itemsMap = {};

      // 1. Regular reports
      for (final doc in reportsDocs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'deleted') continue;
        itemsMap[doc.id] = UnifiedReportItem.fromRegularReport(doc.id, data);
      }

      // 2. Clustered reports
      final allClustered = [...clusteredFarmerDocs, ...clusteredUserDocs];
      for (final doc in allClustered) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'deleted') continue;
        itemsMap[doc.id] = UnifiedReportItem.fromClusteredReport(doc.id, data);
      }

      final items = itemsMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      controller.add(items);
    }

    controller = StreamController<List<UnifiedReportItem>>.broadcast(
      onListen: () {
        subReports = _firestore
            .collection('reports')
            .where('farmerId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          reportsDocs = snap.docs;
          emit();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });

        subClusteredFarmer = _firestore
            .collection('clustered_reports')
            .where('farmerId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          clusteredFarmerDocs = snap.docs;
          emit();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });

        subClusteredUser = _firestore
            .collection('clustered_reports')
            .where('userId', isEqualTo: uid)
            .snapshots()
            .listen((snap) {
          clusteredUserDocs = snap.docs;
          emit();
        }, onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });
      },
      onCancel: () {
        subReports?.cancel();
        subClusteredFarmer?.cancel();
        subClusteredUser?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid ?? _cacheService.cachedUid;
    if (uid == null || uid.isEmpty) {
      return _buildUnauthorizedState();
    }

    final farmProvider = context.watch<FarmProvider>();
    final activeFarmId = farmProvider.activeFarmId;

    return Scaffold(
      backgroundColor: _cream,
      body: StreamBuilder<List<UnifiedReportItem>>(
        stream: _getUnifiedStream(uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }

          final allReports = snapshot.data ?? [];

          // Filter by active farm
          final farmFiltered = activeFarmId != null
              ? allReports.where((item) {
                  return item.farmId == null ||
                      item.farmId!.isEmpty ||
                      item.farmId == activeFarmId;
                }).toList()
              : allReports;

          // Status counts for badge chips
          final pendingCount = farmFiltered.where((r) => r.status.toLowerCase() == 'pending').length;
          final validatedCount = farmFiltered.where((r) => r.status.toLowerCase() == 'validated').length;
          final resolvedCount = farmFiltered.where((r) => r.status.toLowerCase() == 'resolved').length;
          final rejectedCount = farmFiltered.where((r) => r.status.toLowerCase() == 'rejected').length;

          // Filter by status, type, and search
          final displayedReports = _applyFilters(farmFiltered);

          return Column(
            children: [
              // ─── Header ──────────────────────────────────────────────
              _buildHeader(
                totalCount: farmFiltered.length,
                pendingCount: pendingCount,
                validatedCount: validatedCount,
              ),

              // ─── Compact Space-Efficient Filter Bar ──────────────────
              _buildCompactFilterBar(
                totalCount: farmFiltered.length,
                pendingCount: pendingCount,
                validatedCount: validatedCount,
                resolvedCount: resolvedCount,
                rejectedCount: rejectedCount,
                regularCount: farmFiltered.where((r) => r.reportType == 'regular').length,
                clusteredCount: farmFiltered.where((r) => r.reportType == 'clustered').length,
              ),

              // ─── Reports List ─────────────────────────────────────────
              Expanded(
                child: displayedReports.isEmpty
                    ? _buildEmptyState(allReports, farmFiltered)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: displayedReports.length,
                        itemBuilder: (context, index) {
                          final item = displayedReports[index];
                          return ReportCard(
                            item: item,
                            onTap: () => _navigateToDetail(item),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader({
    required int totalCount,
    required int pendingCount,
    required int validatedCount,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _forestGreen,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _forestGreen.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report History',
                      style: GoogleFonts.epilogue(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'Scouting & AI detections synced with RCPC',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Search toggle button
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: _isSearchOpen
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(8),
                ),
                icon: Icon(
                  _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    _isSearchOpen = !_isSearchOpen;
                    if (!_isSearchOpen) {
                      _searchQuery = '';
                      _searchController.clear();
                    }
                  });
                },
              ),
            ],
          ),

          // Search Field (if open)
          if (_isSearchOpen) ...[
            const SizedBox(height: 12),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Search by pest, farm, stage, or notes...',
                  hintStyle: GoogleFonts.manrope(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 18),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 16),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Compact Space-Efficient Filter Bar ────────────────────────────────────

  Widget _buildCompactFilterBar({
    required int totalCount,
    required int pendingCount,
    required int validatedCount,
    required int resolvedCount,
    required int rejectedCount,
    required int regularCount,
    required int clusteredCount,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        children: [
          // Row 1: Status Chips (Horizontal scrollable, compact height: 36)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final filter = _statusFilters[index];
                final isSelected = _selectedFilter == filter;
                final chipColor = _getFilterChipColor(filter);

                int count = totalCount;
                if (filter == 'Pending') count = pendingCount;
                if (filter == 'Validated') count = validatedCount;
                if (filter == 'Resolved') count = resolvedCount;
                if (filter == 'Rejected') count = rejectedCount;

                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? chipColor : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected ? chipColor : Colors.grey.shade300,
                        width: 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: chipColor.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          filter,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.manrope(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? Colors.white : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Row 2: Type Segment (Height: 30) - All | AI Scans | Scouting
          SizedBox(
            height: 30,
            child: Row(
              children: [
                _buildTypeSegmentItem('All', totalCount),
                const SizedBox(width: 6),
                _buildTypeSegmentItem('AI Scans', regularCount, icon: Icons.auto_awesome_rounded),
                const SizedBox(width: 6),
                _buildTypeSegmentItem('Scouting', clusteredCount, icon: Icons.grid_view_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegmentItem(String type, int count, {IconData? icon}) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _forestGreen.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _forestGreen : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected ? _forestGreen : Colors.grey[500],
                ),
                const SizedBox(width: 4),
              ],
              Text(
                '$type ($count)',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? _forestGreen : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getFilterChipColor(String filter) {
    switch (filter) {
      case 'Pending':
        return Colors.orange[800]!;
      case 'Validated':
        return const Color(0xFF1D4ED8);
      case 'Resolved':
        return const Color(0xFF15803D);
      case 'Rejected':
        return const Color(0xFFDC2626);
      default:
        return _forestGreen;
    }
  }

  // ─── Filter Logic ──────────────────────────────────────────────────────────

  List<UnifiedReportItem> _applyFilters(List<UnifiedReportItem> items) {
    var result = items;

    // 1. Status Filter
    if (_selectedFilter != 'All') {
      result = result.where((item) {
        return item.status.toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    }

    // 2. Type Filter
    if (_selectedType == 'AI Scans') {
      result = result.where((item) => item.reportType == 'regular').toList();
    } else if (_selectedType == 'Scouting') {
      result = result.where((item) => item.reportType == 'clustered').toList();
    }

    // 3. Search Filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((item) {
        return item.title.toLowerCase().contains(q) ||
            (item.subtitle?.toLowerCase().contains(q) ?? false) ||
            item.farmName.toLowerCase().contains(q) ||
            item.fieldName.toLowerCase().contains(q) ||
            (item.growthStage?.toLowerCase().contains(q) ?? false) ||
            (item.cropAffected?.toLowerCase().contains(q) ?? false) ||
            (item.validationNotes?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return result;
  }

  // ─── Navigation ────────────────────────────────────────────────────────────

  void _navigateToDetail(UnifiedReportItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          reportId: item.id,
          reportData: item.rawData,
          reportType: item.reportType,
        ),
      ),
    );
  }

  // ─── Empty & Error States ──────────────────────────────────────────────────

  Widget _buildEmptyState(
    List<UnifiedReportItem> allReports,
    List<UnifiedReportItem> farmFiltered,
  ) {
    String headline = 'No reports yet';
    String sub = 'Your AI pest scans and field scouting reports will appear here.';
    IconData icon = Icons.eco_rounded;

    if (allReports.isNotEmpty && farmFiltered.isEmpty) {
      headline = 'No reports for this farm';
      sub = 'Switch to a different farm to view its scouting and AI history.';
      icon = Icons.agriculture_rounded;
    } else if (farmFiltered.isNotEmpty && _selectedFilter != 'All') {
      headline = 'No ${_selectedFilter.toLowerCase()} reports';
      sub = 'Change the filter tab above to view other reports.';
      icon = Icons.filter_list_rounded;
    } else if (_searchQuery.isNotEmpty) {
      headline = 'No results found';
      sub = 'No reports matched "$_searchQuery".';
      icon = Icons.search_off_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _forestGreen.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: _forestGreen.withValues(alpha: 0.4)),
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
            const SizedBox(height: 6),
            Text(
              sub,
              style: GoogleFonts.manrope(fontSize: 13.5, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
              child: Icon(Icons.lock_outline_rounded, size: 44, color: Colors.grey[400]),
            ),
            const SizedBox(height: 20),
            Text(
              'Sign in to view reports',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
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
              style: GoogleFonts.epilogue(fontSize: 18, fontWeight: FontWeight.w700, color: _forestGreen),
            ),
            const SizedBox(height: 6),
            Text(error, style: GoogleFonts.manrope(fontSize: 12, color: Colors.grey[500]), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(backgroundColor: _forestGreen),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REPORT CARD COMPONENT (WITH VISIBLE THUMBNAIL)
// ══════════════════════════════════════════════════════════════════════════════

class ReportCard extends StatelessWidget {
  final UnifiedReportItem item;
  final VoidCallback onTap;

  const ReportCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  static const _forestGreen = Color(0xFF1B3015);

  @override
  Widget build(BuildContext context) {
    final isClustered = item.reportType == 'clustered';
    final statusColor = _statusColor(item.status);
    final riskColor = _riskColor(item.risk);
    final isValidated = item.status.toLowerCase() == 'validated';
    final isRejected = item.status.toLowerCase() == 'rejected';
    final isResolved = item.status.toLowerCase() == 'resolved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 3),
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
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Thumbnail Image / Badge ──────────────────────────────
                    _buildCardThumbnail(isClustered),

                    const SizedBox(width: 12),

                    // ── Card Main Info ───────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: Title + Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: GoogleFonts.epilogue(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: _forestGreen,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              _StatusBadge(status: item.status, color: statusColor),
                            ],
                          ),

                          const SizedBox(height: 5),

                          // Subtitle: Growth stage or Life Stage
                          if (item.subtitle != null) ...[
                            Text(
                              item.subtitle!,
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isClustered && item.exceedsThreshold
                                    ? Colors.red[700]
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Metrics Tags Row
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _MiniPill(label: item.risk.toUpperCase(), color: riskColor),
                              if (isClustered) ...[
                                if (item.totals != null && (item.totals!['larvae'] ?? 0) > 0)
                                  _MiniPill(
                                    label: '${item.totals!['larvae']} Larvae',
                                    color: Colors.amber[800]!,
                                  ),
                                if (item.totals != null && (item.totals!['moths'] ?? 0) > 0)
                                  _MiniPill(
                                    label: '${item.totals!['moths']} Moths',
                                    color: Colors.purple[700]!,
                                  ),
                              ] else ...[
                                if (item.confidence != null && item.confidence! > 0)
                                  _MiniPill(
                                    label: '${(item.confidence! * 100).toInt()}% Conf',
                                    color: Colors.blue[700]!,
                                    outlined: true,
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 8),

                // ── Bottom Row: Validation tag & Farm / Date ─────────────────
                Row(
                  children: [
                    if (isValidated) ...[
                      Icon(Icons.verified_rounded, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Validated by RCPC',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue[700],
                        ),
                      ),
                    ] else if (isRejected) ...[
                      Icon(Icons.cancel_outlined, size: 14, color: Colors.red[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Rejected by RCPC',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red[700],
                        ),
                      ),
                    ] else if (isResolved) ...[
                      Icon(Icons.check_circle_rounded, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[700],
                        ),
                      ),
                    ] else ...[
                      Icon(Icons.location_on_outlined, size: 13, color: Colors.grey[400]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          item.farmName.isNotEmpty
                              ? '${item.farmName} · ${item.fieldName}'
                              : item.fieldName,
                          style: GoogleFonts.manrope(fontSize: 11.5, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    const Spacer(),

                    Icon(Icons.schedule_rounded, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      _fmtDate(item.timestamp),
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[400]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardThumbnail(bool isClustered) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: _forestGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.imageSource != null && item.imageSource!.isNotEmpty)
              DatabaseImage(source: item.imageSource!, fit: BoxFit.cover)
            else
              Center(
                child: Icon(
                  isClustered ? Icons.grid_view_rounded : Icons.pest_control_rounded,
                  color: _forestGreen.withValues(alpha: 0.4),
                  size: 32,
                ),
              ),

            // Top-left small badge indicating SCOUTING vs AI
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isClustered
                      ? const Color(0xDD0D4D33)
                      : const Color(0xDD1D4ED8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isClustered ? 'SCOUT' : 'AI',
                  style: GoogleFonts.manrope(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return DateFormat('h:mm a').format(dt);
    } else if (diff.inDays < 7) {
      return DateFormat('E, h:mm a').format(dt);
    }
    return DateFormat('MMM d').format(dt);
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':
        return const Color(0xFF15803D);
      case 'validated':
        return const Color(0xFF1D4ED8);
      case 'pending':
        return Colors.orange[800]!;
      case 'pending_offline_sync':
        return const Color(0xFFB45309);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return Colors.grey;
    }
  }

  Color _riskColor(String r) {
    switch (r.toLowerCase()) {
      case 'high':
      case 'critical':
      case 'very high':
        return const Color(0xFFD94F3D);
      case 'medium':
      case 'moderate':
        return Colors.orange[800]!;
      case 'low':
        return const Color(0xFF15803D);
      default:
        return Colors.grey;
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MINI BADGES & PILLS
// ══════════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final displayStatus = status == 'pending_offline_sync'
        ? 'QUEUED'
        : status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        displayStatus,
        style: GoogleFonts.manrope(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.4,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.35)) : null,
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
