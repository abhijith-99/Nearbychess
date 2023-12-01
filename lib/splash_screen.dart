import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widget_tree.dart';

class ChessSplashScreen extends StatefulWidget {
  const ChessSplashScreen({Key? key}) : super(key: key);

  @override
  _ChessSplashScreenState createState() => _ChessSplashScreenState();
}

class _ChessSplashScreenState extends State<ChessSplashScreen> {

  @override
  void initState() {
    super.initState();
    // Start listening to authentication state changes
    FirebaseAuth.instance.authStateChanges().first.then((user) {
      // Wait for 4 seconds to show the splash screen
      Future.delayed(const Duration(seconds: 4), () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WidgetTree()),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Image.asset(
          'assets/Animation.gif', // Path to your GIF file
          width: 300, // Adjust the size as needed
          height: 300,
        ),
      ),
    );
  }
}
