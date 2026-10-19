import 'package:visaia/services/pdf_theme_service.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

// ══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ══════════════════════════════════════════════════════════════════════════════

class FarmFieldSummary {
  final String id;
  final String name;
  final double acres;
  final String? crop;

  FarmFieldSummary({
    required this.id,
    required this.name,
    required this.acres,
    this.crop,
  });
}

class FarmCycleSummary {
  final String id;
  final String cycleName;
  final String cropVariety;
  final String fieldName;
  final DateTime? plantingDate;
  final DateTime? harvestDate;
  final int? dap;
  final String weekText;
  final String growthStage;
  final double growthProgress;
  final double seedDensity;
  final bool isCompleted;
  final double? income;
  final double? yieldAmount;

  FarmCycleSummary({
    required this.id,
    required this.cycleName,
    required this.cropVariety,
    required this.fieldName,
    this.plantingDate,
    this.harvestDate,
    this.dap,
    required this.weekText,
    required this.growthStage,
    required this.growthProgress,
    this.seedDensity = 0.0,
    this.isCompleted = false,
    this.income,
    this.yieldAmount,
  });
}

class FarmReportData {
  final String ownerName;
  final String farmName;
  final String location;
  final DateTime reportDate;

  // Active Cycle (primary)
  final String cycleName;
  final String weekText;
  final String growthStage;
  final double growthProgress; // 0.0 to 1.0

  // Surveillance counts (number of reports)
  final int totalReports; // preliminary AI reports
  final int totalClusteredReports; // field scouting reports
  final int totalCombinedReports; // total surveillance reports
  final int pendingReports;
  final int validatedReports;
  final int resolvedReports;
  final int rejectedReports;
  final int highRiskReports;

  // Financials & Production
  final double netIncome;
  final double totalYield;
  final int totalFields;
  final double acres;

  // Registered fields & cycles info
  final List<FarmFieldSummary> fields;
  final List<FarmCycleSummary> activeCycles;
  final List<FarmCycleSummary> completedCycles;

