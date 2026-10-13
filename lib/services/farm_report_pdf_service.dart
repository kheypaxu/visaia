import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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

class ClusteredReportSummary {
  final String id;
  final DateTime reportDate;
  final String fieldName;
  final String growthStage;
  final int? dap;
  final int? weekNumber;
  final int totalInspected;
  final int totalDamaged;
  final double damagePercentage;
  final bool exceedsThreshold;
  final String riskLevel;
  final String reportLevel;
  final String status;
  final int eggs;
  final int larvae;
  final int pupae;
  final int moths;
  final String? controlMethod;
  final bool? trapsInstalled;
  final double? avgWhorlScore;
  final double? avgCobScore;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? expertDiagnosis;
  final String? advisoryMessage;
  final String? rejectionReason;
  final String? resolutionExplanation;
  final String? managementActionTaken;
  final DateTime? resolvedAt;

  ClusteredReportSummary({
    required this.id,
    required this.reportDate,
    required this.fieldName,
    required this.growthStage,
    this.dap,
    this.weekNumber,
    required this.totalInspected,
    required this.totalDamaged,
    required this.damagePercentage,
    required this.exceedsThreshold,
    required this.riskLevel,
    required this.reportLevel,
    required this.status,
    this.eggs = 0,
    this.larvae = 0,
    this.pupae = 0,
    this.moths = 0,
    this.controlMethod,
    this.trapsInstalled,
    this.avgWhorlScore,
    this.avgCobScore,
    this.validatedBy,
    this.validatedAt,
    this.expertDiagnosis,
    this.advisoryMessage,
    this.rejectionReason,
    this.resolutionExplanation,
    this.managementActionTaken,
    this.resolvedAt,
  });
}

class RegularReportSummary {
  final String id;
  final DateTime reportDate;
  final String fieldName;
  final String detection;
  final String? scientificName;
  final String? lifeStage;
  final String? cropAffected;
  final double? confidence;
  final String risk;
  final String status;
  final String? validatedBy;
  final DateTime? validatedAt;
  final String? expertDiagnosis;
  final String? advisoryMessage;
  final String? rejectionReason;
  final String? resolutionExplanation;
  final String? managementActionTaken;
  final DateTime? resolvedAt;

  RegularReportSummary({
    required this.id,
    required this.reportDate,
    required this.fieldName,
    required this.detection,
    this.scientificName,
    this.lifeStage,
    this.cropAffected,
    this.confidence,
    required this.risk,
    required this.status,
    this.validatedBy,
    this.validatedAt,
    this.expertDiagnosis,
    this.advisoryMessage,
    this.rejectionReason,
    this.resolutionExplanation,
    this.managementActionTaken,
    this.resolvedAt,
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

  // Surveillance counts
  final int totalReports; // preliminary AI reports
  final int totalClusteredReports; // field scouting reports
  final int totalCombinedReports; // total of all reports
  final int pendingReports;
  final int validatedReports;
  final int resolvedReports;
  final int rejectedReports;
  final int highRiskReports;

  // Extra metrics
  final double netIncome;
  final double totalYield;
  final int totalFields;
  final double acres;

  // Detailed breakdown lists
  final List<FarmFieldSummary> fields;
  final List<FarmCycleSummary> activeCycles;
  final List<FarmCycleSummary> completedCycles;
  final List<ClusteredReportSummary> clusteredReports;
  final List<RegularReportSummary> regularReports;

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
    this.clusteredReports = const [],
    this.regularReports = const [],
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// SERVICE IMPLEMENTATION
// ══════════════════════════════════════════════════════════════════════════════

class FarmReportPdfService {
  static const PdfColor _darkGreen = PdfColor.fromInt(0xFF084C23);
  static const PdfColor _lightSage = PdfColor.fromInt(0xFFD6E3D1);
  static const PdfColor _borderGrey = PdfColor.fromInt(0xFFD0D7CF);
  static const PdfColor _cardBg = PdfColor.fromInt(0xFFF9FAF8);
  static const PdfColor _subtleBg = PdfColor.fromInt(0xFFF0F4EF);

  static const PdfColor _badgeGreenBg = PdfColor.fromInt(0xFFE8F5E9);
  static const PdfColor _badgeGreenText = PdfColor.fromInt(0xFF1B5E20);
  static const PdfColor _badgeAmberBg = PdfColor.fromInt(0xFFFFF3E0);
  static const PdfColor _badgeAmberText = PdfColor.fromInt(0xFFE65100);
  static const PdfColor _badgeBlueBg = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _badgeBlueText = PdfColor.fromInt(0xFF0D47A1);
  static const PdfColor _badgeRedBg = PdfColor.fromInt(0xFFFFEBEE);
  static const PdfColor _badgeRedText = PdfColor.fromInt(0xFFC62828);

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  static int? _extractInt(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toInt();
    if (val is String) {
      final match = RegExp(r'\d+').firstMatch(val);
      if (match != null) return int.tryParse(match.group(0)!);
    }
    return null;
  }

  /// Fetches comprehensive farm data from Firestore: profile, fields, cycles,
  /// regular AI pest reports, and field scouting clustered reports.
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
    } catch (e) {
      debugPrint('Error fetching user info: $e');
    }

    // Merge latest farm doc if available
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
        // Fallback: check all fields for user
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

      // If farm acres was 0, calculate sum of fields
      if (acres <= 0 && fields.isNotEmpty) {
        acres = fields.fold<double>(0.0, (total, f) => total + f.acres);
      }
    } catch (e) {
      debugPrint('Error fetching fields: $e');
    }

    // 3. Fetch Cycles (Active & Completed)
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
    } catch (e) {
      debugPrint('Error fetching cycles: $e');
    }

