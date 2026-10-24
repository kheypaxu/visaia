import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/push_message_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24);
  final data = <String, dynamic>{
    'farmerId': 'farmer-a', 'eventId': 'approval-a',
    'expiresAt': '${now.add(const Duration(days: 1)).millisecondsSinceEpoch}',
  };
  bool display(String? uid, {Map<String, dynamic>? payload, List<String> seen = const []}) =>
      shouldDisplayPush(recipientUid: uid, data: payload ?? data, now: now, seen: seen);
  test('both devices logged into the recipient account can display the same event', () {
    expect(display('farmer-a'), isTrue);
    expect(display('farmer-a'), isTrue);
  });
  test('logout and switching test accounts block old deliveries', () {
    expect(display(null), isFalse);
    expect(display('farmer-b'), isFalse);
    expect(display('farmer-a'), isTrue);
  });
  test('a duplicate retry does not display twice on the same device', () {
    expect(display('farmer-a', seen: ['approval-a']), isFalse);
  });
  test('expired and malformed messages are rejected', () {
    expect(display('farmer-a', payload: {...data, 'expiresAt': '${now.millisecondsSinceEpoch}'}), isFalse);
    expect(display('farmer-a', payload: {...data}..remove('expiresAt')), isFalse);
    expect(display('farmer-a', payload: {...data}..remove('eventId')), isFalse);
  });
}
