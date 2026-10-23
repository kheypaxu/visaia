import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/offline_sync_service.dart';

void main() {
  test(
    'queued reports retain ownership, document identity and photo across restart',
    () {
      final item = QueuedOfflineItem(
        id: 'queue-1',
        docId: 'report-1',
        type: 'pest_report',
        imagePath: '/persistent/offline_queue/photo.jpg',
        userId: 'farmer-1',
        farmerName: 'Farmer Name',
        farmId: 'farm-1',
        fieldId: 'field-1',
        cycleId: 'cycle-1',
        latitude: 10.5,
        longitude: 122.5,
        areaName: 'Field',
        timestamp: 123456,
        status: 'failed',
        errorMessage: 'Connection interrupted',
      );
      final restored = QueuedOfflineItem.fromJson(
        jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), item.toJson());
      expect(restored.docId, 'report-1');
      expect(restored.imagePath, '/persistent/offline_queue/photo.jpg');
    },
  );

  test('legacy queued reports without farmer name or cycle still load', () {
    final restored = QueuedOfflineItem.fromJson({
      'id': 'legacy-1',
      'imagePath': '/persistent/photo.jpg',
      'userId': 'farmer-1',
      'latitude': 10,
      'longitude': 122,
    });
    expect(restored.userId, 'farmer-1');
    expect(restored.farmerName, isNull);
    expect(restored.cycleId, isNull);
    expect(restored.status, 'pending');
    expect(restored.latitude, 10.0);
  });
}
