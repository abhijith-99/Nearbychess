import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class UserProfileDetailsPage extends StatefulWidget {
  const UserProfileDetailsPage({Key? key}) : super(key: key);

  @override
  _UserProfileDetailsPageState createState() => _UserProfileDetailsPageState();
}

class _UserProfileDetailsPageState extends State<UserProfileDetailsPage> {
  // ... existing variables and functions

  // List of avatar URLs or asset paths
  final List<String> avatarImages = [
    'assets/avatars/avatar1.png',
    'assets/avatars/avatar2.png',
    'assets/avatars/avatar3.png',
    'assets/avatars/avatar4.png',
    'assets/avatars/avatar5.png',
    'assets/avatars/avatar6.png',
  ];

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/login_register', (Route<dynamic> route) => false);
    } catch (error) {
      print(error.toString());
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.exists ? userDoc.data() as Map<String, dynamic> : null;
  }

  Future<void> updateAvatar(String newAvatar) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'avatar': newAvatar});
    setState(() {});
  }

  void showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.0,
          ),
          itemCount: avatarImages.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                updateAvatar(avatarImages[index]);
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Image.asset(avatarImages[index]),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> shareReferralCode() async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        String referralCode = userData['referralCode'];
        String shareMessage = "Join me on the ultimate chess battleground! Use my code $referralCode to start your journey with extra 100 NBC rewards. Download now: https://example.com/download";
        Share.share(shareMessage);
        print("Referral Code: $referralCode");
        print("Share Message: $shareMessage");
      }
    } catch (error) {
      print('Failed to share: $error');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            var userData = snapshot.data!;
            String avatarUrl = userData['avatar'];
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: AssetImage(avatarUrl),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: showAvatarSelection,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userData['name'] ?? 'Username',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.3,
                      child: ElevatedButton(
                        onPressed: signOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18.0),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Poppins',
                          ),
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shareReferralCode,
        label: const Text('Share And Win 100'),
        icon: const Icon(Icons.share),
        backgroundColor: Colors.blue,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