  FarmReportData({
    required this.ownerName,
    required this.farmName,
    required this.location,
    required this.reportDate,
    required this.cycleName,
    required this.weekText,
    required this.growthStage,
    required this.growthProgress,
    required this.totalReports,
    required this.pendingReports,
    required this.validatedReports,
    required this.resolvedReports,
    this.totalClusteredReports = 0,
    this.totalCombinedReports = 0,
    this.rejectedReports = 0,
    this.highRiskReports = 0,
    this.netIncome = 0,
    this.totalYield = 0,
    this.totalFields = 0,
    this.acres = 0,
    this.fields = const [],
    this.activeCycles = const [],
    this.completedCycles = const [],
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SERVICE IMPLEMENTATION
// ══════════════════════════════════════════════════════════════════════════════

class FarmReportPdfService {
  static const PdfColor _darkGreen = PdfColor.fromInt(0xFF084C23);
  static const PdfColor _lightSage = PdfColor.fromInt(0xFFD6E3D1);
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFFD0D7CF);

  static DateTime? _parseNullableDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  /// Fetches farm profile, fields, cycle status, and surveillance report counts
  static Future<FarmReportData> fetchFarmReportData({
    required String userId,
    required String farmId,
    required Map<String, dynamic> farmData,
  }) async {
    final db = FirebaseFirestore.instance;

    // 1. Fetch User Info
    String ownerName = FirebaseAuth.instance.currentUser?.displayName ?? 'Farm Owner';
    try {
      final userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        ownerName = userData?['name'] ??
            userData?['fullName'] ??
            userData?['displayName'] ??
            userData?['farmerName'] ??
            ownerName;
      }
    } catch (_) {}

    Map<String, dynamic> mergedFarm = Map<String, dynamic>.from(farmData);
    try {
      final farmDoc = await db
          .collection('users')
          .doc(userId)
          .collection('farms')
          .doc(farmId)
          .get();
      if (farmDoc.exists && farmDoc.data() != null) {
        mergedFarm = {...mergedFarm, ...farmDoc.data()!};
      }
    } catch (_) {}

    final farmName = (mergedFarm['name'] as String? ?? 'Farm').trim();
    final location = (mergedFarm['address'] as String? ??
            mergedFarm['location'] as String? ??
            'Location not specified')
        .trim();
    double acres = (mergedFarm['acres'] as num?)?.toDouble() ?? 0.0;

    // 2. Fetch Fields
    final List<FarmFieldSummary> fields = [];
    final Set<String> farmFieldIds = {};
    try {
      final fieldsSnap = await db
          .collection('users')
          .doc(userId)
          .collection('fields')
          .where('farmId', isEqualTo: farmId)
          .get();

      var docs = fieldsSnap.docs;
      if (docs.isEmpty) {
        final allFieldsSnap = await db
            .collection('users')
            .doc(userId)
            .collection('fields')
            .get();
        docs = allFieldsSnap.docs.where((d) {
          final fId = d.data()['farmId'];
          return fId == null || fId == farmId;
        }).toList();
      }

      for (final doc in docs) {
        final d = doc.data();
        final fAcres = (d['acres'] as num?)?.toDouble() ?? 0.0;
        farmFieldIds.add(doc.id);
        fields.add(FarmFieldSummary(
          id: doc.id,
          name: d['name'] as String? ?? 'Field',
          acres: fAcres,
          crop: d['crop'] as String?,
        ));
      }

      if (acres <= 0 && fields.isNotEmpty) {
        acres = fields.fold<double>(0.0, (total, f) => total + f.acres);
      }
    } catch (_) {}

    // 3. Fetch Cycles
    final List<FarmCycleSummary> activeCycles = [];
    final List<FarmCycleSummary> completedCycles = [];
    double netIncome = 0.0;
    double totalYield = 0.0;

    String primaryCycleName = 'No active cycle';
    String primaryWeekText = 'N/A';
    String primaryGrowthStage = 'None';
    double primaryGrowthProgress = 0.0;

    try {
      final cycleSnap = await db
          .collection('users')
          .doc(userId)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .get();

      var cycleDocs = cycleSnap.docs;
      if (cycleDocs.isEmpty) {
        final allCycles = await db
            .collection('users')
            .doc(userId)
            .collection('cycles')
            .get();
        cycleDocs = allCycles.docs.where((d) {
          final fId = d.data()['farmId'];
          return fId == null || fId == farmId;
        }).toList();
      }

      for (final doc in cycleDocs) {
        final cData = doc.data();
        final isCompleted = cData['isCompleted'] == true;
        final cName = cData['cycleName'] as String? ?? 'Cycle';
        final cropVariety = (cData['cropVariety'] ?? cData['cropType'] ?? 'Corn').toString();
        final fieldName = (cData['fieldName'] ?? 'Field').toString();
        final plantingDate = _parseNullableDate(cData['plantingDate']);
        final harvestDate = _parseNullableDate(cData['expectedHarvestDate'] ??
            cData['estimatedHarvestDate'] ??
            cData['harvestDate'] ??
            cData['actualHarvestDate']);
        final seedDensity = (cData['seedDensity'] as num?)?.toDouble() ?? 0.0;

        int? dap;
        String weekText = 'N/A';
        String growthStage = cData['statusText'] as String? ?? 'Active';
        double growthProgress = 0.1;

        if (plantingDate != null) {
          dap = DateTime.now().difference(plantingDate).inDays;
          final weekNum = (dap / 7).floor() + 1;
          weekText = 'Week $weekNum';

          if (weekNum <= 2) {
            growthStage = 'Seedling';
            growthProgress = (weekNum / 12).clamp(0.1, 1.0);
          } else if (weekNum <= 6) {
            growthStage = 'Early Vegetative';
            growthProgress = (weekNum / 12).clamp(0.2, 1.0);
          } else if (weekNum <= 9) {
            growthStage = 'Late Vegetative';
            growthProgress = (weekNum / 12).clamp(0.5, 1.0);
          } else if (weekNum <= 11) {
            growthStage = 'Tasseling / Silking';
            growthProgress = (weekNum / 12).clamp(0.75, 1.0);
          } else {
            growthStage = 'Harvesting';
            growthProgress = 1.0;
          }
        }
        if (cData['statusText'] != null) {
          growthStage = cData['statusText'].toString();
        }
        if (cData['progress'] != null) {
          growthProgress = ((cData['progress'] as num).toDouble() / 100.0).clamp(0.0, 1.0);
        }

        final incomeVal = (cData['netIncome'] as num?)?.toDouble() ??
            (cData['income'] as num?)?.toDouble();
        final yieldVal = (cData['totalYield'] as num?)?.toDouble();

        final cycleSummary = FarmCycleSummary(
          id: doc.id,
          cycleName: cName,
          cropVariety: cropVariety,
          fieldName: fieldName,
          plantingDate: plantingDate,
          harvestDate: harvestDate,
          dap: dap,
          weekText: weekText,
          growthStage: growthStage,
          growthProgress: growthProgress,
          seedDensity: seedDensity,
          isCompleted: isCompleted,
          income: incomeVal,
          yieldAmount: yieldVal,
        );

        if (isCompleted) {
          completedCycles.add(cycleSummary);
          if (incomeVal != null) netIncome += incomeVal;
          if (yieldVal != null) totalYield += yieldVal;
        } else {
          activeCycles.add(cycleSummary);
        }
      }

      if (activeCycles.isNotEmpty) {
        final p = activeCycles.first;
        primaryCycleName = '${p.cycleName} | ${p.cropVariety}';
        primaryWeekText = p.weekText;
        primaryGrowthStage = p.growthStage;
        primaryGrowthProgress = p.growthProgress;
      }
    } catch (_) {}

    // 4. Fetch Regular Reports Count
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> regularDocsMap = {};
    try {
      final q1 = await db.collection('reports').where('farmerId', isEqualTo: userId).get();
      for (final doc in q1.docs) {
        regularDocsMap[doc.id] = doc;
      }
    } catch (_) {}
    try {
      final q2 = await db.collection('reports').where('userId', isEqualTo: userId).get();
      for (final doc in q2.docs) {
        regularDocsMap[doc.id] = doc;
      }
    } catch (_) {}
    try {
      final q3 = await db.collection('reports').where('farmId', isEqualTo: farmId).get();
      for (final doc in q3.docs) {
        regularDocsMap[doc.id] = doc;
      }
    } catch (_) {}

    final List<Map<String, dynamic>> farmRegularReports = [];
    for (final doc in regularDocsMap.values) {
      final d = doc.data();
      final docFarmId = d['farmId'] as String?;
      final docFarmName = (d['farmName'] as String?)?.toLowerCase().trim();
      final docFieldId = d['fieldId'] as String?;

      bool matchesFarm = false;
      if (docFarmId != null && docFarmId.isNotEmpty) {
        matchesFarm = (docFarmId == farmId);
      } else if (docFarmName != null && docFarmName.isNotEmpty) {
        matchesFarm = (docFarmName == farmName.toLowerCase().trim());
      } else if (docFieldId != null && farmFieldIds.contains(docFieldId)) {
        matchesFarm = true;
      } else {
        matchesFarm = true;
      }

      if (matchesFarm) {
        farmRegularReports.add(d);
      }
    }

    // 5. Fetch Clustered Reports Count
    final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> clusteredDocsMap = {};
    try {
      final qc1 = await db.collection('clustered_reports').where('farmerId', isEqualTo: userId).get();
      for (final doc in qc1.docs) {
        clusteredDocsMap[doc.id] = doc;
      }
    } catch (_) {}
    try {
      final qc2 = await db.collection('clustered_reports').where('userId', isEqualTo: userId).get();
      for (final doc in qc2.docs) {
        clusteredDocsMap[doc.id] = doc;
      }
    } catch (_) {}
    try {
      final qc3 = await db.collection('clustered_reports').where('farmId', isEqualTo: farmId).get();
      for (final doc in qc3.docs) {
        clusteredDocsMap[doc.id] = doc;
      }
    } catch (_) {}

    final List<Map<String, dynamic>> farmClusteredReports = [];
    for (final doc in clusteredDocsMap.values) {
      final d = doc.data();
      final docFarmId = d['farmId'] as String?;
      final docFarmName = (d['farmName'] as String?)?.toLowerCase().trim();
      final docFieldId = d['fieldId'] as String?;

      bool matchesFarm = false;
      if (docFarmId != null && docFarmId.isNotEmpty) {
        matchesFarm = (docFarmId == farmId);
      } else if (docFarmName != null && docFarmName.isNotEmpty) {
        matchesFarm = (docFarmName == farmName.toLowerCase().trim());
      } else if (docFieldId != null && farmFieldIds.contains(docFieldId)) {
        matchesFarm = true;
      } else {
        matchesFarm = true;
      }

      if (matchesFarm) {
        farmClusteredReports.add(d);
      }
    }

    // 6. Aggregate Surveillance Counts
    final totalRegular = farmRegularReports.length;
    final totalClustered = farmClusteredReports.length;
    final totalCombined = totalRegular + totalClustered;

    int pendingCount = 0;
    int validatedCount = 0;
    int resolvedCount = 0;
    int rejectedCount = 0;
    int highRiskCount = 0;

    for (final r in farmRegularReports) {
      final status = (r['status'] as String? ?? '').toLowerCase();
      final risk = (r['risk'] as String? ?? r['riskLevel'] as String? ?? '').toLowerCase();
      if (status.contains('pend')) pendingCount++;
      if (status.contains('valid')) validatedCount++;
      if (status.contains('resolv')) resolvedCount++;
      if (status.contains('reject')) rejectedCount++;
      if (risk.contains('high') || risk.contains('crit')) highRiskCount++;
    }

    for (final c in farmClusteredReports) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      final exceeds = c['exceedsThreshold'] == true;
      final risk = (c['riskLevel'] as String? ?? '').toLowerCase();
      if (status.contains('pend')) pendingCount++;
      if (status.contains('valid')) validatedCount++;
      if (status.contains('resolv')) resolvedCount++;
      if (status.contains('reject')) rejectedCount++;
      if (exceeds || risk.contains('high')) highRiskCount++;
    }

    return FarmReportData(
      ownerName: ownerName,
      farmName: farmName,
      location: location,
      reportDate: DateTime.now(),
      cycleName: primaryCycleName,
      weekText: primaryWeekText,
      growthStage: primaryGrowthStage,
      growthProgress: primaryGrowthProgress,
      totalReports: totalRegular,
      totalClusteredReports: totalClustered,
      totalCombinedReports: totalCombined,
      pendingReports: pendingCount,
      validatedReports: validatedCount,
      resolvedReports: resolvedCount,
      rejectedReports: rejectedCount,
      highRiskReports: highRiskCount,
      netIncome: netIncome,
      totalYield: totalYield,
      totalFields: fields.length,
      acres: acres,
      fields: fields,
      activeCycles: activeCycles,
      completedCycles: completedCycles,
    );
  }

