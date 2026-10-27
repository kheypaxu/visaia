import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import 'push_message_policy.dart';

const _recipientKey = 'push_recipient_uid';
const _accountsKey = 'push_account_uids';
const _installationKey = 'push_installation_id';
const _baseUrl = String.fromEnvironment(
  'PUSH_BACKEND_URL',
  defaultValue: 'https://visaia-web.vercel.app',
);
final _local = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> visaiaBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeLocal();
  await _display(message);
}

Future<void> _initializeLocal({void Function(String?)? onTap}) async {
  await _local.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_visaia'),
    ),
    onDidReceiveNotificationResponse: (response) =>
        onTap?.call(response.payload),
  );
}

Future<void> _display(RemoteMessage message) async {
  // Data-only delivery lets us hide account details until its owner signs in.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final recipients = _savedAccounts(prefs);
  final seenKey = 'push_seen_${message.data['farmerId']}';
  final seen = prefs.getStringList(seenKey) ?? [];
  if (!shouldDisplayPush(
    recipientUids: recipients,
    data: message.data,
    now: DateTime.now(),
    seen: seen,
  )) {
    return;
  }
  final id = message.data['eventId']!;
  final presentation = pushPresentation(
    data: message.data,
    activeUid: prefs.getString(_recipientKey),
  );
  await prefs.setStringList(seenKey, [
    ...seen.skip(max(0, seen.length - 99)),
    id,
  ]);
  await _local.show(
    pushNotificationId(id),
    presentation.title,
    presentation.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'farm_reminders',
        'Farm notifications',
        channelDescription: 'Account approval and farm activity reminders',
        icon: 'ic_stat_visaia',
        largeIcon: DrawableResourceAndroidBitmap('ic_launcher_foreground'),
        importance: Importance.high,
        priority: Priority.high,
        groupKey: 'visaia_${message.data['farmerId']}',
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

List<String> _savedAccounts(SharedPreferences prefs) {
  final saved = prefs.getStringList(_accountsKey);
  if (saved != null) return saved;
  // Migrate the previous single-account registration on first launch.
  final legacy = prefs.getString(_recipientKey);
  return legacy == null ? [] : [legacy];
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  Future<void> _queue = Future.value();
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> notifyAnalysisReady({
    required String detectionId,
    required String ownerUid,
  }) async {
    if (!supported) return;
    await _display(
      RemoteMessage(
        data: {
          'eventId': 'ai_result_ready_$detectionId',
          'type': 'ai_result_ready',
          'farmerId': ownerUid,
          'detectionId': detectionId,
          'title': 'AI result ready to review',
          'body':
              'Your pest photo has been analyzed. Tap to review and assign your result.',
          'expiresAt': DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch
              .toString(),
        },
      ),
    );
  }

  Future<void> init({required void Function(String?) onTap}) async {
    if (!supported) return;
    FirebaseMessaging.onBackgroundMessage(visaiaBackgroundMessage);
    await _initializeLocal(onTap: onTap);
    final launch = await _local.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      onTap(launch?.notificationResponse?.payload);
    }
    FirebaseMessaging.onMessage.listen((message) {
      unawaited(_display(message));
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) unawaited(register(user));
    });
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(register(user));
      } else {
        unawaited(_markNoActiveAccount());
      }
      // Registration intentionally signs out while waiting for MAO approval.
      // Switching retains saved memberships; explicit logout removes its account.
    });
  }

  Future<void> register(User user) async {
    if (!supported) return Future.value();
    final prefs = await SharedPreferences.getInstance();
    final recipients = {..._savedAccounts(prefs), user.uid};
    await prefs.setStringList(_accountsKey, recipients.toList());
    await prefs.setString(_recipientKey, user.uid);
    // Existing detailed drawer entries must not remain visible after switching.
    await _redactOtherAccountNotifications(prefs, user.uid);
    String? auth;
    try {
      auth = await user.getIdToken();
    } catch (error) {
      debugPrint('Push authentication unavailable: $error');
      return;
    }
    _queue = _queue.catchError((Object _) {}).then((_) async {
      await prefs.reload();
      if (!_savedAccounts(prefs).contains(user.uid)) return;
      try {
        final permission = await FirebaseMessaging.instance.requestPermission();
        if (permission.authorizationStatus == AuthorizationStatus.denied) {
          return;
        }
        var installation = prefs.getString(_installationKey);
        if (installation == null) {
          installation = List.generate(
            32,
            (_) => Random.secure().nextInt(256),
          ).map((v) => v.toRadixString(16).padLeft(2, '0')).join();
          await prefs.setString(_installationKey, installation);
        }
        final token = await FirebaseMessaging.instance.getToken();
        await prefs.reload();
        if (token == null ||
            auth == null ||
            !_savedAccounts(prefs).contains(user.uid)) {
          return;
        }
        final response = await http
            .post(
              Uri.parse('$_baseUrl/api/notifications/device'),
              headers: {
                'Authorization': 'Bearer $auth',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'installationId': installation,
                'token': token,
              }),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          debugPrint(
            'Push registration failed (${response.statusCode}); will retry on next sign-in.',
          );
        }
      } catch (error) {
        debugPrint('Push registration unavailable: $error');
      }
    });
    return _queue;
  }

  Future<void> keepForAccountSwitch() async {
    if (!supported) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await register(user);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recipientKey);
    await _redactOtherAccountNotifications(prefs, null);
  }

  Future<void> detach({String? uid}) async {
    if (!supported) return;
    final prefs = await SharedPreferences.getInstance();
    final recipient = uid ?? prefs.getString(_recipientKey);
    if (recipient == null) return;
    final remaining = _savedAccounts(
      prefs,
    ).where((id) => id != recipient).toList();
    await prefs.setStringList(_accountsKey, remaining);
    // Clear first, even offline: deliveries for the logged-out account are blocked.
    await prefs.remove(_recipientKey);
    await _cancelAccountNotifications(prefs, [recipient]);
    try {
      final auth = await FirebaseAuth.instance.currentUser?.getIdToken();
      final installation = prefs.getString(_installationKey);
      if (auth != null && installation != null) {
        await http
            .delete(
              Uri.parse('$_baseUrl/api/notifications/device'),
              headers: {
                'Authorization': 'Bearer $auth',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'installationId': installation}),
            )
            .timeout(const Duration(seconds: 5));
      }
      // Other saved accounts share this token and must keep receiving messages.
      if (remaining.isEmpty) await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint(
        'Push detach deferred; old recipient is blocked locally: $error',
      );
    }
  }
}

Future<void> _markNoActiveAccount() async {
  final prefs = await SharedPreferences.getInstance();
  if (FirebaseAuth.instance.currentUser != null) return;
  await prefs.setStringList(_accountsKey, _savedAccounts(prefs));
  await prefs.remove(_recipientKey);
  await _redactOtherAccountNotifications(prefs, null);
}

Future<void> _redactOtherAccountNotifications(
  SharedPreferences prefs,
  String? activeUid,
) async {
  await _cancelAccountNotifications(
    prefs,
    _savedAccounts(prefs).where((uid) => uid != activeUid),
  );
}

Future<void> _cancelAccountNotifications(
  SharedPreferences prefs,
  Iterable<String> uids,
) async {
  final active = (await _local.getActiveNotifications())
      .map((notification) => notification.id)
      .toSet();
  for (final uid in uids) {
    for (final event in prefs.getStringList('push_seen_$uid') ?? <String>[]) {
      // Cancel previously displayed details. Future messages use the generic preview.
      final id = pushNotificationId(event);
      if (active.contains(id)) await _local.cancel(id);
    }
  }
}
