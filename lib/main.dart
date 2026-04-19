import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:visaia/screens/root_screen.dart';
import 'package:visaia/screens/auth/registration_screen.dart';
import 'package:visaia/screens/auth/auth_gate.dart';
import 'package:visaia/screens/onboarding/get_started_screen.dart';
import 'package:visaia/screens/onboarding/onboarding_screens.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VISAAIA - Farm Protection App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: GoogleFonts.inter().fontFamily,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/get-started',
      routes: {
        // FIRST SCREEN
        '/get-started': (context) => const GetStartedPage(),

        // AUTH
        '/auth-gate': (context) => const AuthGate(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),

        // ONBOARDING
        '/onboarding': (context) => OnboardingScreen(
          onFinish: () {
            Navigator.pushReplacementNamed(context, '/root');
          },
        ),

        // MAIN APP
        '/root': (context) => const RootLayout(),
        
      },
    );
  }
}