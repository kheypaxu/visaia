import 'package:cloud_firestore/cloud_firestore.dart';

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

  // New fields
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

  // ================= FROM FIRESTORE =================
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

  // ================= TO FIRESTORE =================
  Map<String, dynamic> toMap() {
    return {
      'fieldId': fieldId,
      'fieldName': fieldName,
      'farmId': farmId,
      'cycleName': cycleName,
      'cropVariety': cropVariety,
      'plantingDate': plantingDate != null ? Timestamp.fromDate(plantingDate!) : null,
      'harvestDate': harvestDate != null ? Timestamp.fromDate(harvestDate!) : null,
      'seedDensity': seedDensity,
      'isCompleted': isCompleted,
      'status': status,
      'statusText': statusText,
      'income': income,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    final map = <String, dynamic>{};
    
    if (plantingDate != null) map['plantingDate'] = Timestamp.fromDate(plantingDate!);
    if (harvestDate != null) map['harvestDate'] = Timestamp.fromDate(harvestDate!);
    
    map['fieldId'] = fieldId;
    map['fieldName'] = fieldName;
    map['farmId'] = farmId;
    map['cycleName'] = cycleName;
    map['cropVariety'] = cropVariety;
    map['seedDensity'] = seedDensity;
    map['isCompleted'] = isCompleted;
    map['status'] = status;
    map['statusText'] = statusText;
    map['income'] = income;
    
    return map;
  }

  // ================= COPY WITH =================
  CycleModel copyWith({
    String? fieldId,
    String? fieldName,
    String? farmId,
    String? cycleName,
    String? cropVariety,
    DateTime? plantingDate,
    DateTime? harvestDate,
    double? seedDensity,
    bool? isCompleted,
    String? status,
    String? statusText,
    double? income,
    bool clearPlantingDate = false,
    bool clearHarvestDate = false,
    bool clearStatus = false,
    bool clearIncome = false,
  }) {
    return CycleModel(
      id: id,
      fieldId: fieldId ?? this.fieldId,
      fieldName: fieldName ?? this.fieldName,
      farmId: farmId ?? this.farmId,
      cycleName: cycleName ?? this.cycleName,
      cropVariety: cropVariety ?? this.cropVariety,
      plantingDate: clearPlantingDate ? null : (plantingDate ?? this.plantingDate),
      harvestDate: clearHarvestDate ? null : (harvestDate ?? this.harvestDate),
      seedDensity: seedDensity ?? this.seedDensity,
      isCompleted: isCompleted ?? this.isCompleted,
      status: clearStatus ? null : (status ?? this.status),
      statusText: clearStatus ? null : (statusText ?? this.statusText),
      income: clearIncome ? null : (income ?? this.income),
      createdAt: createdAt,
    );
  }

  // ================= COMPUTED PROPERTIES =================

  /// Checks if cycle should be displayed as completed
  /// (explicit flag OR harvest date passed)
  bool get shouldBeCompleted {
    if (isCompleted) return true;
    if (harvestDate == null) return false;
    return DateTime.now().difference(harvestDate!).inDays > 1;
  }

  /// Calculates progress percentage (0.0 to 1.0)
  double get progress {
    if (plantingDate == null || harvestDate == null) return 0.0;

    final now = DateTime.now();
    final totalDays = harvestDate!.difference(plantingDate!).inDays;
    final elapsedDays = now.difference(plantingDate!).inDays;

    if (elapsedDays <= 0) return 0.0;
    if (elapsedDays >= totalDays) return 1.0;
    return elapsedDays / totalDays;
  }

  /// Returns progress as percentage string
  String get progressPercentage => '${(progress * 100).toInt()}%';

  /// Total days in cycle
  int? get totalDays {
    if (plantingDate == null || harvestDate == null) return null;
    return harvestDate!.difference(plantingDate!).inDays;
  }

  /// Days remaining until harvest
  int? get daysUntilHarvest {
    if (harvestDate == null) return null;
    final diff = harvestDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Days since planting
  int? get daysSincePlanting {
    if (plantingDate == null) return null;
    return DateTime.now().difference(plantingDate!).inDays;
  }

  /// Formatted planting date
  String get formattedPlantingDate {
    if (plantingDate == null) return 'Not set';
    return _formatDate(plantingDate!, 'MMM dd, yyyy');
  }

  /// Formatted harvest date (short)
  String get formattedHarvestDateShort {
    if (harvestDate == null) return 'Not set';
    return _formatDate(harvestDate!, 'MMM dd');
  }

  /// Formatted harvest date (long)
  String get formattedHarvestDateLong {
    if (harvestDate == null) return 'Not recorded';
    return _formatDate(harvestDate!, 'MMM dd, yyyy');
  }

  /// Formatted income
  String get formattedIncome {
    if (income == null) return 'Not recorded';
    return '\$${income!.toStringAsFixed(2)}';
  }

  /// Gets crop-specific icon name
  String get cropIconName {
    if (cropVariety.isEmpty) return 'grass';
    final lower = cropVariety.toLowerCase();
    if (lower.contains('corn') || lower.contains('maize')) return 'eco';
    if (lower.contains('soy')) return 'spa';
    if (lower.contains('wheat') || lower.contains('barley')) return 'grain';
    if (lower.contains('rice')) return 'rice_bowl';
    if (lower.contains('cotton')) return 'cloud';
    return 'grass';
  }

  // ================= HELPERS =================
  static String _formatDate(DateTime date, String pattern) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    if (pattern == 'MMM dd') {
      return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}';
    }
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }

  @override
  String toString() {
    return 'CycleModel(id: $id, cycleName: $cycleName, fieldName: $fieldName, progress: ${progress.toStringAsFixed(2)})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CycleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}