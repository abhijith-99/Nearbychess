//splash
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mychessapp/pages/login_register_page.dart';
import 'package:mychessapp/pages/userhome.dart';
import 'dart:async';


class ChessSplashScreen extends StatefulWidget {
  const ChessSplashScreen({super.key});

  @override
  _ChessSplashScreenState createState() => _ChessSplashScreenState();
}

class _ChessSplashScreenState extends State<ChessSplashScreen> {

  @override
  void initState() {
    super.initState();
    _navigateToNextPage();
  }

  void _navigateToNextPage() async {
    // Wait for a minimum duration (e.g., 3 seconds) for the splash screen

    // Then check the authentication state
    FirebaseAuth.instance.authStateChanges().first.then((User? user) async {
      if (user == null) {
        await Future.delayed(Duration(seconds: 3));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginRegisterPage()));
      } else {
        await Future.delayed(Duration(seconds: 3));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const UserHomePage()));
      }
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