  /// Generates the concise, executive PDF for a specific farm (info about the farm & report counts)
  static Future<File> generateFarmReportPdf(FarmReportData data) async {
    final pdf = pw.Document(theme: await PdfThemeService.load());

    final dateStr = DateFormat('MMMM dd, yyyy').format(data.reportDate);
    final progressPercent = (data.growthProgress * 100).round();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.SizedBox(height: 0);
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FARM REPORT • ${data.farmName}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                pw.Text(
                  dateStr,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated automatically by VISAIA Smart Farm Monitoring',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // ── Title Header ──
          pw.Center(
            child: pw.Text(
              'FARM REPORT',
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                color: _darkGreen,
                letterSpacing: 0.5,
              ),
            ),
          ),
          pw.SizedBox(height: 6),

          pw.Container(
            height: 3,
            color: _darkGreen,
            margin: const pw.EdgeInsets.symmetric(horizontal: 10),
          ),
          pw.SizedBox(height: 8),

          pw.Center(
            child: pw.Text(
              'Summary of Farm Performance and Key Data Points',
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: _darkGreen,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Table 1: Farm Information ──
          _buildSectionTable(
            headerTitle: 'Farm Information',
            headerBgColor: _darkGreen,
            headerTextColor: PdfColors.white,
            rows: [
              ['Farm Owner', data.ownerName],
              ['Farm Name', data.farmName],
              ['Location', data.location],
              ['Total Area', '${data.acres.toStringAsFixed(1)} Acres'],
              ['Registered Fields', '${data.totalFields} Fields'],
              ['Report Date', dateStr],
            ],
          ),
          pw.SizedBox(height: 18),

          // ── Table 2: Active Cycle Status ──
          _buildActiveCycleTable(
            headerTitle: 'Active Cycle Status',
            headerBgColor: _lightSage,
            headerTextColor: _darkGreen,
            data: data,
            progressPercent: progressPercent,
          ),
          pw.SizedBox(height: 18),

          // ── Table 3: Fall Armyworm & Pest Surveillance Reports (Counts) ──
          _buildSectionTable(
            headerTitle: 'Fall Armyworm & Pest Surveillance Reports',
            headerBgColor: _lightSage,
            headerTextColor: _darkGreen,
            rows: [
              ['Total Preliminary AI Reports', '${data.totalReports} Reports'],
              ['Field Scouting (Clustered) Reports', '${data.totalClusteredReports} Reports'],
              ['Total Surveillance Reports', '${data.totalCombinedReports} Reports'],
              ['Pending Expert Validation', '${data.pendingReports} Reports'],
              [
                'Validated Reports (DA-RCPC)',
                '${data.validatedReports} ${data.validatedReports == 1 ? 'Report' : 'Reports'}'
              ],
              ['Resolved Reports', '${data.resolvedReports} Reports'],
              ['High Risk / Economic Threshold Alerts', '${data.highRiskReports} Reports'],
            ],
          ),
          pw.SizedBox(height: 18),

          // ── Production & Financials (if recorded) ──
          if (data.totalYield > 0 || data.netIncome > 0) ...[
            _buildSectionTable(
              headerTitle: 'Production & Financial Summary',
              headerBgColor: _lightSage,
              headerTextColor: _darkGreen,
              rows: [
                ['Completed Crop Cycles', '${data.completedCycles.length} Cycles'],
                ['Total Harvest Yield', '${NumberFormat('#,##0.#').format(data.totalYield)} Tons'],
                ['Consolidated Net Income', 'PHP ${NumberFormat('#,##0.00').format(data.netIncome)}'],
              ],
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Registered Fields (if fields exist) ──
          if (data.fields.isNotEmpty) ...[
            _buildSectionTable(
              headerTitle: 'Registered Fields Breakdown',
              headerBgColor: _lightSage,
              headerTextColor: _darkGreen,
              rows: data.fields.map((f) {
                return [
                  f.name,
                  '${f.acres.toStringAsFixed(2)} Acres • ${f.crop ?? 'Corn Variety'}',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
          ],

          // ── Official Verification Notice ──
          _buildOfficialVerificationNotice(),
          pw.SizedBox(height: 8),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final sanitizedName =
        data.farmName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final file = File(
        '${output.path}/farm_report_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // PDF WIDGET BUILDERS
  // ══════════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildOfficialVerificationNotice() {
    final genTimeStr = DateFormat('MMMM dd, yyyy • hh:mm a').format(DateTime.now());
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'VISAIA SMART AGRICULTURAL SURVEILLANCE & DA-RCPC VERIFICATION',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              pw.Text(
                genTimeStr,
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Official consolidated farm performance report in alignment with Department of Agriculture - '
            'Regional Crop Protection Center (DA-RCPC) standards.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTable({
    required String headerTitle,
    required PdfColor headerBgColor,
    required PdfColor headerTextColor,
    required List<List<String>> rows,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 1),
      ),
      child: pw.Column(
        children: [
          // Header Bar
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            color: headerBgColor,
            alignment: pw.Alignment.center,
            child: pw.Text(
              headerTitle,
              style: pw.TextStyle(
                color: headerTextColor,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          // Rows
          ...rows.map((row) {
            return pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 1)),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(color: _borderGrey, width: 1)),
                      ),
                      child: pw.Text(
                        row[0],
                        style: pw.TextStyle(
                          fontSize: 10.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: pw.Text(
                        row[1],
                        style: const pw.TextStyle(
                          fontSize: 10.5,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _buildActiveCycleTable({
    required String headerTitle,
    required PdfColor headerBgColor,
    required PdfColor headerTextColor,
    required FarmReportData data,
    required int progressPercent,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderGrey, width: 1),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            color: headerBgColor,
            alignment: pw.Alignment.center,
            child: pw.Text(
              headerTitle,
              style: pw.TextStyle(
                color: headerTextColor,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          _buildTableRow('Cycle About to Harvest', data.cycleName),
          _buildTableRow('Week', data.weekText),
          _buildTableRow('Growth Stage', data.growthStage),
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 1)),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(color: _borderGrey, width: 1)),
                    ),
                    child: pw.Text(
                      'Growth Progress',
                      style: pw.TextStyle(
                        fontSize: 10.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Stack(
                            children: [
                              pw.Container(
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.grey300,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                              pw.Container(
                                width: 140 * data.growthProgress.clamp(0.05, 1.0),
                                height: 8,
                                decoration: pw.BoxDecoration(
                                  color: _darkGreen,
                                  borderRadius: pw.BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          '$progressPercent%',
                          style: pw.TextStyle(
                            fontSize: 10.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _darkGreen,
                          ),
                        ),
                      ],
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

  static pw.Widget _buildTableRow(String label, String value) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: _borderGrey, width: 1)),
              ),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: pw.Text(
                value,
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // EXPORT AND SHARE METHODS
  // ══════════════════════════════════════════════════════════════════════════════

  /// Exports and shares the Farm Report PDF
  static Future<void> exportAndShareFarmReport({
    required String userId,
    required String farmId,
    required Map<String, dynamic> farmData,
  }) async {
    final data = await fetchFarmReportData(
      userId: userId,
      farmId: farmId,
      farmData: farmData,
    );

    final file = await generateFarmReportPdf(data);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Farm Report - ${data.farmName}',
      ),
    );
  }

  /// Exports Farm Data to CSV and shares it
  static Future<void> exportAndShareCsv({
    required String userId,
    required String farmId,
    required Map<String, dynamic> farmData,
  }) async {
    final data = await fetchFarmReportData(
      userId: userId,
      farmId: farmId,
      farmData: farmData,
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(data.reportDate);
    final progressPercent = (data.growthProgress * 100).round();

    final buffer = StringBuffer();
    buffer.writeln('VISAIA FARM REPORT');
    buffer.writeln('Report Date,$dateStr');
    buffer.writeln('');
    buffer.writeln('FARM INFORMATION');
    buffer.writeln('Farm Owner,"${data.ownerName}"');
    buffer.writeln('Farm Name,"${data.farmName}"');
    buffer.writeln('Location,"${data.location}"');
    buffer.writeln('Acres,${data.acres}');
    buffer.writeln('Total Fields,${data.totalFields}');
    buffer.writeln('');
    buffer.writeln('ACTIVE CYCLE STATUS');
    buffer.writeln('Cycle About to Harvest,"${data.cycleName}"');
    buffer.writeln('Week,"${data.weekText}"');
    buffer.writeln('Growth Stage,"${data.growthStage}"');
    buffer.writeln('Growth Progress,"$progressPercent%"');
    buffer.writeln('');
    buffer.writeln('PEST SURVEILLANCE & AI REPORTS OVERVIEW');
    buffer.writeln('Total Preliminary AI Reports,${data.totalReports}');
    buffer.writeln('Field Scouting (Clustered) Reports,${data.totalClusteredReports}');
    buffer.writeln('Total Combined Reports,${data.totalCombinedReports}');
    buffer.writeln('Pending Expert Validation,${data.pendingReports}');
    buffer.writeln('Validated Reports (DA-RCPC),${data.validatedReports}');
    buffer.writeln('Resolved Reports,${data.resolvedReports}');
    buffer.writeln('High Risk / Economic Threshold Alerts,${data.highRiskReports}');
    buffer.writeln('');
    buffer.writeln('FINANCIALS & PRODUCTION');
    buffer.writeln('Net Income (PHP),${data.netIncome}');
    buffer.writeln('Total Yield (Tons),${data.totalYield}');

    if (data.fields.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('REGISTERED FIELDS');
      buffer.writeln('Field Name,Acres,Crop');
      for (final f in data.fields) {
        buffer.writeln('"${f.name}",${f.acres},"${f.crop ?? ''}"');
      }
    }

    final output = await getTemporaryDirectory();
    final sanitizedName =
        data.farmName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final file = File(
        '${output.path}/farm_data_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Farm Data CSV - ${data.farmName}',
      ),
    );
  }

  /// Exports General Summary of all Farmlands (info about all farms & surveillance counts)
  static Future<void> exportAndShareGeneralData({
    required String userId,
    required double totalIncome,
    required double totalYield,
    required int activeCycles,
    required double totalAcres,
    required List<Map<String, dynamic>> allFarms,
  }) async {
    final pdf = pw.Document(theme: await PdfThemeService.load());
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM dd, yyyy').format(now);
    final db = FirebaseFirestore.instance;

    // 1. Fetch User Info
    String ownerName = FirebaseAuth.instance.currentUser?.displayName ?? 'Farm Owner';
    try {
      final userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        ownerName = userData?['name'] ??
            userData?['fullName'] ??
            userData?['displayName'] ??
            ownerName;
      }
    } catch (_) {}

    // 2. Fetch all Regular Reports across all farms
    final Map<String, Map<String, dynamic>> allRegularMap = {};
    try {
      final r1 = await db.collection('reports').where('farmerId', isEqualTo: userId).get();
      for (final doc in r1.docs) {
        allRegularMap[doc.id] = doc.data();
      }
    } catch (_) {}
    try {
      final r2 = await db.collection('reports').where('userId', isEqualTo: userId).get();
      for (final doc in r2.docs) {
        allRegularMap[doc.id] = doc.data();
      }
    } catch (_) {}

    // 3. Fetch all Clustered Reports across all farms
    final Map<String, Map<String, dynamic>> allClusteredMap = {};
    try {
      final c1 = await db.collection('clustered_reports').where('farmerId', isEqualTo: userId).get();
      for (final doc in c1.docs) {
        allClusteredMap[doc.id] = doc.data();
      }
    } catch (_) {}
    try {
      final c2 = await db.collection('clustered_reports').where('userId', isEqualTo: userId).get();
      for (final doc in c2.docs) {
        allClusteredMap[doc.id] = doc.data();
      }
    } catch (_) {}

    // 4. Aggregate metrics across all farms
    final totalRegular = allRegularMap.length;
    final totalClustered = allClusteredMap.length;
    final totalCombined = totalRegular + totalClustered;

    int pendingCount = 0;
    int validatedCount = 0;
    int resolvedCount = 0;
    int highRiskCount = 0;

    for (final r in allRegularMap.values) {
      final status = (r['status'] as String? ?? '').toLowerCase();
      final risk = (r['risk'] as String? ?? r['riskLevel'] as String? ?? '').toLowerCase();
      if (status.contains('pend')) pendingCount++;
      if (status.contains('valid')) validatedCount++;
      if (status.contains('resolv')) resolvedCount++;
      if (risk.contains('high') || risk.contains('crit')) highRiskCount++;
    }

    for (final c in allClusteredMap.values) {
      final status = (c['status'] as String? ?? '').toLowerCase();
      final exceeds = c['exceedsThreshold'] == true;
      final risk = (c['riskLevel'] as String? ?? '').toLowerCase();
      if (status.contains('pend')) pendingCount++;
      if (status.contains('valid')) validatedCount++;
      if (status.contains('resolv')) resolvedCount++;
      if (exceeds || risk.contains('high')) highRiskCount++;
    }

    // 5. Build PDF document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.SizedBox(height: 0);
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ALL FARMLANDS GENERAL REPORT',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
                pw.Text(
                  dateStr,
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated automatically by VISAIA Smart Farm Monitoring',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) => [
          // Title
          pw.Center(
            child: pw.Text(
              'ALL FARMLANDS GENERAL REPORT',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _darkGreen,
              ),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(height: 2.5, color: _darkGreen),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Consolidated Summary of All Agricultural Operations & Surveillance • $dateStr',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _darkGreen,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // Table 1: General Overview
          _buildSectionTable(
            headerTitle: 'General Overview',
            headerBgColor: _darkGreen,
            headerTextColor: PdfColors.white,
            rows: [
              ['Farmer / Owner', ownerName],
              ['Total Registered Farmlands', '${allFarms.length} Farms'],
              ['Total Acreage', '${totalAcres.toStringAsFixed(1)} Acres'],
              ['Active Crop Cycles', '$activeCycles Ongoing'],
              ['Consolidated Net Income', 'PHP ${NumberFormat('#,##0').format(totalIncome)}'],
              ['Total Harvest Yield', '${NumberFormat('#,##0.#').format(totalYield)} Tons'],
            ],
          ),
          pw.SizedBox(height: 18),

          // Table 2: Consolidated Pest Surveillance & Scouting Summary (Counts)
          _buildSectionTable(
            headerTitle: 'Consolidated Surveillance & Pest Scouting Summary',
            headerBgColor: _lightSage,
            headerTextColor: _darkGreen,
            rows: [
              ['Total Preliminary AI Reports', '$totalRegular Reports'],
              ['Field Scouting (Clustered) Reports', '$totalClustered Reports'],
              ['Total Surveillance Reports', '$totalCombined Reports'],
              ['Pending Expert Validation', '$pendingCount Reports'],
              ['Validated Reports (DA-RCPC)', '$validatedCount Reports'],
              ['Resolved Reports', '$resolvedCount Reports'],
              ['High Risk / Economic Threshold Alerts', '$highRiskCount Incidents'],
            ],
          ),
          pw.SizedBox(height: 18),

          // Table 3: Registered Farmlands Directory
          if (allFarms.isNotEmpty) ...[
            _buildSectionTable(
              headerTitle: 'Registered Farmlands Directory',
              headerBgColor: _lightSage,
              headerTextColor: _darkGreen,
              rows: allFarms.map((farm) {
                final name = farm['name'] ?? 'Farm';
                final loc = farm['address'] ?? farm['location'] ?? 'Location not specified';
                final acres = (farm['acres'] as num?)?.toDouble() ?? 0.0;
                return [
                  name.toString(),
                  '$loc • ${acres.toStringAsFixed(1)} Acres',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 18),
          ],

          // Official Verification Notice
          _buildOfficialVerificationNotice(),
          pw.SizedBox(height: 8),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final file =
        File('${output.path}/general_farm_data_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'VISAIA General Farm Report - $dateStr',
      ),
    );
  }
}
