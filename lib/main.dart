import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mychessapp/pages/access_denial.dart';
import 'package:mychessapp/pages/login_register_page.dart';
import 'package:mychessapp/pages/user_profile.dart';
import 'package:mychessapp/pages/userhome.dart';
import 'dart:async';
import 'package:mychessapp/splash_screen.dart';
import 'package:mychessapp/userprofiledetails.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'web_listener_stub.dart'
  if (dart.library.html) 'web_listener.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: "AIzaSyA5LntFnqarzEsZoDAx8WuO98rnLaZjFzA",
          appId: "1:820296910788:web:00ca69115e86ddd8cd8691",
          messagingSenderId: "820296910788",
          projectId: "chessapp-68652",
          databaseURL: "https://chessapp-68652-default-rtdb.firebaseio.com/"));
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
    } else if (state == AppLifecycleState.resumed) {
// App is in the foreground, update the user status to online
      _updateUserStatus(true);
    }
  }

  Future<void> _updateUserStatus(bool isOnline) async {
    try {
      String? userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null)
        // return;
        {
        var usersRef = FirebaseFirestore.instance.collection('users');
        var doc = await usersRef.doc(userId).get();

        // Check if the user is in a game before setting them offline
        if (doc.exists) {
          var data = doc.data();
          bool inGame = data?['inGame'] ?? false;

          // Only update online status if the user is not in a game or if setting them online
          if (isOnline || !inGame) {
            await usersRef.doc(userId).update({'isOnline': isOnline});
          }
        }
      }


    } catch (e) {
      print('Error updating user status: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    // Your existing theme data and MaterialApp setup
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
      theme: ThemeData(
          primarySwatch: primaryBlack),
      home: Builder(
        builder: (context) {
          if (MediaQuery.of(context).size.width < 700) {
            // Instead of showing a dialog, navigate to the AccessDeniedPage
            Future.microtask(() => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AccessDeniedPage()),
            ));
          }
          return const ChessSplashScreen(); // Adjust based on your initial screen
        },
      ),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      routes: {
        // Your routes
        '/user_profile_details': (context) => const UserProfileDetailsPage(),
        '/login_register': (context) => const LoginRegisterPage(), // other routes...
        '/home': (context) => const UserHomePage(),
        '/profile': (context) => const UserProfilePage(),
      },
    );
  }

}
