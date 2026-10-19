import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visaia/services/notification_feed_service.dart';

InboxNotification entry(
  String id, {
  String type = 'regular',
  String status = 'validated',
  String? alert,
  int day = 1,
}) => InboxNotification(
  id: id,
  title: '',
  message: '',
  reportId: 'report-1',
  reportType: type,
  status: status,
  createdAt: DateTime(2026, 10, day),
  unread: true,
  data: const {},
  alertId: alert,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('same clustered report from both owner queries appears once', () {
    final n = entry('cluster', type: 'clustered');
    expect(InboxNotification.merge([n, n]), [n]);
  });
  test(
    'explicit validation alert supersedes only the matching report outcome',
    () {
      final alert = entry('alert', alert: 'a');
      final rejected = entry('rejected', status: 'rejected', day: 3);
      final cluster = entry('cluster', type: 'clustered', day: 2);
      expect(
        InboxNotification.merge([entry('regular'), alert, rejected, cluster]),
        [rejected, cluster, alert],
      );
    },
  );
  test('legacy report alert without type also suppresses duplicate', () {
    final alert = entry('alert', type: '', alert: 'a');
    expect(InboxNotification.merge([entry('regular'), alert]), [alert]);
  });
  test('rejection is classified separately from validation', () {
    expect(
      InboxNotification.reportStatus({'type': 'validation_rejected'}),
      'rejected',
    );
    expect(
      InboxNotification.reportStatus({'type': 'validation_confirmed'}),
      'validated',
    );
  });
  test('report read receipts persist per account and event', () async {
    SharedPreferences.setMockInitialValues({});
    await NotificationFeedService.markRead('farmer-a', [
      entry('validated-event'),
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('notification_reads_v1_farmer-a'), [
      'validated-event',
    ]);
    expect(prefs.getStringList('notification_reads_v1_farmer-b'), isNull);
    expect(
      prefs.getStringList('notification_reads_v1_farmer-a'),
      isNot(contains('rejected-event')),
    );
  });
  test('signed out feed does not open Firestore queries', () async {
    expect(await NotificationFeedService.watch('').first, isEmpty);
  });
}
