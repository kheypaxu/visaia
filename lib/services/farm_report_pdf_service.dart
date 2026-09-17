import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';


class FarmReportData {
  final String ownerName;
  final String farmName;
  final String location;
  final DateTime reportDate;

  // Active Cycle
  final String cycleName;
  final String weekText;
  final String growthStage;
  final double growthProgress; // 0.0 to 1.0

  // FAW Reports
  final int totalReports;
  final int pendingReports;
  final int validatedReports;
  final int resolvedReports;

  // Extra metrics
  final double netIncome;
  final double totalYield;
  final int totalFields;
  final double acres;

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
    this.netIncome = 0,
    this.totalYield = 0,
    this.totalFields = 0,
    this.acres = 0,
  });
}

class FarmReportPdfService {
  static const PdfColor _darkGreen = PdfColor.fromInt(0xFF084C23);
  static const PdfColor _lightSage = PdfColor.fromInt(0xFFD6E3D1);
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFFD0D7CF);

  /// Fetches all required data from Firestore for a specific farm
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
            ownerName;
      }
    } catch (_) {}

    final farmName = farmData['name'] as String? ?? 'Farm';
    final location = farmData['address'] as String? ??
        farmData['location'] as String? ??
        'Location not specified';
    final acres = (farmData['acres'] as num?)?.toDouble() ?? 0.0;

    // 2. Fetch Active Cycle
    String cycleName = 'No active cycle';
    String weekText = 'N/A';
    String growthStage = 'None';
    double growthProgress = 0.0;

    try {
      final cycleSnap = await db
          .collection('users')
          .doc(userId)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (cycleSnap.docs.isNotEmpty) {
        final cData = cycleSnap.docs.first.data();
        final cName = cData['cycleName'] ?? 'Current Cycle';
        final cropVariety = cData['cropVariety'] ?? cData['cropType'] ?? 'Corn';
        cycleName = '$cName | $cropVariety';

        final plantingDate = (cData['plantingDate'] as Timestamp?)?.toDate();
        if (plantingDate != null) {
          final days = DateTime.now().difference(plantingDate).inDays;
          final weekNum = (days / 7).floor() + 1;
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
          growthStage = cData['statusText'];
        }
        if (cData['progress'] != null) {
          growthProgress = ((cData['progress'] as num).toDouble() / 100.0).clamp(0.0, 1.0);
        }
      }
    } catch (_) {}

    // 3. Fetch FAW Reports
    int totalReports = 0;
    int pendingReports = 0;
    int validatedReports = 0;
    int resolvedReports = 0;

    try {
      final reportsSnap = await db
          .collection('reports')
          .where('farmerId', isEqualTo: userId)
          .get();

      final farmReports = reportsSnap.docs.where((doc) {
        final d = doc.data();
        return d['farmId'] == null || d['farmId'] == farmId;
      }).toList();

      totalReports = farmReports.length;
      for (final r in farmReports) {
        final status = (r.data()['status'] as String? ?? '').toLowerCase();
        if (status.contains('pending')) {
          pendingReports++;
        } else if (status.contains('validate')) {
          validatedReports++;
        } else if (status.contains('resolve')) {
          resolvedReports++;
        }
      }
    } catch (_) {}

    // 4. Fetch Fields Count
    int totalFields = 0;
    try {
      final fieldsSnap = await db
          .collection('users')
          .doc(userId)
          .collection('fields')
          .where('farmId', isEqualTo: farmId)
          .get();
      totalFields = fieldsSnap.docs.length;
    } catch (_) {}

    // 5. Fetch Completed Yield & Income
    double netIncome = 0;
    double totalYield = 0;
    try {
      final completedSnap = await db
          .collection('users')
          .doc(userId)
          .collection('cycles')
          .where('farmId', isEqualTo: farmId)
          .where('isCompleted', isEqualTo: true)
          .get();

      for (final doc in completedSnap.docs) {
        final data = doc.data();
        netIncome += (data['netIncome'] as num?)?.toDouble() ??
            (data['income'] as num?)?.toDouble() ??
            0;
        totalYield += (data['totalYield'] as num?)?.toDouble() ?? 0;
      }
    } catch (_) {}

    return FarmReportData(
      ownerName: ownerName,
      farmName: farmName,
      location: location,
      reportDate: DateTime.now(),
      cycleName: cycleName,
      weekText: weekText,
      growthStage: growthStage,
      growthProgress: growthProgress,
      totalReports: totalReports,
      pendingReports: pendingReports,
      validatedReports: validatedReports,
      resolvedReports: resolvedReports,
      netIncome: netIncome,
      totalYield: totalYield,
      totalFields: totalFields,
      acres: acres,
    );
  }

  /// Generates the exact PDF matching the UI template in the mockup
  static Future<File> generateFarmReportPdf(FarmReportData data) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('MMMM dd, yyyy').format(data.reportDate);
    final progressPercent = (data.growthProgress * 100).round();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // ── Header Title ──
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

              // Green separator bar
              pw.Container(
                height: 3,
                color: _darkGreen,
                margin: const pw.EdgeInsets.symmetric(horizontal: 10),
              ),
              pw.SizedBox(height: 8),

              // Subtitle
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
              pw.SizedBox(height: 22),

              // ── Table 1: Farm Information ──
              _buildSectionTable(
                headerTitle: 'Farm Information',
                headerBgColor: _darkGreen,
                headerTextColor: PdfColors.white,
                rows: [
                  ['Farm Owner', data.ownerName],
                  ['Farm Name', data.farmName],
                  ['Location', data.location],
                  ['Report Date', dateStr],
                ],
              ),
              pw.SizedBox(height: 20),

              // ── Table 2: Active Cycle Status ──
              _buildActiveCycleTable(
                headerTitle: 'Active Cycle Status',
                headerBgColor: _lightSage,
                headerTextColor: _darkGreen,
                data: data,
                progressPercent: progressPercent,
              ),
              pw.SizedBox(height: 20),

              // ── Table 3: Fall Armyworm Reports ──
              _buildSectionTable(
                headerTitle: 'Fall Armyworm Reports',
                headerBgColor: _lightSage,
                headerTextColor: _darkGreen,
                rows: [
                  ['Total Report', '${data.totalReports} Reports'],
                  ['Pending Report', '${data.pendingReports} Reports'],
                  ['Validated Report', '${data.validatedReports} ${data.validatedReports == 1 ? 'Report' : 'Reports'}'],
                  ['Resolved Report', '${data.resolvedReports} Reports'],
                ],
              ),

              pw.Spacer(),
              // Footer
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.only(top: 10),
                child: pw.Text(
                  'Generated automatically by VISAIA Smart Farm Monitoring',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final sanitizedName = data.farmName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final file = File('${output.path}/farm_report_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
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
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(right: pw.BorderSide(color: _borderGrey, width: 1)),
                      ),
                      child: pw.Text(
                        row[0],
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: pw.Text(
                        row[1],
                        style: const pw.TextStyle(
                          fontSize: 11,
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
          // Row 1: Cycle About to Harvest
          _buildTableRow('Cycle About to Harvest', data.cycleName),
          // Row 2: Week
          _buildTableRow('Week', data.weekText),
          // Row 3: Growth Stage
          _buildTableRow('Growth Stage', data.growthStage),
          // Row 4: Growth Progress (with progress bar)
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _borderGrey, width: 1)),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 4,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(right: pw.BorderSide(color: _borderGrey, width: 1)),
                    ),
                    child: pw.Text(
                      'Growth Progess',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  flex: 5,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: pw.Row(
                      children: [
                        // Progress bar container
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
                            fontSize: 11,
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const pw.BoxDecoration(
                border: pw.Border(right: pw.BorderSide(color: _borderGrey, width: 1)),
              ),
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: pw.Text(
                value,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
    buffer.writeln('Report Date,${dateStr}');
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
    buffer.writeln('Growth Progress,"${progressPercent}%"');
    buffer.writeln('');
    buffer.writeln('FALL ARMYWORM REPORTS');
    buffer.writeln('Total Reports,${data.totalReports}');
    buffer.writeln('Pending Reports,${data.pendingReports}');
    buffer.writeln('Validated Reports,${data.validatedReports}');
    buffer.writeln('Resolved Reports,${data.resolvedReports}');
    buffer.writeln('');
    buffer.writeln('FINANCIALS & PRODUCTION');
    buffer.writeln('Net Income (PHP),${data.netIncome}');
    buffer.writeln('Total Yield (Tons/Kg),${data.totalYield}');

    final output = await getTemporaryDirectory();
    final sanitizedName = data.farmName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final file = File('${output.path}/farm_data_${sanitizedName}_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Farm Data CSV - ${data.farmName}',
      ),
    );
  }

  /// Exports General Summary of all Farmlands
  static Future<void> exportAndShareGeneralData({
    required String userId,
    required double totalIncome,
    required double totalYield,
    required int activeCycles,
    required double totalAcres,
    required List<Map<String, dynamic>> allFarms,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('MMMM dd, yyyy').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  'ALL FARMLANDS GENERAL REPORT',
                  style: pw.TextStyle(
                    fontSize: 22,
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
                  'Consolidated Summary of All Agricultural Operations • $dateStr',
                  style: pw.TextStyle(
                    fontSize: 11.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkGreen,
                  ),
                ),
              ),
              pw.SizedBox(height: 22),

              _buildSectionTable(
                headerTitle: 'General Overview',
                headerBgColor: _darkGreen,
                headerTextColor: PdfColors.white,
                rows: [
                  ['Total Farmlands', '${allFarms.length} Farms'],
                  ['Total Acreage', '${totalAcres.toStringAsFixed(1)} Acres'],
                  ['Active Crop Cycles', '$activeCycles Ongoing'],
                  ['Consolidated Net Income', '\u20B1${NumberFormat('#,##0').format(totalIncome)}'],
                  ['Total Harvest Yield', '${NumberFormat('#,##0.#').format(totalYield)} Tons'],
                ],
              ),
              pw.SizedBox(height: 20),

              if (allFarms.isNotEmpty)
                _buildSectionTable(
                  headerTitle: 'Registered Farmlands',
                  headerBgColor: _lightSage,
                  headerTextColor: _darkGreen,
                  rows: allFarms.map((farm) {
                    final name = farm['name'] ?? 'Farm';
                    final acres = (farm['acres'] as num?)?.toDouble() ?? 0.0;
                    return [name.toString(), '${acres.toStringAsFixed(1)} Acres'];
                  }).toList(),
                ),

              pw.Spacer(),
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Generated automatically by VISAIA Smart Farm Monitoring System',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/general_farm_data_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'VISAIA General Farm Report - $dateStr',
      ),
    );
  }
}
