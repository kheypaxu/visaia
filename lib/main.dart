import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/auth/login_screen.dart';
import 'package:visaia/screens/root_screen.dart';
import 'package:visaia/screens/auth/registration_screen.dart';
import 'package:visaia/screens/onboarding/get_started_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegistrationPage(),

        // MAIN APP
        '/root': (context) => const VisaiaAppRoot(),
        
      },
    );
  }
}