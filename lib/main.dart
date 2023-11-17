import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:mychessapp/pages/login_register_page.dart';
import 'dart:async';
import 'package:mychessapp/splash_screen.dart';
import 'package:mychessapp/userprofiledetails.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: const FirebaseOptions(apiKey: "AIzaSyA5LntFnqarzEsZoDAx8WuO98rnLaZjFzA", appId: "1:820296910788:web:00ca69115e86ddd8cd8691", messagingSenderId: "820296910788", projectId: "chessapp-68652"));
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    MaterialColor primaryBlack = const MaterialColor(0xFF000000, {
      50: Color(0xFF000000),
      100: Color(0xFF000000),
      200: Color(0xFF000000),
      300: Color(0xFF000000),
      400: Color(0xFF000000),
      500: Color(0xFF000000),
      600: Color(0xFF000000),
      700: Color(0xFF000000),
      800: Color(0xFF000000),
      900: Color(0xFF000000),
    });

    return MaterialApp(
      title: 'Chess Game',
      theme: ThemeData(primarySwatch: primaryBlack), // Use the custom primaryBlack MaterialColor
      home: const ChessSplashScreen(),
      debugShowCheckedModeBanner: false,
      // Change
      routes: {
        '/user_profile_details': (context) => const UserProfileDetailsPage(),
        '/login_register': (context) => const LoginRegisterPage(),
        // other routes...
      },
    );
  }
}

