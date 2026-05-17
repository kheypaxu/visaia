import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogModel {
  final String id;
  final String fieldId;
  final String fieldName;
  final String type;      // "irrigation", "fertilization", "harvest", etc.
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