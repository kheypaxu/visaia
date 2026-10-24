import 'package:flutter_test/flutter_test.dart';
import 'package:visaia/services/push_message_policy.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24);
  final data = <String, dynamic>{
    'farmerId': 'farmer-a',
    'eventId': 'approval-a',
    'expiresAt': '${now.add(const Duration(days: 1)).millisecondsSinceEpoch}',
  };
  bool display(
    String? uid, {
    Map<String, dynamic>? payload,
    List<String> seen = const [],
  }) => shouldDisplayPush(
    recipientUids: uid == null ? [] : [uid],
    data: payload ?? data,
    now: now,
    seen: seen,
  );
  test(
    'both devices logged into the recipient account can display the same event',
    () {
      expect(display('farmer-a'), isTrue);
      expect(display('farmer-a'), isTrue);
    },
  );
  test('logging out removes the account from allowed recipients', () {
    expect(display(null), isFalse);
    expect(display('farmer-b'), isFalse);
    expect(display('farmer-a'), isTrue);
  });
  test(
    'another retained account can notify while a different account is active',
    () {
      expect(
        shouldDisplayPush(
          recipientUids: ['farmer-a', 'farmer-b'],
          data: data,
          now: now,
          seen: [],
        ),
        isTrue,
      );
      final preview = pushPresentation(
        data: {
          ...data,
          'accountName': 'Farmer A',
          'title': 'Sensitive title',
          'body': 'Private report details',
        },
        activeUid: 'farmer-b',
      );
      expect(preview.title, contains('Farmer A'));
      expect(preview.body, contains('Sign in'));
      expect(preview.title, isNot(contains('Sensitive')));
      expect(preview.body, isNot(contains('Private')));
    },
  );
  test(
    'the active account sees its notification details with an account label',
    () {
      final preview = pushPresentation(
        data: {
          ...data,
          'accountName': 'Farmer A',
          'title': 'Account approved',
          'body': 'MAO approved your account',
        },
        activeUid: 'farmer-a',
      );
      expect(preview.title, 'Farmer A · Account approved');
      expect(preview.body, 'MAO approved your account');
    },
  );
  test('signed-out saved accounts get only a generic preview', () {
    final preview = pushPresentation(
      data: {...data, 'body': 'Private'},
      activeUid: null,
    );
    expect(preview.title, contains('Saved account'));
    expect(preview.body, isNot(contains('Private')));
  });
  test('a duplicate retry does not display twice on the same device', () {
    expect(display('farmer-a', seen: ['approval-a']), isFalse);
  });
  test('expired and malformed messages are rejected', () {
    expect(
      display(
        'farmer-a',
        payload: {...data, 'expiresAt': '${now.millisecondsSinceEpoch}'},
      ),
      isFalse,
    );
    expect(
      display('farmer-a', payload: {...data}..remove('expiresAt')),
      isFalse,
    );
    expect(display('farmer-a', payload: {...data}..remove('eventId')), isFalse);
  });
}
