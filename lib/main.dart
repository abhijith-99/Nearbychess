import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mychessapp/pages/login_register_page.dart';
import 'dart:async';
import 'package:mychessapp/splash_screen.dart';
import 'package:mychessapp/userprofiledetails.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'web_listener_stub.dart'
if (dart.library.html) 'web_listener.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyA5LntFnqarzEsZoDAx8WuO98rnLaZjFzA",
          appId: "1:820296910788:web:00ca69115e86ddd8cd8691",
          messagingSenderId: "820296910788",
          projectId: "chessapp-68652"));
  runApp(const ChessApp());
}

class ChessApp extends StatefulWidget {
  const ChessApp({Key? key}) : super(key: key);

  @override
  _ChessAppState createState() => _ChessAppState();
}

class _ChessAppState extends State<ChessApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      setupBeforeUnloadListener(() async {
        await _updateUserStatus(false);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // User is leaving the app, update the user status
      _updateUserStatus(false);
    }else if (state == AppLifecycleState.resumed) {
      // App is in the foreground, update the user status to online
      _updateUserStatus(true);
    }
  }


  Future<void> _updateUserStatus(bool isOnline) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      CollectionReference users = FirebaseFirestore.instance.collection('users');
      await users.doc(userId).update({'isOnline': isOnline, 'inGame': false});
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

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
      routes: {
        '/user_profile_details': (context) => const UserProfileDetailsPage(),
        '/login_register': (context) => const LoginRegisterPage(),
        // other routes...
      },
    );
  }
}

