//splash
import 'package:flutter/material.dart';
import 'dart:async';
import 'widget_tree.dart'; // Replace with your actual main screen

class ChessSplashScreen extends StatefulWidget {
  const ChessSplashScreen({super.key});

  @override
  _ChessSplashScreenState createState() => _ChessSplashScreenState();
}

class _ChessSplashScreenState extends State<ChessSplashScreen> {

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const WidgetTree()),
      );
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