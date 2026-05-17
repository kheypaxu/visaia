import 'package:cloud_firestore/cloud_firestore.dart';

class PestModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String name;
  final String severity;   // "high", "moderate", "low", "monitoring"
  final DateTime detectedAt;
  final bool isActive;     // if false, pest is resolved

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

  Map<String, dynamic> toMap() => {
    'fieldId': fieldId,
    'fieldName': fieldName,
    'name': name,
    'severity': severity,
    'detectedAt': Timestamp.fromDate(detectedAt),
    'isActive': isActive,
  };
}