import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mychessapp/pages/userhome.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  bool isReferralCodeValid = false;
  String verificationMessage = '';
  String? _selectedLocation;
  String? _selectedAvatar;
  bool isAvatarListVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> verifyReferralCode() async {
    String referralCode = _referralCodeController.text.trim();
    if (referralCode.isNotEmpty) {
      var referrerDoc = await FirebaseFirestore.instance.collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (referrerDoc.docs.isNotEmpty) {
        setState(() {
          isReferralCodeValid = true;
          verificationMessage = 'Valid Referral Code';
        });
      } else {
        setState(() {
          isReferralCodeValid = false;
          verificationMessage = 'Invalid Referral Code';
        });
      }
    }
  }

  Future<void> createUserProfile() async {
    if (_nameController.text.isNotEmpty &&
        _selectedLocation != null &&
        _selectedAvatar != null) {
      try {
        CollectionReference users =
        FirebaseFirestore.instance.collection('users');
        String userId = FirebaseAuth.instance.currentUser!.uid;
        String referralCode = generateReferralCode(userId);
        DateTime now = DateTime.now();
        await users.doc(userId).set({
          'uid': userId,
          'name': _nameController.text,
          'location': _selectedLocation,
          'avatar': _selectedAvatar,
          'isOnline': true,
          'inGame': false,
          'chessCoins': 100,
          'lastLoginDate': Timestamp.fromDate(now),
          'consecutiveLoginDays': 0,
          'bonusReadyToClaim': false,
          'referralCode': referralCode,
          'appliedReferralCode': _referralCodeController.text.trim(),
        });

        // If a referral code was applied, handle the referral bonus
        if (isReferralCodeValid) {
          await applyReferralBonus(userId, _referralCodeController.text.trim());
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const UserHomePage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating profile: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
    }
  }

  Future<void> applyReferralBonus(String newUserId, String appliedReferralCode) async {
    // Award bonus to the new user
    await FirebaseFirestore.instance.collection('users').doc(newUserId)
        .update({'chessCoins': FieldValue.increment(100)}); // Increment by 100

    // Find the referrer's user ID and name using the referral code
    var referrerDoc = await FirebaseFirestore.instance.collection('users')
        .where('referralCode', isEqualTo: appliedReferralCode)
        .limit(1)
        .get();

    if (referrerDoc.docs.isNotEmpty) {
      // Award bonus to the referrer
      var referrerUserData = referrerDoc.docs.first.data();
      String referrerUserId = referrerDoc.docs.first.id;
      String referrerName = referrerUserData['name']; // Assuming 'name' field exists

      await FirebaseFirestore.instance.collection('users').doc(referrerUserId)
          .update({'chessCoins': FieldValue.increment(100)}); // Increment by 100

      // Update the referrer's document with referral bonus info
      await FirebaseFirestore.instance.collection('users').doc(referrerUserId).update({
        'referralBonusInfo': {
          'type': 'referrer',
          'referredName': (await FirebaseFirestore.instance.collection('users').doc(newUserId).get()).data()?['name'],
        }
      });

      // Update the new user's document with referral bonus info
      await FirebaseFirestore.instance.collection('users').doc(newUserId).update({
        'referralBonusInfo': {
          'type': 'received',
          'referrerName': referrerName,
        }
      });
    }
  }


  String generateReferralCode(String userId) {
    return "100NBC${userId.substring(0, min(6, userId.length))}";
  }

  Widget buildAvatarSelector() {
    return Column(
      children: [
        ListTile(
          title: const Text('Choose Avatar'),
          trailing: IconButton(
            icon: Icon(isAvatarListVisible
                ? Icons.arrow_upward
                : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                isAvatarListVisible = !isAvatarListVisible;
              });
            },
          ),
          onTap: () {
            setState(() {
              isAvatarListVisible = !isAvatarListVisible;
            });
          },
        ),
        if (isAvatarListVisible) buildAvatarGrid(),
      ],
    );
  }




  Widget buildAvatarGrid() {
    List<String> avatarImages = [
      'assets/avatars/avatar1.png',
      'assets/avatars/avatar2.png',
      'assets/avatars/avatar3.png',
      'assets/avatars/avatar4.png',
      'assets/avatars/avatar5.png',
      'assets/avatars/avatar6.png',
      // ... Add paths for all avatar images
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: avatarImages.length,
      itemBuilder: (context, index) {
        bool isSelected = avatarImages[index] == _selectedAvatar;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedAvatar = avatarImages[index];
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border:
              isSelected ? Border.all(color: Colors.blue, width: 3) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Opacity(
              opacity: isSelected ? 1.0 : 0.5,
              child: Image.asset(avatarImages[index]),
            ),
          ),
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              'assets/mono-white.jpg', // Replace with your image asset
              fit: BoxFit.cover,
            ),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      const SizedBox(height: 50),
                      const Text(
                        'Create User Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          labelStyle: const TextStyle(color: Colors.black),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                            borderRadius: BorderRadius.circular(8.0), // Border radius
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: Colors.black),
                            borderRadius: BorderRadius.circular(8.0), // Border radius
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 10.0), // Adjust vertical padding
                        ),
                        style: const TextStyle(color: Colors.black),
                      ),

                      buildAvatarSelector(),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _referralCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Referral Code (Optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(isReferralCodeValid ? Icons.check : Icons.search),
                            onPressed: verifyReferralCode,
                          ),
                        ],
                      ),
                      if (verificationMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            verificationMessage,
                            style: TextStyle(
                              color: isReferralCodeValid ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: createUserProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Transparent background
                          foregroundColor: Colors.black, // Black text color
                          elevation: 0, // Remove elevation shadow
                          side: const BorderSide(color: Colors.black, width: 1.3), // Thicker black border
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text('Save Profile'),
                      ),



                    ],
                  ),
                ),
              ),
            ),


          ],
        ),

      ),
    );
  }


}
