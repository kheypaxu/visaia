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
import 'package:firebase_core/firebase_core.dart';
import 'package:visaia/services/auth_cache_service.dart';
import 'package:visaia/services/connectivity_service.dart';
import 'package:visaia/services/offline_sync_service.dart';
import 'firebase_options.dart';
import 'package:visaia/widgets/app_version_gate.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

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

  final syncService = OfflineSyncService();
  await syncService.init();

  // Check if session is already cached or active
  final hasActiveUser = FirebaseAuth.instance.currentUser != null;
  final hasCachedSession = authCacheService.hasCachedSession;
  if (hasActiveUser || hasCachedSession) {
    authCacheService.isOfflineSessionActive = true;
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => FarmProvider(),
      child: MyApp(
        initialRoute: hasActiveUser || hasCachedSession
            ? '/auth-gate'
            : '/get-started',
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, this.initialRoute = '/get-started'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
      routes: {
        '/get-started': (context) => const GetStartedPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/auth-gate': (context) => const AuthGate(),
        '/root': (context) => const VisaiaAppRoot(),
      },
    );
  }
}
