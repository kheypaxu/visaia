import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:visaia/core/providers/farm_provider.dart';
import 'package:visaia/screens/auth/auth_gate.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:visaia/screens/root_screen.dart';
import 'package:visaia/screens/auth/registration_screen.dart';
import 'package:visaia/screens/onboarding/get_started_screen.dart';
import 'package:visaia/screens/onboarding/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'package:visaia/services/local_write_service.dart';
import 'package:visaia/services/push_notification_service.dart';
import 'package:visaia/services/auth_service.dart';
import 'package:visaia/screens/logging_screens/daily_log_screen.dart';
import 'package:visaia/screens/logging_screens/field_scouting_screen.dart';
import 'dart:convert';
import 'firebase_options.dart';
import 'package:visaia/widgets/app_version_gate.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
String? _pendingPush;
bool _handlingPush = false;
bool _pushAwaitingSignIn = false;

Future<void> _openPendingPush() async {
  final payload = _pendingPush;
  if (_handlingPush || payload == null || appNavigatorKey.currentState == null) {
    return;
  }
  _handlingPush = true;
  _pendingPush = null;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final expires = int.tryParse(data['expiresAt']?.toString() ?? '');
    if (expires == null || DateTime.now().millisecondsSinceEpoch >= expires) {
      _pushAwaitingSignIn = false;
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid != data['farmerId']) {
      final name = data['accountName'] as String? ?? 'this saved account';
      if (uid != null) {
        final context = appNavigatorKey.currentContext!;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Sign in to $name?'),
            content: const Text(
              'You are using another account. Switch to view this notification. Saved accounts will keep receiving notifications.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign in'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await AuthService().signOut(keepNotifications: true);
      }
      _pendingPush = payload;
      _pushAwaitingSignIn = true;
      appNavigatorKey.currentState!.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
        arguments: <String, dynamic>{
          'email': data['accountEmail'] ?? '',
          'autoFillMessage': 'Sign in to $name to view this notification.',
        },
      );
      return;
    }
    _pushAwaitingSignIn = false;
    final cycleId = data['cycleId'] as String? ?? '';
    if (data['type'] == 'daily_log_reminder' && cycleId.isNotEmpty) {
      appNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => DailyLogFormScreen(
            userId: uid,
            cycleId: cycleId,
            shouldAssignCycle: false,
          ),
        ),
      );
    } else if (data['type'] == 'scouting_reminder' && cycleId.isNotEmpty) {
      appNavigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              FieldScoutingFormScreen(userId: uid, cycleId: cycleId),
        ),
      );
    } else {
      appNavigatorKey.currentState!.pushNamed('/login');
    }
  } catch (error) {
    debugPrint('Unable to open push notification: $error');
  } finally {
    _handlingPush = false;
  }
}

class _PushNavigatorObserver extends NavigatorObserver {
  void _ready(Route<dynamic>? route) {
    if (route?.settings.name == '/splash') return;
    if (_pushAwaitingSignIn) {
      if (route?.settings.name == '/login') return;
      try {
        final recipient =
            (jsonDecode(_pendingPush ?? '{}')
                as Map<String, dynamic>)['farmerId'];
        if (FirebaseAuth.instance.currentUser?.uid != recipient) {
          if (route?.settings.name == '/root') {
            _pendingPush = null;
            _pushAwaitingSignIn = false;
          }
          return;
        }
      } catch (_) {
        return;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingPush());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _ready(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _ready(newRoute);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Configure Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 3. Initialize offline services
  final connectivityService = ConnectivityService();
  await connectivityService.init();

  final authCacheService = AuthCacheService();
  await authCacheService.init();
  await LocalWriteService.init();
  LocalWriteService.setUser(
    FirebaseAuth.instance.currentUser?.uid ?? authCacheService.cachedUid,
  );
  FirebaseAuth.instance.authStateChanges().listen((user) {
    LocalWriteService.setUser(user?.uid);
  });

  final syncService = OfflineSyncService();
  await syncService.init();

  try {
    await PushNotificationService.instance.init(
      onTap: (payload) {
        _pushAwaitingSignIn = false;
        _pendingPush = payload;
        if (appNavigatorKey.currentState != null) _openPendingPush();
      },
    );
  } catch (error) {
    debugPrint('Push notifications unavailable: $error');
  }

  runApp(
    ChangeNotifierProvider(create: (_) => FarmProvider(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, this.initialRoute = '/splash'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: LocalWriteService.messengerKey,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [_PushNavigatorObserver()],
      title: 'VISAAIA - Farm Protection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: GoogleFonts.inter().fontFamily,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      builder: (context, child) =>
          AppVersionGate(navigatorKey: appNavigatorKey, child: child!),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        if (settings.name != '/get-started') return null;
        return PageRouteBuilder<void>(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 650),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GetStartedPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (MediaQuery.disableAnimationsOf(context)) return child;
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/auth-gate': (context) => const AuthGate(),
        '/root': (context) => const VisaiaAppRoot(),
      },
    );
  }
}
