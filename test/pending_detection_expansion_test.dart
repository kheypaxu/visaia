import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/api_service.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'package:visaia/widgets/pending_detection_list.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pending_detection_ui_');
  });
  tearDown(() async {
    await directory.delete();
  });

  Future<OfflineSyncService> service(List<QueuedOfflineItem> items) async {
    SharedPreferences.setMockInitialValues({
      'visaia_offline_sync_queue_v1': items
          .map((i) => jsonEncode(i.toJson()))
          .toList(),
    });
    final sync = OfflineSyncService.forTesting(
      currentOwner: () => 'farmer-1',
      online: () => false,
      analyze: (_, _) async => throw UnimplementedError(),
      commitReport: (_) async {},
      documentsDirectory: () async => directory,
    );
    await sync.init();
    return sync;
  }

  testWidgets(
    'Report History expansion displays queued detection information',
    (tester) async {
      final item = QueuedOfflineItem(
        id: 'detection-1',
        type: 'pest_report',
        imagePath: '${directory.path}/missing.jpg',
        userId: 'farmer-1',
        latitude: 10,
        longitude: 122,
        areaName: 'North field',
        timestamp: DateTime(2026, 10, 28).millisecondsSinceEpoch,
        status: 'ready',
        farmName: 'Sample Farm',
        fieldName: 'North field',
        result: AnalysisResult(
          pestName: 'Fall Armyworm',
          scientificName: 'Spodoptera frugiperda',
          lifeStage: 'Larva',
          analysis: 'Larvae detected on maize.',
          treatment: 'Review field.',
          boxes: [],
          riskLevel: 'High',
          filename: 'pest.jpg',
          historicalContext: '',
          cropAffected: 'Maize',
          confidence: .91,
        ),
      );
      final sync = await service([item]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PendingDetectionsSection(service: sync),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pending detections (1)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Fall Armyworm'), findsOneWidget);
      expect(find.text('Ready to review'), findsOneWidget);
      expect(find.text('View AI result'), findsOneWidget);
      await tester.tap(find.text('Pending detections (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pending detections (1)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Fall Armyworm'), findsOneWidget);
    },
  );
  testWidgets(
    'waiting detections show details even when the local photo is unavailable',
    (tester) async {
      final sync = await service([
        QueuedOfflineItem(
          id: 'waiting-1',
          type: 'pest_report',
          imagePath: '${directory.path}/missing.jpg',
          userId: 'farmer-1',
          latitude: 10,
          longitude: 122,
          areaName: 'South field',
          timestamp: DateTime(2026, 10, 28).millisecondsSinceEpoch,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PendingDetectionsSection(service: sync),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pending detections (1)'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pest detection'), findsOneWidget);
      expect(find.text('South field'), findsOneWidget);
      expect(find.text('Waiting to sync'), findsOneWidget);
    },
  );
  testWidgets('empty expansion explains that no detections are pending', (
    tester,
  ) async {
    final sync = await service([]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PendingDetectionsSection(service: sync),
              const Expanded(child: SizedBox()),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Pending detections (0)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('No pending detections.'), findsOneWidget);
  });
}
