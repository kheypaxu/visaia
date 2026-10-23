import 'package:cloud_firestore/cloud_firestore.dart';

/// Distinguishes the user's crop schedule from the recorded harvest event.
class CycleDates {
  CycleDates(this.data);

  final Map<String, dynamic> data;

  DateTime? get planting => _date(data['plantingDate']);

  DateTime? get estimatedHarvest =>
      _date(data['expectedHarvestDate']) ??
      _date(data['estimatedHarvestDate']) ??
      _date(data['harvestDate']);

  // Older harvest recording copied the estimate into actualHarvestDate.
  // The harvest event timestamp is the reliable completion date in that format.
  DateTime? get harvestCompleted =>
      _date(data['harvestCompletedAt']) ??
      _date(data['actualHarvestDate']) ??
      _date(data['completedAt']) ??
      (data['isPreviousCycle'] == true ? _date(data['harvestDate']) : null);

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
