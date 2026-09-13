import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:visaia/screens/root_screen.dart';
import 'package:visaia/services/auth_cache_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cacheService = AuthCacheService();

    // If offline session is explicitly active and has cached session
    if (cacheService.isOfflineSessionActive && cacheService.hasCachedSession) {
      return const VisaiaAppRoot();
    }

    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If we are waiting for data, show loader
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8DBA60)),
            );
          }

          // If the stream receives a valid user, transition to App Home
          if (snapshot.hasData && snapshot.data != null) {
            cacheService.isOfflineSessionActive = true;
            return const VisaiaAppRoot();
          }

          // If offline and previously cached session exists, let user in directly
          if (cacheService.hasCachedSession && cacheService.cachedUid != null) {
            cacheService.isOfflineSessionActive = true;
            return const VisaiaAppRoot();
          }

          // Otherwise return login screen
          return const LoginPage();
        },
      ),
    );
  }
}
