import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({Key? key}) : super(key: key);

  // Function to launch URLs
  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('oopss😢'),
        centerTitle: true,
        leading: Container(), // This removes the back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                "It looks like you're on a mobile device, and this app shines on larger screens!",
              textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold, // Makes the font weight bold
                  fontSize: 16, // Increases the font size
                  // You can also specify the font family if you have one in mind
                ),
              ),

              const SizedBox(height: 20), // Adds space between the text and the buttons
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green, // Play Store color
                  primary: Colors.white,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.android),
                    SizedBox(width: 10),
                    Text('Play Store'),
                  ],
                ),
                onPressed: () {
                  // Placeholder for Play Store link
                  // _launchURL('https://play.google.com/store/apps/details?id=yourAppId');
                },
              ),
              const SizedBox(height: 5), // Adds space between buttons
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('or', textAlign: TextAlign.center),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.blue, // App Store color
                  primary: Colors.white,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apple),
                    SizedBox(width: 10),
                    Text('App Store'),
                  ],
                ),
                onPressed: () {
                  // Placeholder for App Store link
                  // _launchURL('https://apps.apple.com/app/idyourAppId');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
