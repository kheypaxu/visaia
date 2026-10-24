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
const _installationKey = 'push_installation_id';
const _baseUrl = String.fromEnvironment(
  'PUSH_BACKEND_URL', defaultValue: 'https://visaia-web.vercel.app',
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
    onDidReceiveNotificationResponse: (response) => onTap?.call(response.payload),
  );
}

Future<void> _display(RemoteMessage message) async {
  // Data-only messages let us reject stale deliveries after account switches.
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final seenKey = 'push_seen_${prefs.getString(_recipientKey)}';
  final seen = prefs.getStringList(seenKey) ?? [];
  if (!shouldDisplayPush(recipientUid: prefs.getString(_recipientKey),
      data: message.data, now: DateTime.now(), seen: seen)) return;
  final id = message.data['eventId']!;
  await prefs.setStringList(seenKey, [...seen.skip(max(0, seen.length - 99)), id]);
  await _local.show(
    id.codeUnits.fold<int>(0, (value, unit) => (value * 31 + unit) & 0x7fffffff),
    message.data['title'] ?? 'VISAIA',
    message.data['body'] ?? '',
    const NotificationDetails(android: AndroidNotificationDetails(
      'farm_reminders', 'Farm notifications',
      channelDescription: 'Account approval and farm activity reminders',
      importance: Importance.high, priority: Priority.high,
    )),
    payload: jsonEncode(message.data),
  );
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();
  Future<void> _queue = Future.value();
  int _generation = 0;
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
      if (user != null) unawaited(register(user));
      // Registration intentionally signs out while waiting for MAO approval.
      // Explicit logout clears the recipient through detach() instead.
    });
  }

  Future<void> register(User user) async {
    if (!supported) return Future.value();
    final generation = ++_generation;
    final prefs = await SharedPreferences.getInstance();
    if (generation != _generation) return;
    final previous = prefs.getString(_recipientKey);
    await prefs.setString(_recipientKey, user.uid);
    if (previous != user.uid) await _local.cancelAll();
    _queue = _queue.catchError((Object _) {}).then((_) async {
      if (generation != _generation) return;
      try {
        final permission = await FirebaseMessaging.instance.requestPermission();
        if (permission.authorizationStatus == AuthorizationStatus.denied) return;
        var installation = prefs.getString(_installationKey);
        if (installation == null) {
          installation = List.generate(32, (_) => Random.secure().nextInt(256))
              .map((v) => v.toRadixString(16).padLeft(2, '0')).join();
          await prefs.setString(_installationKey, installation);
        }
        final token = await FirebaseMessaging.instance.getToken();
        final auth = await user.getIdToken();
        if (token == null || auth == null || generation != _generation) return;
        final response = await http.post(
          Uri.parse('$_baseUrl/api/notifications/device'),
          headers: {'Authorization': 'Bearer $auth', 'Content-Type': 'application/json'},
          body: jsonEncode({'installationId': installation, 'token': token}),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          debugPrint('Push registration failed (${response.statusCode}); will retry on next sign-in.');
        }
      } catch (error) {
        debugPrint('Push registration unavailable: $error');
      }
    });
    return _queue;
  }

  Future<void> detach() async {
    if (!supported) return;
    ++_generation;
    final prefs = await SharedPreferences.getInstance();
    // Clear first, even offline: background deliveries must not reveal old accounts.
    await prefs.remove(_recipientKey);
    await _local.cancelAll();
    try {
      final auth = await FirebaseAuth.instance.currentUser?.getIdToken();
      final installation = prefs.getString(_installationKey);
      if (auth != null && installation != null) {
        await http.delete(Uri.parse('$_baseUrl/api/notifications/device'),
          headers: {'Authorization': 'Bearer $auth', 'Content-Type': 'application/json'},
          body: jsonEncode({'installationId': installation}),
        ).timeout(const Duration(seconds: 5));
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (error) {
      debugPrint('Push detach deferred; old recipient is blocked locally: $error');
    }
  }
}
