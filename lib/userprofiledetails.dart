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
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar1.png?alt=media&token=7fc8ed85-7d37-43b7-bd46-a11f6d80ae7e",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar2.png?alt=media&token=7d77108b-91a3-451a-b633-da1e03df1ea8",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar3.png?alt=media&token=0d97a0c5-0a10-41f1-a972-3c2941a87c52",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar4.png?alt=media&token=5b398b84-8aa8-465b-8db1-111f2195e6fb",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar5.png?alt=media&token=b82e2b51-cbec-421b-a436-2ee2be88d0c2",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar6.png?alt=media&token=2612629f-0dca-4e65-951d-b7f878a6b463"
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
                child: Image.network(avatarImages[index]),
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
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0, right: 20.0), // Adjust padding as needed
          child: AppBar(
            title: Text('User Profile'), // Title for your AppBar
            elevation: 0, // Optional: Removes shadow from AppBar
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.home),
                onPressed: () {
                  // Navigate to the home page or pop until the first route
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ),
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
                          backgroundImage: NetworkImage(avatarUrl),
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
