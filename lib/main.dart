import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visaia/screens/login_screens/login.dart';

// Import only the screens you need
import 'screens/login_screens/get_started.dart';
import 'screens/login_screens/registration.dart';

void main() {
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
      initialRoute: '/',
      routes: {
        '/': (context) => const GetStartedPage(),
        '/register': (context) => const RegistrationPage(),
        '/login': (context) => const LoginPage(),
        
      },
    );
  }
}