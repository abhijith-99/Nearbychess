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
        if (!snapshot.hasData) {
          // No user logged in
          return const LoginRegisterPage();
        }

        // User is logged in, check if profile exists
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
          builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              // Waiting for user profile data
              return const SizedBox.shrink(); // Or a placeholder if you prefer
            }

            if (userSnapshot.data != null && userSnapshot.data!.exists) {
              // User profile exists
              return const UserHomePage();
            } else {
              // User profile does not exist
              return const UserProfilePage();
            }
          },
        );
      },
    );
  }
}
