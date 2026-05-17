import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

// ======================= MODELS =======================

class CycleModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String farmId;
  final String cycleName;
  final String cropVariety;
  final DateTime? plantingDate;
  final DateTime? harvestDate;
  final double seedDensity;
  final bool isCompleted;
  final String? status;
  final String? statusText;
  final double? income;
  final DateTime? createdAt;

  CycleModel({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.farmId,
    required this.cycleName,
    required this.cropVariety,
    this.plantingDate,
    this.harvestDate,
    required this.seedDensity,
    this.isCompleted = false,
    this.status,
    this.statusText,
    this.income,
    this.createdAt,
  });

  factory CycleModel.fromMap(String id, Map<String, dynamic> map) {
    return CycleModel(
      id: id,
      fieldId: map['fieldId'] ?? '',
      fieldName: map['fieldName'] ?? 'No Field',
      farmId: map['farmId'] ?? '',
      cycleName: map['cycleName'] ?? 'Untitled Cycle',
      cropVariety: map['cropVariety'] ?? '',
      plantingDate: _parseTimestamp(map['plantingDate']),
      harvestDate: _parseTimestamp(map['harvestDate']),
      seedDensity: (map['seedDensity'] as num?)?.toDouble() ?? 0.0,
      isCompleted: map['isCompleted'] ?? false,
      status: map['status'],
      statusText: map['statusText'],
      income: (map['income'] as num?)?.toDouble(),
      createdAt: _parseTimestamp(map['createdAt']),
    );
  }

  factory CycleModel.fromDoc(QueryDocumentSnapshot doc) {
    return CycleModel.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int? get daysSincePlanting {
    if (plantingDate == null) return null;
    return DateTime.now().difference(plantingDate!).inDays;
  }
}

class FieldModel {
  final String id;
  final String name;
  final double acres;
  final String? crop;
  final List<LatLng> boundaries;

  FieldModel({
    required this.id,
    required this.name,
    required this.acres,
    required this.boundaries,
    this.crop,
  });

  factory FieldModel.fromMap(String id, Map<String, dynamic> data) {
    return FieldModel(
      id: id,
      name: data['name'] ?? '',
      acres: (data['acres'] ?? 0).toDouble(),
      crop: data['crop'],
      boundaries: (data['boundaries'] as List)
          .map((p) => LatLng(
                (p['latitude'] ?? p['lat']).toDouble(),
                (p['longitude'] ?? p['lng']).toDouble(),
              ))
          .toList(),
    );
  }
}

class PestModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String name;
  final String severity; // "high", "moderate", "low", "monitoring"
  final DateTime detectedAt;
  final bool isActive;

  PestModel({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.name,
    required this.severity,
    required this.detectedAt,
    required this.isActive,
  });

  factory PestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PestModel(
      id: doc.id,
      fieldId: data['fieldId'] ?? '',
      fieldName: data['fieldName'] ?? 'Unknown Field',
      name: data['name'] ?? 'Unknown Pest',
      severity: data['severity'] ?? 'low',
      detectedAt: (data['detectedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
}

class ActivityLogModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;

  ActivityLogModel({
    required this.id,
    required this.fieldId,
    required this.fieldName,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });

  factory ActivityLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLogModel(
      id: doc.id,
      fieldId: data['fieldId'] ?? '',
      fieldName: data['fieldName'] ?? 'Unknown Field',
      type: data['type'] ?? 'activity',
      title: data['title'] ?? 'Activity',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }
}

// ======================= FIRESTORE SERVICE =======================

class MonitoringFirestoreService {
  final FirebaseFirestore _db;
  final String _userId;

  MonitoringFirestoreService({FirebaseFirestore? db, required String userId})
      : _db = db ?? FirebaseFirestore.instance,
        _userId = userId;

  // ----- Fields (from user document) -----
  Future<List<FieldModel>> getFields() async {
    final snapshot = await _db
        .collection('users')
        .doc(_userId)
        .collection('fields')
        .get();

    return snapshot.docs
        .map((doc) => FieldModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ----- Active Cycles (isCompleted == false) -----
  Stream<List<CycleModel>> getActiveCycles() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .where('isCompleted', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CycleModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  // ----- Active Pests (isActive == true) -----
  Stream<List<PestModel>> getActivePests() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('pests')
        .where('isActive', isEqualTo: true)
        .orderBy('detectedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => PestModel.fromFirestore(doc))
            .toList());
  }

  // ----- Recent Activity Logs (last 5) -----
  Stream<List<ActivityLogModel>> getRecentActivityLogs({int limit = 5}) {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('activityLogs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ActivityLogModel.fromFirestore(doc))
            .toList());
  }

  // ----- Total Yield (sum of income from completed cycles) -----
  Stream<double> getTotalYield() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.fold<double>(0.0, (sum, doc) {
              final data = doc.data();
              final yield = (data['totalYield'] as num?)?.toDouble() ?? 0.0;
              return sum + yield;
            }));
  }

  Stream<double> getNetIncome() {
    return _db
        .collection('users')
        .doc(_userId)
        .collection('cycles')
        .where('isCompleted', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.fold<double>(0.0, (sum, doc) {
              final data = doc.data();
              final income =
                  (data['netIncome'] as num?)?.toDouble() ?? 0.0;
              return sum + income;
            }));
  }

  // ----- (Optional) NET INCOME if you have expenses collection -----
  // Stream<double> getNetIncome() { ... }
}

// ======================= HOMEDASHBOARD WIDGET =======================

class HomeDashboard extends StatelessWidget {
  final String userId; 

  const HomeDashboard({super.key, required this.userId});

  // Brand colors
  static const Color darkGreen = Color(0xFF0D4D33);
  static const Color textGray = Color(0xFF43483E);
  static const Color headingBlack = Color(0xFF1A1C18);

  @override
  Widget build(BuildContext context) {
    final service = MonitoringFirestoreService(userId: userId);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----- Top Metrics: NET INCOME & TOTAL YIELD -----
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<double>(
                    stream: service.getNetIncome(),
                    builder: (ctx, snapshot) {
                      final total = snapshot.data ?? 0.0;

                      return _buildMetricCard(
                        title: "NET INCOME",
                        value: total.toStringAsFixed(0),
                        icon: Icons.payments_outlined,
                        bgColor: darkGreen,
                        textColor: Colors.white,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StreamBuilder<double>(
                    stream: service.getTotalYield(),
                    builder: (ctx, snapshot) {
                      final totalYield = snapshot.data ?? 0.0;

                      return _buildMetricCard(
                        title: "TOTAL YIELD",
                        value: totalYield.toStringAsFixed(1),
                        unit: "kg",
                        icon: Icons.agriculture_rounded,
                        bgColor: const Color(0xFFC5E1A5),
                        textColor: darkGreen,
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // ----- Active Cycle & Field Count -----
            FutureBuilder<List<FieldModel>>(
              future: service.getFields(),
              builder: (ctx, fieldSnapshot) {
                final fieldCount = fieldSnapshot.data?.length ?? 0;
                return StreamBuilder<List<CycleModel>>(
                  stream: service.getActiveCycles(),
                  builder: (ctx, cycleSnapshot) {
                    final cycles = cycleSnapshot.data ?? [];
                    final activeCycleCount = cycles.length;
                    return Row(
                      children: [
                        Expanded(
                          child: _buildSmallMetricCard(
                            "ACTIVE CYCLES",
                            activeCycleCount.toString(),
                            "",
                            const Color(0xFF7BC72E).withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: _buildSmallMetricCard(
                            "FIELD COUNT",
                            fieldCount.toString(),
                            "",
                            const Color(0xFFF7E594),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),

            // ----- Active Pests Section -----
            Text(
              "Active Pests",
              style: GoogleFonts.epilogue(
                  fontSize: 28, fontWeight: FontWeight.w800, color: headingBlack),
            ),
            Text(
              "Critical monitoring required",
              style: GoogleFonts.manrope(
                  fontSize: 16, color: textGray, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            StreamBuilder<List<PestModel>>(
              stream: service.getActivePests(),
              builder: (ctx, snapshot) {
                final pests = snapshot.data ?? [];
                if (pests.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No active pest alerts"),
                  );
                }
                return Column(
                  children: pests.map((pest) => _buildPestPillFromModel(pest)).toList(),
                );
              },
            ),
            const SizedBox(height: 40),

            // ----- Recent Activity Section -----
            Text(
              'Recent Activity',
              style: GoogleFonts.epilogue(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: headingBlack,
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<ActivityLogModel>>(
              stream: service.getRecentActivityLogs(),
              builder: (ctx, snapshot) {
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text("No recent activity"),
                  );
                }
                return Column(
                  children: logs.map((log) => _buildActivityCardFromModel(log)).toList(),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ----- Dynamic Pest Pill from PestModel -----
  Widget _buildPestPillFromModel(PestModel pest) {
    Color bgColor;
    Color iconColor;
    switch (pest.severity) {
      case 'high':
        bgColor = const Color.fromARGB(255, 247, 206, 206);
        iconColor = const Color(0xFFBA1A1A);
        break;
      case 'moderate':
        bgColor = const Color.fromARGB(166, 255, 221, 221);
        iconColor = const Color(0xFFBA1A1A);
        break;
      case 'low':
        bgColor = const Color(0xFF7E5800);
        iconColor = const Color.fromARGB(255, 255, 235, 200);
        break;
      default: // monitoring
        bgColor = const Color.fromARGB(197, 144, 118, 56);
        iconColor = const Color.fromARGB(249, 255, 225, 168);
    }
    return _buildPestPill(
      pest.name,
      "${pest.severity.toUpperCase()} severity • ${_relativeTime(pest.detectedAt)}",
      bgColor,
      iconColor,
    );
  }

  // ----- Dynamic Activity Card from ActivityLogModel -----
  Widget _buildActivityCardFromModel(ActivityLogModel log) {
    IconData icon;
    Color iconBg;
    switch (log.type) {
      case 'irrigation':
        icon = Icons.water_drop;
        iconBg = const Color.fromARGB(255, 228, 248, 229);
        break;
      case 'fertilization':
        icon = Icons.center_focus_strong;
        iconBg = const Color.fromARGB(223, 235, 216, 179);
        break;
      default:
        icon = Icons.notifications_active;
        iconBg = Colors.grey.shade200;
    }
    return _buildActivityCard(
      log.title,
      log.description,
      _relativeTime(log.timestamp),
      icon,
      iconBg,
    );
  }

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}D AGO';
    if (diff.inHours > 0) return '${diff.inHours}H AGO';
    if (diff.inMinutes > 0) return '${diff.inMinutes}M AGO';
    return 'NOW';
  }

  // ----- Your existing UI components (unchanged, just pasted) -----

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? unit,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: textColor, size: 24),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: GoogleFonts.manrope(
                  color: textColor.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: GoogleFonts.manrope(
                      color: textColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(unit,
                    style: GoogleFonts.manrope(
                        color: textColor.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ]
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "VIEW DETAILS",
            style: GoogleFonts.manrope(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallMetricCard(String title, String value, String unit, Color color) {
    IconData displayIcon = title.contains("CYCLE")
        ? Icons.stacked_line_chart_rounded
        : Icons.grid_view_rounded;

    return Container(
      width: 167,
      height: 131,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(displayIcon, size: 18, color: Colors.black.withOpacity(0.7)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: Colors.black.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF1A1C18),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: GoogleFonts.manrope(
                        color: Colors.black.withOpacity(0.4),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPestPill(String title, String subtitle, Color circleBg, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: circleBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bug_report, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: headingBlack)),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        color: textGray,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String title, String subtitle, String time, IconData icon, Color iconBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAF9),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: darkGreen, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: headingBlack)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: GoogleFonts.manrope(
                        color: textGray,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(time,
              style: GoogleFonts.manrope(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}