    // 4. Fetch Regular Reports (AI Scans)
    final List<RegularReportSummary> regularReports = [];
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
        matchesFarm = true; // User's report with default assignment
      }

      if (!matchesFarm) continue;

      final ts = _parseDate(d['dateConducted'] ??
          d['scoutingDate'] ??
          d['submittedAt'] ??
          d['timestamp'] ??
          d['createdAt']);

      final detection = (d['detection'] ?? d['originalDetection'] ?? 'Fall Armyworm').toString();
      final scientificName = d['scientificName'] as String? ?? 'Spodoptera frugiperda';
      final lifeStage = (d['lifeStage'] ?? d['originalLifeStage']) as String?;
      final cropAffected = (d['cropAffected'] ?? 'Corn').toString();
      final confidence = (d['confidence'] as num?)?.toDouble();
      final risk = (d['risk'] ?? d['riskLevel'] ?? 'Low').toString();
      final status = (d['status'] ?? 'pending').toString().toLowerCase();

      regularReports.add(RegularReportSummary(
        id: doc.id,
        reportDate: ts,
        fieldName: (d['fieldName'] ?? d['areaName'] ?? 'Field').toString(),
        detection: detection,
        scientificName: scientificName,
        lifeStage: lifeStage,
        cropAffected: cropAffected,
        confidence: confidence,
        risk: risk,
        status: status,
        validatedBy: d['validatedBy'] as String?,
        validatedAt: _parseNullableDate(d['validatedAt']),
        expertDiagnosis: d['expertDiagnosis'] as String?,
        advisoryMessage: d['advisoryMessage'] as String?,
        rejectionReason: (d['rejectionReason'] ?? d['validationNotes']) as String?,
        resolutionExplanation: d['resolutionExplanation'] as String?,
        managementActionTaken: d['managementActionTaken'] as String?,
        resolvedAt: _parseNullableDate(d['resolvedAt']),
      ));
    }

    // Sort regular reports descending by date
    regularReports.sort((a, b) => b.reportDate.compareTo(a.reportDate));

    // 5. Fetch Clustered Reports (Field Scouting)
    final List<ClusteredReportSummary> clusteredReports = [];
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

      if (!matchesFarm) continue;

      final ts = _parseDate(d['reportDate'] ??
          d['timestamp'] ??
          d['createdAt'] ??
          d['submittedAt'] ??
          d['dateConducted'] ??
          d['scoutingDate']);

      final growthStage = (d['growthStage'] ?? 'Corn').toString();
      final dap = _extractInt(d['dap']);
      final weekNumber = _extractInt(d['weekNumber']);

      final totalInspected = (d['correctedInspected'] as num?)?.toInt() ??
          (d['totalInspected'] as num?)?.toInt() ??
          100;
      final totalDamaged = (d['correctedDamaged'] as num?)?.toInt() ??
          (d['totalDamaged'] as num?)?.toInt() ??
          0;
      final damagePercentage = (d['damagePercentage'] as num?)?.toDouble() ??
          (totalInspected > 0 ? (totalDamaged / totalInspected) * 100 : 0.0);
      final exceedsThreshold = d['exceedsThreshold'] == true || damagePercentage >= 10.0;

      final riskLevel = (d['correctedRisk'] ??
              d['riskLevel'] ??
              d['severityLevel'] ??
              (exceedsThreshold ? 'High' : 'Moderate'))
          .toString();
      final reportLevel = (d['reportLevel'] ?? (exceedsThreshold ? 'High-level' : 'Low-level')).toString();
      final status = (d['status'] ?? 'pending').toString().toLowerCase();

      final totals = (d['correctedTotals'] as Map<String, dynamic>?) ??
          (d['totals'] as Map<String, dynamic>?) ??
          {};
      final eggs = (totals['eggs'] as num?)?.toInt() ?? 0;
      final larvae = (totals['larvae'] as num?)?.toInt() ?? 0;
      final pupae = (totals['pupae'] as num?)?.toInt() ?? 0;
      final moths = (totals['moths'] as num?)?.toInt() ?? 0;

      final damageAssessment = d['damageAssessment'] as Map<String, dynamic>?;
      final avgWhorl = (damageAssessment?['averageWhorlLeafScore'] as num?)?.toDouble();
      final avgCob = (damageAssessment?['averageCobScore'] as num?)?.toDouble();

      clusteredReports.add(ClusteredReportSummary(
        id: doc.id,
        reportDate: ts,
        fieldName: (d['fieldName'] ?? 'Field').toString(),
        growthStage: growthStage,
        dap: dap,
        weekNumber: weekNumber,
        totalInspected: totalInspected,
        totalDamaged: totalDamaged,
        damagePercentage: damagePercentage,
        exceedsThreshold: exceedsThreshold,
        riskLevel: riskLevel,
        reportLevel: reportLevel,
        status: status,
        eggs: eggs,
        larvae: larvae,
        pupae: pupae,
        moths: moths,
        controlMethod: d['controlMethod'] as String?,
        trapsInstalled: d['trapsInstalled'] as bool?,
        avgWhorlScore: avgWhorl,
        avgCobScore: avgCob,
        validatedBy: d['validatedBy'] as String?,
        validatedAt: _parseNullableDate(d['validatedAt']),
        expertDiagnosis: d['expertDiagnosis'] as String?,
        advisoryMessage: d['advisoryMessage'] as String?,
        rejectionReason: (d['rejectionReason'] ?? d['validationNotes']) as String?,
        resolutionExplanation: d['resolutionExplanation'] as String?,
        managementActionTaken: d['managementActionTaken'] as String?,
        resolvedAt: _parseNullableDate(d['resolvedAt']),
      ));
    }

    // Sort clustered reports descending by date
    clusteredReports.sort((a, b) => b.reportDate.compareTo(a.reportDate));

    // 6. Aggregate Totals
    final totalRegular = regularReports.length;
    final totalClustered = clusteredReports.length;
    final totalCombined = totalRegular + totalClustered;

    int pendingCount = 0;
    int validatedCount = 0;
    int resolvedCount = 0;
    int rejectedCount = 0;
    int highRiskCount = 0;

    for (final r in regularReports) {
      if (r.status.contains('pend')) pendingCount++;
      if (r.status.contains('valid')) validatedCount++;
      if (r.status.contains('resolv')) resolvedCount++;
      if (r.status.contains('reject')) rejectedCount++;
      if (r.risk.toLowerCase().contains('high') || r.risk.toLowerCase().contains('crit')) {
        highRiskCount++;
      }
    }

    for (final c in clusteredReports) {
      if (c.status.contains('pend')) pendingCount++;
      if (c.status.contains('valid')) validatedCount++;
      if (c.status.contains('resolv')) resolvedCount++;
      if (c.status.contains('reject')) rejectedCount++;
      if (c.exceedsThreshold || c.riskLevel.toLowerCase().contains('high')) {
        highRiskCount++;
      }
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
      clusteredReports: clusteredReports,
      regularReports: regularReports,
    );
  }

  /// Generates the official multi-page PDF document matching the executive layout
  /// and including comprehensive farm surveillance, scouting, and profile data.
  static Future<File> generateFarmReportPdf(FarmReportData data) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('MMMM dd, yyyy').format(data.reportDate);
    final progressPercent = (data.growthProgress * 100).round();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 34),
        header: (pw.Context context) {
          if (context.pageNumber == 1) {
            return pw.SizedBox(height: 0);
          }
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'VISAIA FARM REPORT • ${data.farmName}',
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
            padding: const pw.EdgeInsets.only(top: 6),
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
          pw.SizedBox(height: 18),

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
          pw.SizedBox(height: 16),

          // ── Table 2: Active Cycle Status ──
          _buildActiveCycleTable(
            headerTitle: 'Active Cycle Status',
            headerBgColor: _lightSage,
            headerTextColor: _darkGreen,
            data: data,
            progressPercent: progressPercent,
          ),
          pw.SizedBox(height: 16),

          // ── Table 3: Fall Armyworm & Pest Surveillance Reports ──
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
          pw.SizedBox(height: 16),

          // ── Production & Financials (if recorded) ──
          if (data.totalYield > 0 || data.netIncome > 0 || data.completedCycles.isNotEmpty) ...[
            _buildSectionTable(
              headerTitle: 'Production & Financial Performance',
              headerBgColor: _lightSage,
              headerTextColor: _darkGreen,
              rows: [
                ['Completed Crop Cycles', '${data.completedCycles.length} Cycles'],
                ['Total Harvest Yield', '${NumberFormat('#,##0.#').format(data.totalYield)} Tons'],
                ['Consolidated Net Income', 'PHP ${NumberFormat('#,##0.00').format(data.netIncome)}'],
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ── SECTION: Field Scouting & Clustered Reports ──
          _buildSectionBanner(
            title: 'Field Scouting & Clustered Reports',
            badgeText: '${data.clusteredReports.length} Recorded',
          ),
          pw.SizedBox(height: 8),

          if (data.clusteredReports.isEmpty)
            _buildEmptyStateNotice('No field scouting (clustered) reports recorded for this farm yet.')
          else
            ...data.clusteredReports.map((report) => _buildClusteredReportCard(report)),

          pw.SizedBox(height: 16),

          // ── SECTION: Preliminary AI Pest Detections ──
          _buildSectionBanner(
            title: 'Preliminary AI Pest Detections (Regular Reports)',
            badgeText: '${data.regularReports.length} Recorded',
          ),
          pw.SizedBox(height: 8),

          if (data.regularReports.isEmpty)
            _buildEmptyStateNotice('No preliminary AI pest scan reports recorded for this farm yet.')
          else
            ...data.regularReports.map((report) => _buildRegularReportCard(report)),

          pw.SizedBox(height: 16),

          // ── SECTION: Registered Fields ──
          if (data.fields.isNotEmpty) ...[
            _buildSectionBanner(
              title: 'Registered Fields & Land Parcels',
              badgeText: '${data.fields.length} Fields',
            ),
            pw.SizedBox(height: 8),
            _buildFieldsTable(data.fields),
            pw.SizedBox(height: 16),
          ],

          // ── SECTION: Active & Historical Crop Cycles ──
          if (data.activeCycles.isNotEmpty || data.completedCycles.isNotEmpty) ...[
            _buildSectionBanner(
              title: 'Crop Cycles Directory',
              badgeText: '${data.activeCycles.length + data.completedCycles.length} Cycles',
            ),
            pw.SizedBox(height: 8),
            _buildCyclesTable([...data.activeCycles, ...data.completedCycles]),
            pw.SizedBox(height: 16),
          ],

          // ── Official Verification Block ──
          _buildOfficialVerificationBlock(data),
          pw.SizedBox(height: 10),
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

  static pw.Widget _buildSectionBanner({
    required String title,
    required String badgeText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _darkGreen,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(
              color: _lightSage,
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: pw.Text(
              badgeText,
              style: pw.TextStyle(
                color: _darkGreen,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmptyStateNotice(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: _cardBg,
        border: pw.Border.all(color: _borderGrey, width: 1),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        message,
        style: const pw.TextStyle(
          fontSize: 10,
          color: PdfColors.grey700,
        ),
      ),
    );
  }

  static pw.Widget _buildClusteredReportCard(ClusteredReportSummary report) {
    final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(report.reportDate);
    final statusColor = _statusColor(report.status);
    final statusBg = _statusBg(report.status);
    final riskColor = _riskColor(report.riskLevel);
    final riskBg = _riskBg(report.riskLevel);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borderGrey, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header Row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: _lightSage,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'FAW Scouting: ${report.growthStage} • ${report.fieldName}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkGreen,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: statusBg,
                    border: pw.Border.all(color: statusColor, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    report.status.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sub-Bar: Date, DAP, Week, Risk
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$dateStr   •   ${report.dap != null ? 'DAP ${report.dap}' : 'DAP N/A'}   •   ${report.weekNumber != null ? 'Week ${report.weekNumber}' : ''}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: riskBg,
                    border: pw.Border.all(color: riskColor, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    '${report.riskLevel.toUpperCase()} RISK',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Box: Metrics Grid
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    _buildMetricBox('Inspected', '${report.totalInspected} Plants'),
                    pw.SizedBox(width: 8),
                    _buildMetricBox('Damaged', '${report.totalDamaged} Plants'),
                    pw.SizedBox(width: 8),
                    _buildMetricBox('Damage Rate', '${report.damagePercentage.toStringAsFixed(1)}%'),
                    pw.SizedBox(width: 8),
                    _buildMetricBox(
                      'Threshold (10%)',
                      report.exceedsThreshold ? 'EXCEEDED' : 'Normal',
                      highlightRed: report.exceedsThreshold,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),

                // Pest Counts Breakdown
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: _subtleBg,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildPestCountText('Egg Masses', report.eggs),
                      _buildPestCountText('Larvae', report.larvae),
                      _buildPestCountText('Pupae', report.pupae),
                      _buildPestCountText('Adult Moths', report.moths),
                    ],
                  ),
                ),

                if (report.controlMethod != null || report.trapsInstalled != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      if (report.controlMethod != null)
                        pw.Expanded(
                          child: pw.Text(
                            'Control Method: ${report.controlMethod}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                          ),
                        ),
                      if (report.trapsInstalled != null)
                        pw.Text(
                          'Pheromone Traps: ${report.trapsInstalled == true ? 'Active' : 'None'}',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                        ),
                    ],
                  ),
                ],

                // Expert Validation Box
                if (report.validatedBy != null || report.advisoryMessage != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: _badgeGreenBg,
                      border: pw.Border.all(color: _badgeGreenText, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'DA-RCPC EXPERT VALIDATION',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: _badgeGreenText,
                              ),
                            ),
                            if (report.validatedAt != null)
                              pw.Text(
                                DateFormat('MMM dd, yyyy').format(report.validatedAt!),
                                style: const pw.TextStyle(fontSize: 7.5, color: _badgeGreenText),
                              ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Officer: ${report.validatedBy ?? 'DA-RCPC Entomologist'}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        if (report.expertDiagnosis != null)
                          pw.Text(
                            'Diagnosis: ${report.expertDiagnosis}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                        if (report.advisoryMessage != null)
                          pw.Text(
                            'Advisory: ${report.advisoryMessage}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                      ],
                    ),
                  ),
                ],

                // Farmer Resolution Record
                if (report.managementActionTaken != null || report.resolutionExplanation != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: _badgeBlueBg,
                      border: pw.Border.all(color: _badgeBlueText, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FARM MANAGEMENT RESOLUTION',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _badgeBlueText,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        if (report.managementActionTaken != null)
                          pw.Text(
                            'Action: ${report.managementActionTaken}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                        if (report.resolutionExplanation != null)
                          pw.Text(
                            'Explanation: ${report.resolutionExplanation}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRegularReportCard(RegularReportSummary report) {
    final dateStr = DateFormat('MMM dd, yyyy • h:mm a').format(report.reportDate);
    final statusColor = _statusColor(report.status);
    final statusBg = _statusBg(report.status);
    final riskColor = _riskColor(report.risk);
    final riskBg = _riskBg(report.risk);

    final confidenceText = report.confidence != null
        ? '${(report.confidence! > 1 ? report.confidence! : report.confidence! * 100).toStringAsFixed(1)}%'
        : 'N/A';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _borderGrey, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Header Row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: _lightSage,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '${report.detection} (${report.scientificName ?? 'Spodoptera frugiperda'}) • ${report.fieldName}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: _darkGreen,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: statusBg,
                    border: pw.Border.all(color: statusColor, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    report.status.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sub-Bar: Date, Stage, Crop, Risk
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _borderGrey, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$dateStr   •   Stage: ${report.lifeStage ?? 'Unknown'}   •   Crop: ${report.cropAffected ?? 'Corn'}',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: pw.BoxDecoration(
                    color: riskBg,
                    border: pw.Border.all(color: riskColor, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Text(
                    '${report.risk.toUpperCase()} RISK',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      fontWeight: pw.FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    _buildMetricBox('AI Confidence', confidenceText),
                    pw.SizedBox(width: 8),
                    _buildMetricBox('Risk Assessment', report.risk),
                    pw.SizedBox(width: 8),
                    _buildMetricBox('Target Host', report.cropAffected ?? 'Corn'),
                    pw.SizedBox(width: 8),
                    _buildMetricBox('Field Location', report.fieldName),
                  ],
                ),

                // Expert Validation Box
                if (report.validatedBy != null || report.advisoryMessage != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: _badgeGreenBg,
                      border: pw.Border.all(color: _badgeGreenText, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              'DA-RCPC EXPERT VALIDATION',
                              style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold,
                                color: _badgeGreenText,
                              ),
                            ),
                            if (report.validatedAt != null)
                              pw.Text(
                                DateFormat('MMM dd, yyyy').format(report.validatedAt!),
                                style: const pw.TextStyle(fontSize: 7.5, color: _badgeGreenText),
                              ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Officer: ${report.validatedBy ?? 'DA-RCPC Validator'}',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        if (report.expertDiagnosis != null)
                          pw.Text(
                            'Diagnosis: ${report.expertDiagnosis}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                        if (report.advisoryMessage != null)
                          pw.Text(
                            'Advisory: ${report.advisoryMessage}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                      ],
                    ),
                  ),
                ],

                // Farmer Resolution Record
                if (report.managementActionTaken != null || report.resolutionExplanation != null) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      color: _badgeBlueBg,
                      border: pw.Border.all(color: _badgeBlueText, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FARM MANAGEMENT RESOLUTION',
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _badgeBlueText,
                          ),
                        ),
                        pw.SizedBox(height: 3),
                        if (report.managementActionTaken != null)
                          pw.Text(
                            'Action: ${report.managementActionTaken}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                        if (report.resolutionExplanation != null)
                          pw.Text(
                            'Explanation: ${report.resolutionExplanation}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.black),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricBox(String label, String value, {bool highlightRed = false}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: pw.BoxDecoration(
          color: highlightRed ? _badgeRedBg : _cardBg,
          border: pw.Border.all(
            color: highlightRed ? _badgeRedText : _borderGrey,
            width: 0.5,
          ),
          borderRadius: pw.BorderRadius.circular(2),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: highlightRed ? _badgeRedText : PdfColors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPestCountText(String label, int count) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
          ),
          pw.TextSpan(
            text: '$count',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: count > 0 ? _darkGreen : PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFieldsTable(List<FarmFieldSummary> fields) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: _darkGreen,
        fontSize: 9.5,
      ),
      headerDecoration: const pw.BoxDecoration(color: _lightSage),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      cellStyle: const pw.TextStyle(fontSize: 9),
      headers: ['Field Name', 'Acreage', 'Current / Planned Crop'],
      data: fields.map((f) {
        return [
          f.name,
          '${f.acres.toStringAsFixed(2)} Acres',
          f.crop ?? 'Corn Variety',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildCyclesTable(List<FarmCycleSummary> cycles) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: _darkGreen,
        fontSize: 9.5,
      ),
      headerDecoration: const pw.BoxDecoration(color: _lightSage),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      headers: ['Cycle Name', 'Crop / Variety', 'Field', 'Growth Stage', 'Planting Date', 'Status'],
      data: cycles.map((c) {
        final plantStr = c.plantingDate != null
            ? DateFormat('MMM dd, yyyy').format(c.plantingDate!)
            : 'Unspecified';
        return [
          c.cycleName,
          c.cropVariety,
          c.fieldName,
          c.growthStage,
          plantStr,
          c.isCompleted ? 'Completed' : 'Active (${(c.growthProgress * 100).round()}%)',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildOfficialVerificationBlock(FarmReportData data) {
    final genTimeStr = DateFormat('MMMM dd, yyyy • hh:mm:ss a').format(DateTime.now());
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _cardBg,
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
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _darkGreen,
                ),
              ),
              pw.Text(
                'OFFICIAL REPORT',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _badgeGreenText,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This report constitutes an integrated summary of on-site fall armyworm (Spodoptera frugiperda) scouting, '
            'AI-assisted preliminary pest detections, field parcel metrics, and verified regional crop protection advisories. '
            'All records are archived securely in the VISAIA Smart Farm Monitoring platform in alignment with Department of Agriculture guidelines.',
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.grey700,
              lineSpacing: 1.2,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Farm Owner: ${data.ownerName}',
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Generated: $genTimeStr',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
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
          _buildTableRow('Cycle About to Harvest', data.cycleName),
          _buildTableRow('Week', data.weekText),
          _buildTableRow('Growth Stage', data.growthStage),
          // Growth Progress Row
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

  static PdfColor _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('valid')) return _badgeGreenText;
    if (s.contains('resolv')) return _badgeBlueText;
    if (s.contains('reject')) return _badgeRedText;
    return _badgeAmberText;
  }

  static PdfColor _statusBg(String status) {
    final s = status.toLowerCase();
    if (s.contains('valid')) return _badgeGreenBg;
    if (s.contains('resolv')) return _badgeBlueBg;
    if (s.contains('reject')) return _badgeRedBg;
    return _badgeAmberBg;
  }

  static PdfColor _riskColor(String risk) {
    final r = risk.toLowerCase();
    if (r.contains('high') || r.contains('crit')) return _badgeRedText;
    if (r.contains('mod')) return _badgeAmberText;
    return _badgeGreenText;
  }

  static PdfColor _riskBg(String risk) {
    final r = risk.toLowerCase();
    if (r.contains('high') || r.contains('crit')) return _badgeRedBg;
    if (r.contains('mod')) return _badgeAmberBg;
    return _badgeGreenBg;
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

  /// Exports Comprehensive Farm Data to CSV and shares it
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
    buffer.writeln('VISAIA COMPREHENSIVE FARM REPORT');
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
    buffer.writeln('Total Field Scouting (Clustered) Reports,${data.totalClusteredReports}');
    buffer.writeln('Total Combined Reports,${data.totalCombinedReports}');
    buffer.writeln('Pending Expert Validation,${data.pendingReports}');
    buffer.writeln('Validated Reports (DA-RCPC),${data.validatedReports}');
    buffer.writeln('Resolved Reports,${data.resolvedReports}');
    buffer.writeln('High Risk / Economic Threshold Alerts,${data.highRiskReports}');
    buffer.writeln('');
    buffer.writeln('FINANCIALS & PRODUCTION');
    buffer.writeln('Net Income (PHP),${data.netIncome}');
    buffer.writeln('Total Yield (Tons),${data.totalYield}');

    // Clustered Reports Breakdown
    buffer.writeln('');
    buffer.writeln('FIELD SCOUTING (CLUSTERED) REPORTS');
    buffer.writeln('Report ID,Date,Field,Growth Stage,DAP,Week,Inspected,Damaged,Damage %,Threshold Exceeded,Risk Level,Eggs,Larvae,Pupae,Moths,Control Method,Traps Installed,Status,Validated By,Expert Diagnosis,Advisory,Action Taken,Resolution Explanation');
    for (final r in data.clusteredReports) {
      final rDate = DateFormat('yyyy-MM-dd HH:mm').format(r.reportDate);
      buffer.writeln('"${r.id}","$rDate","${r.fieldName}","${r.growthStage}",${r.dap ?? ''},${r.weekNumber ?? ''},${r.totalInspected},${r.totalDamaged},${r.damagePercentage.toStringAsFixed(1)},${r.exceedsThreshold},"${r.riskLevel}",${r.eggs},${r.larvae},${r.pupae},${r.moths},"${r.controlMethod ?? ''}",${r.trapsInstalled ?? ''},"${r.status}","${r.validatedBy ?? ''}","${r.expertDiagnosis ?? ''}","${r.advisoryMessage ?? ''}","${r.managementActionTaken ?? ''}","${r.resolutionExplanation ?? ''}"');
    }

    // Regular Reports Breakdown
    buffer.writeln('');
    buffer.writeln('PRELIMINARY AI PEST DETECTION REPORTS (REGULAR)');
    buffer.writeln('Report ID,Date,Field,Detection,Scientific Name,Life Stage,Crop,Confidence %,Risk Level,Status,Validated By,Expert Diagnosis,Advisory,Action Taken,Resolution Explanation');
    for (final r in data.regularReports) {
      final rDate = DateFormat('yyyy-MM-dd HH:mm').format(r.reportDate);
      final conf = r.confidence != null ? (r.confidence! > 1 ? r.confidence! : r.confidence! * 100).toStringAsFixed(1) : '';
      buffer.writeln('"${r.id}","$rDate","${r.fieldName}","${r.detection}","${r.scientificName ?? ''}","${r.lifeStage ?? ''}","${r.cropAffected ?? ''}",$conf,"${r.risk}","${r.status}","${r.validatedBy ?? ''}","${r.expertDiagnosis ?? ''}","${r.advisoryMessage ?? ''}","${r.managementActionTaken ?? ''}","${r.resolutionExplanation ?? ''}"');
    }

    // Registered Fields
    buffer.writeln('');
    buffer.writeln('REGISTERED FIELDS');
    buffer.writeln('Field Name,Acres,Crop Variety');
    for (final f in data.fields) {
      buffer.writeln('"${f.name}",${f.acres},"${f.crop ?? ''}"');
    }

    // Crop Cycles
    buffer.writeln('');
    buffer.writeln('CROP CYCLES DIRECTORY');
    buffer.writeln('Cycle Name,Variety,Field,Planting Date,Harvest Date,Growth Stage,Progress %,Status,Net Income (PHP),Total Yield (Tons)');
    for (final c in [...data.activeCycles, ...data.completedCycles]) {
      final pDate = c.plantingDate != null ? DateFormat('yyyy-MM-dd').format(c.plantingDate!) : '';
      final hDate = c.harvestDate != null ? DateFormat('yyyy-MM-dd').format(c.harvestDate!) : '';
      buffer.writeln('"${c.cycleName}","${c.cropVariety}","${c.fieldName}",$pDate,$hDate,"${c.growthStage}","${(c.growthProgress * 100).round()}%","${c.isCompleted ? 'Completed' : 'Active'}",${c.income ?? ''},${c.yieldAmount ?? ''}');
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
                  ['Consolidated Net Income', 'PHP ${NumberFormat('#,##0').format(totalIncome)}'],
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
