import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/api_service.dart';
import 'package:visaia/services/offline_sync_service.dart';

AnalysisResult sampleResult() => AnalysisResult(
  pestName: 'Fall Armyworm',
  scientificName: 'Spodoptera frugiperda',
  lifeStage: 'Larva',
  analysis: 'AI analysis',
  treatment: 'AI treatment',
  boxes: [
    BoundingBox(
      x: 1,
      y: 2,
      width: 3,
      height: 4,
      className: 'larva',
      confidence: .91,
    ),
  ],
  riskLevel: 'High',
  filename: 'pest.jpg',
  annotatedImageUrl: 'https://example.com/pest.jpg',
  historicalContext: 'Historical context',
  cropAffected: 'Maize',
  confidence: .91,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File photo;
  bool online = false;
  String? owner = 'farmer-1';
  int analyses = 0;
  int commits = 0;
  bool rejectCommit = false;
  final committedIds = <String>[];

  OfflineSyncService create({
    Future<AnalysisResult> Function(File, VoidCallback)? analyze,
  }) => OfflineSyncService.forTesting(
    currentOwner: () => owner,
    online: () => online,
    documentsDirectory: () async => directory,
    analyze:
        analyze ??
        (file, onSent) async {
          analyses++;
          onSent();
          return sampleResult();
        },
    commitReport: (item) async {
      commits++;
      committedIds.add(item.id);
      if (rejectCommit) throw StateError('Server unavailable');
    },
  );

  Future<QueuedOfflineItem> enqueue(OfflineSyncService service) =>
      service.enqueuePestReport(
        imageFile: photo,
        userId: 'farmer-1',
        farmId: 'farm-1',
        fieldId: 'field-1',
        latitude: 10,
        longitude: 122,
        areaName: 'Field',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('detection_lifecycle_');
    photo = await File('${directory.path}/pest.jpg').writeAsBytes([1, 2, 3]);
    online = false;
    owner = 'farmer-1';
    analyses = 0;
    commits = 0;
    rejectCommit = false;
    committedIds.clear();
  });
  tearDown(() async => directory.delete(recursive: true));

  test('discard removes a ready detection and its photo durably', () async {
    final service = create();
    final item = await enqueue(service);
    online = true;
    await service.syncAll();
    online = false;
    await service.removeItem(item.id);
    expect(service.itemById(item.id), isNull);
    expect(await File(item.imagePath).exists(), isFalse);
    final restored = create();
    await restored.init();
    expect(restored.queue, isEmpty);
    expect(commits, 0);
  });

  test('discard preserves a report with an unconfirmed save', () async {
    final service = create();
    final item = await enqueue(service);
    item.submission = {'cycleId': 'cycle-1'};
    await expectLater(service.removeItem(item.id), throwsStateError);
    expect(service.itemById(item.id), same(item));
    expect(await File(item.imagePath).exists(), isTrue);
  });

  test('notifies once after the review result is persisted', () async {
    final service = create();
    final item = await enqueue(service);
    final notified = <String>[];
    service.onAnalysisReady = (ready) async {
      final restored = create();
      await restored.init();
      expect(restored.itemById(ready.id)?.isReady, isTrue);
      notified.add(ready.id);
    };
    online = true;
    await service.syncAll();
    await service.syncAll();
    expect(notified, [item.id]);
  });

  test('notification failure preserves a completed result', () async {
    final service = create();
    final item = await enqueue(service);
    service.onAnalysisReady = (_) async =>
        throw StateError('Notifications denied');
    online = true;
    await service.syncAll();
    expect(item.status, 'ready');
    expect(item.errorMessage, isNull);
    await service.syncAll();
    expect(analyses, 1);
  });

  test(
    'offline upload becomes a durable review result, not a report',
    () async {
      var service = create();
      final item = await enqueue(service);
      expect(commits, 0);
      expect(item.docId, isNull);
      final savedPhoto = File(item.imagePath);
      expect(await savedPhoto.exists(), isTrue);
      final labels = <String>[];
      service.queueRevision.addListener(() => labels.add(item.statusLabel));
      online = true;
      await service.syncAll();
      expect(
        labels,
        containsAllInOrder([
          'Uploading photo',
          'Waiting for AI result',
          'Ready to review',
        ]),
      );
      expect(item.status, 'ready');
      expect(commits, 0);
      expect(await savedPhoto.exists(), isTrue);
      service = create();
      await service.init();
      expect(service.readyCount, 1);
      expect(service.queue.single.result!.toJson(), sampleResult().toJson());
      await service.syncAll();
      expect(analyses, 1);
      expect(commits, 0);
    },
  );

  test(
    'only reviewed assigned reports submit; failed save survives restart and reuses ID',
    () async {
      var service = create();
      final item = await enqueue(service);
      online = true;
      await service.syncAll();
      await expectLater(
        service.submitReviewedReport(item.id, {}),
        throwsStateError,
      );
      expect(commits, 0);
      rejectCommit = true;
      final payload = {
        'cycleId': 'cycle-1',
        'weekNumber': 2,
        'station': 3,
        'detection': 'Fall Armyworm',
        'lifeStage': 'larva',
        'confidence': .91,
        'risk': 'High',
        'analysis': 'AI analysis',
        'treatment': 'AI treatment',
        'historicalContext': 'Historical context',
        'cropAffected': 'Maize',
      };
      await expectLater(
        service.submitReviewedReport(item.id, payload),
        throwsStateError,
      );
      expect(await File(item.imagePath).exists(), isTrue);
      service = create();
      await service.init();
      expect(service.queue.single.submission!['cycleId'], 'cycle-1');
      expect(service.queue.single.result!.analysis, 'AI analysis');
      rejectCommit = false;
      await service.syncAll();
      expect(committedIds, [item.id, item.id]);
      expect(analyses, 1);
      expect(service.queue, isEmpty);
      expect(await File(item.imagePath).exists(), isFalse);
      final restarted = create();
      await restarted.init();
      expect(restarted.queue, isEmpty);
    },
  );

  test(
    'another account cannot see, analyze, or submit this detection',
    () async {
      final service = create();
      final item = await enqueue(service);
      owner = 'farmer-2';
      online = true;
      service.refresh();
      expect(service.queue, isEmpty);
      await service.syncAll(forUserId: 'farmer-1');
      expect(analyses, 0);
      expect(commits, 0);
      await expectLater(
        service.submitReviewedReport(item.id, {'cycleId': 'cycle'}),
        throwsStateError,
      );
      owner = 'farmer-1';
      expect(service.queue.single.id, item.id);
    },
  );

  test(
    'account switch during inference preserves owner result without submitting',
    () async {
      final response = Completer<AnalysisResult>();
      final started = Completer<void>();
      final service = create(
        analyze: (file, onSent) {
          onSent();
          started.complete();
          return response.future;
        },
      );
      final item = await enqueue(service);
      online = true;
      final sync = service.syncAll();
      await started.future;
      owner = 'farmer-2';
      response.complete(sampleResult());
      await sync;
      expect(service.queue, isEmpty);
      expect(commits, 0);
      owner = 'farmer-1';
      expect(service.itemById(item.id)!.result!.analysis, 'AI analysis');
    },
  );

  test(
    'legacy in-flight queue entries retain photo and placeholder identity',
    () async {
      final item = QueuedOfflineItem(
        id: 'legacy-1',
        docId: 'old-report-1',
        type: 'pest_report',
        imagePath: photo.path,
        userId: 'farmer-1',
        latitude: 10,
        longitude: 122,
        areaName: 'Field',
        timestamp: 123,
        status: 'syncing',
      );
      SharedPreferences.setMockInitialValues({
        'visaia_offline_sync_queue_v1': [jsonEncode(item.toJson())],
      });
      final service = create();
      await service.init();
      expect(service.queue.single.status, 'pending');
      expect(service.queue.single.docId, 'old-report-1');
      online = true;
      await service.syncAll();
      expect(service.queue.single.isReady, isTrue);
      expect(commits, 0);
      expect(await photo.exists(), isTrue);
    },
  );

  test('analysis failure is retryable and never discards the photo', () async {
    var fail = true;
    final service = create(
      analyze: (file, onSent) async {
        analyses++;
        onSent();
        if (fail) throw const FormatException('Incomplete AI response');
        return sampleResult();
      },
    );
    final item = await enqueue(service);
    online = true;
    await service.syncAll();
    expect(item.status, 'failed');
    expect(item.result, isNull);
    expect(item.errorMessage, contains('Incomplete AI response'));
    expect(await File(item.imagePath).exists(), isTrue);
    expect(commits, 0);
    fail = false;
    await service.syncAll();
    expect(item.isReady, isTrue);
    expect(analyses, 2);
    expect(commits, 0);
  });

  test(
    'an overlapping Save cannot acknowledge success before the server',
    () async {
      final committed = Completer<void>();
      final started = Completer<void>();
      final service = OfflineSyncService.forTesting(
        currentOwner: () => owner,
        online: () => online,
        documentsDirectory: () async => directory,
        analyze: (_, onSent) async => sampleResult(),
        commitReport: (_) {
          commits++;
          started.complete();
          return committed.future;
        },
      );
      final item = await enqueue(service);
      online = true;
      await service.syncAll();
      var acknowledged = false;
      final first = service.submitReviewedReport(item.id, {
        'cycleId': 'cycle-1',
      })..then((_) => acknowledged = true);
      await started.future;
      await expectLater(
        service.submitReviewedReport(item.id, {'cycleId': 'cycle-2'}),
        throwsStateError,
      );
      await service.syncAll();
      expect(acknowledged, isFalse);
      expect(commits, 1);
      expect(await File(item.imagePath).exists(), isTrue);
      committed.complete();
      await first;
      expect(acknowledged, isTrue);
      expect(service.queue, isEmpty);
    },
  );
}
