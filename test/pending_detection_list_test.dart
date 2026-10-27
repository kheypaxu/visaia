import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'package:visaia/widgets/pending_detection_list.dart';
import 'detection_queue_lifecycle_test.dart' show sampleResult;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OfflineSyncService> create({
    bool ready = true,
    bool empty = false,
  }) async {
    final item = QueuedOfflineItem(
      id: 'pending-1',
      type: 'pest_report',
      imagePath: '/missing/pest.jpg',
      userId: 'farmer-1',
      farmName: 'Farm',
      fieldName: 'Field',
      latitude: 10,
      longitude: 122,
      areaName: 'Field',
      timestamp: 123,
      status: ready ? 'ready' : 'pending',
      result: ready ? sampleResult() : null,
    );
    SharedPreferences.setMockInitialValues({
      'visaia_offline_sync_queue_v1': empty
          ? <String>[]
          : [jsonEncode(item.toJson())],
    });
    final service = OfflineSyncService.forTesting(
      currentOwner: () => 'farmer-1',
      online: () => false,
      documentsDirectory: () async => Directory.systemTemp,
      analyze: (_, onSent) async => sampleResult(),
      commitReport: (_) async {},
    );
    await service.init();
    return service;
  }

  testWidgets('ready item opens its saved result and fits a narrow display', (
    tester,
  ) async {
    final service = await create();
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 500,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 640),
                  textScaler: TextScaler.linear(1.4),
                ),
                child: PendingDetectionList(
                  service: service,
                  onOpen: (item) => opened = item.id,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ready to review'), findsOneWidget);
    await tester.tap(find.text('View AI result'));
    expect(opened, 'pending-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('waiting item has a status and no result action', (tester) async {
    final service = await create(ready: false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PendingDetectionList(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Waiting to sync'), findsOneWidget);
    expect(find.text('View AI result'), findsNothing);
  });

  testWidgets('history section remains discoverable when the queue is empty', (
    tester,
  ) async {
    final service = await create(empty: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PendingDetectionsSection(service: service)),
      ),
    );
    expect(find.text('Pending detections (0)'), findsOneWidget);
    await tester.tap(find.text('Pending detections (0)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pending detections.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
