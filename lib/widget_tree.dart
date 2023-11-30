import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mychessapp/pages/login_register_page.dart';
import 'package:mychessapp/pages/user_profile.dart';
import 'package:mychessapp/pages/userhome.dart';



class WidgetTree extends StatelessWidget {
  const WidgetTree({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            // User is logged in
            final user = snapshot.data!;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.done) {
                  if (userSnapshot.data != null && userSnapshot.data!.exists) {
                    // User profile exists, navigate to ChessBoard;
                    return const UserHomePage();
                  } else {
                    // User profile does not exist, navigate to UserProfilePage
                    return const UserProfilePage();
                  }
                }
                // Waiting for user profile data
                return const Center(child: CircularProgressIndicator());
              },
            );
          } else {
            // No user is logged in, show login page
            return const LoginRegisterPage();
          }
        }
        // Waiting for authentication state
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}