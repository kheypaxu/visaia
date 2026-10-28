import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'package:visaia/widgets/cycle_assignment_button.dart';
import 'detection_queue_lifecycle_test.dart' show sampleResult;

void main() {
  bool online = true;
  bool reject = false;
  int commits = 0;
  final targets = <String>[];
  OfflineSyncService create() => OfflineSyncService.forTesting(
    currentOwner: () => 'farmer-1',
    online: () => online,
    documentsDirectory: () async => Directory.systemTemp,
    analyze: (_, _) async => sampleResult(),
    commitReport: (item) async {
      commits++;
      targets.add(item.submission!['cycleId'] as String);
      if (reject) throw StateError('Network failed');
    },
  );
  setUp(() {
    online = true;
    reject = false;
    commits = 0;
    targets.clear();
    final item = QueuedOfflineItem(
      id: 'locked-detection',
      type: 'pest_report',
      imagePath: '/missing.jpg',
      userId: 'farmer-1',
      latitude: 10,
      longitude: 122,
      areaName: 'Field',
      timestamp: 123,
      status: 'ready',
      result: sampleResult(),
    );
    SharedPreferences.setMockInitialValues({
      'visaia_offline_sync_queue_v1': [jsonEncode(item.toJson())],
    });
  });
  const assignment = {
    'cycleId': 'cycle-1',
    'cycleName': 'Maize cycle',
    'weekNumber': 2,
    'station': 3,
  };
  test('assignment survives reopening and rejects any second target', () async {
    final sync = create();
    await sync.init();
    await sync.lockCycleAssignment('locked-detection', assignment);
    final restored = create();
    await restored.init();
    expect(restored.queue.single.isAssigned, isTrue);
    expect(restored.queue.single.lockedAssignment, assignment);
    await expectLater(
      restored.lockCycleAssignment('locked-detection', {
        ...assignment,
        'cycleId': 'cycle-2',
      }),
      throwsStateError,
    );
    await expectLater(
      restored.submitReviewedReport('locked-detection', {
        ...assignment,
        'station': 4,
      }),
      throwsStateError,
    );
    expect(commits, 0);
  });
  test(
    'failed save retains original assignment until sync removes it durably',
    () async {
      var sync = create();
      await sync.init();
      await sync.lockCycleAssignment('locked-detection', assignment);
      reject = true;
      await expectLater(
        sync.submitReviewedReport('locked-detection', assignment),
        throwsStateError,
      );
      expect(sync.queue.single.isAssigned, isTrue);
      expect(sync.readyCount, 0);
      sync = create();
      await sync.init();
      reject = false;
      await sync.syncAll();
      expect(commits, 2);
      expect(targets, ['cycle-1', 'cycle-1']);
      expect(sync.queue, isEmpty);
      final restarted = create();
      await restarted.init();
      expect(restarted.queue, isEmpty);
    },
  );
  testWidgets(
    'assignment is solid green and clickable before assignment, disabled after',
    (tester) async {
      var taps = 0;
      Widget button(bool assigned) => MaterialApp(
        home: Scaffold(
          body: CycleAssignmentButton(
            assigned: assigned,
            onAssign: () => taps++,
          ),
        ),
      );
      await tester.pumpWidget(button(false));
      final active = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(active.onPressed, isNotNull);
      expect(
        active.style!.backgroundColor!.resolve({}),
        const Color(0xFF1A5C30),
      );
      await tester.tap(find.text('Assign to Cycle'));
      expect(taps, 1);
      await tester.pumpWidget(button(true));
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Cycle Assigned'));
      expect(taps, 1);
    },
  );
}
