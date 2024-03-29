import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mychessapp/pages/userhome.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'dart:ui';
import 'geocoding_stub.dart' if (dart.library.html) 'geocoding_web.dart';
import 'geocoding_web.dart';
// import 'geocoding_web.dart' if (dart.library.html) 'geocoding_web.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  String? _selectedAvatar;
  bool isAvatarListVisible = false;
  bool isReferralCodeValid = false;
  String verificationMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }




  Future<void> verifyReferralCode() async {
    String referralCode = _referralCodeController.text.trim();
    if (referralCode.isNotEmpty) {
      var referrerDoc = await FirebaseFirestore.instance
          .collection('users')
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
    print("createUserProfile called");
    loc.Location location = loc.Location();
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    loc.LocationData _locationData;

    try {
      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          throw Exception('Location service not enabled');
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != loc.PermissionStatus.granted) {
          throw Exception('Location permission not granted');
        }
      }

      _locationData = await location.getLocation();
      print(
          "Location Data: Latitude: ${_locationData.latitude}, Longitude: ${_locationData.longitude}");

      if (_locationData.latitude != null && _locationData.longitude != null) {
        String detailedLocationName;
        String city;
        // Check if running on the web
        if (kIsWeb) {
          // Use web implementation
          detailedLocationName = await getPlaceFromCoordinates(
            _locationData.latitude!,
            _locationData.longitude!,
          );
          print(" web $detailedLocationName");
        } else {
          // Use mobile implementation
          List<geocoding.Placemark> placemarks =
          await geocoding.placemarkFromCoordinates(
            _locationData.latitude!,
            _locationData.longitude!,
          );
          if (placemarks.isNotEmpty) {
            geocoding.Placemark place = placemarks.first;
            detailedLocationName = place.subLocality ??
                place.locality ??
                place.subAdministrativeArea ??
                place.administrativeArea ??
                'Unknown';

            // city = place.subLocality ?? place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? 'Unknown';
          } else {
            throw Exception('Geocoding returned no results');
          }
        }

        city = await getPlaceFromCoordinates(
          _locationData.latitude!,
          _locationData.longitude!,
        );
        print("City name: $city");

        if (_nameController.text.isNotEmpty && _selectedAvatar != null) {
          CollectionReference users =
          FirebaseFirestore.instance.collection('users');
          String userId = FirebaseAuth.instance.currentUser!.uid;
          String referralCode = generateReferralCode(userId);
          DateTime now = DateTime.now();
          await users.doc(userId).set({
            'uid': userId,
            'name': _nameController.text,
            'avatar': _selectedAvatar,
            'isOnline': true,
            'inGame': false,
            'latitude': _locationData.latitude,
            'longitude': _locationData.longitude,
            'location': detailedLocationName,
            'city': city,
            'chessCoins': 100,
            'lastLoginDate': Timestamp.fromDate(now),
            'consecutiveLoginDays': 0,
            'bonusReadyToClaim': false,
            'referralCode': referralCode,
            'appliedReferralCode': _referralCodeController.text.trim(),
          }, SetOptions(merge: true));

          // Check if a referral code was applied and is valid
          if (_referralCodeController.text.trim().isNotEmpty && isReferralCodeValid) {
            await applyReferralBonus(userId, _referralCodeController.text.trim());
          }

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserHomePage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please fill in all fields')),
          );
        }
      } else {
        throw Exception('Invalid location coordinates');
      }
    } catch (e) {
      print('Error in createUserProfile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error in creating profile: $e')),
      );
    }
  }

  Future<void> applyReferralBonus(
      String newUserId, String appliedReferralCode) async {
    // Award bonus to the new user
    await FirebaseFirestore.instance
        .collection('users')
        .doc(newUserId)
        .update({'chessCoins': FieldValue.increment(100)}); // Increment by 100

    // Find the referrer's user ID and name using the referral code
    var referrerDoc = await FirebaseFirestore.instance
        .collection('users')
        .where('referralCode', isEqualTo: appliedReferralCode)
        .limit(1)
        .get();

    if (referrerDoc.docs.isNotEmpty) {
      // Award bonus to the referrer
      var referrerUserData = referrerDoc.docs.first.data();
      String referrerUserId = referrerDoc.docs.first.id;
      String referrerName =
      referrerUserData['name']; // Assuming 'name' field exists

      await FirebaseFirestore.instance
          .collection('users')
          .doc(referrerUserId)
          .update(
          {'chessCoins': FieldValue.increment(100)}); // Increment by 100

      // Update the referrer's document with referral bonus info
      await FirebaseFirestore.instance
          .collection('users')
          .doc(referrerUserId)
          .update({
        'referralBonusInfo': {
          'type': 'referrer',
          'referredName': (await FirebaseFirestore.instance
              .collection('users')
              .doc(newUserId)
              .get())
              .data()?['name'],
        }
      });

      // Update the new user's document with referral bonus info
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newUserId)
          .update({
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


  List<String> avatarUrls = [
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar1.png?alt=media&token=7fc8ed85-7d37-43b7-bd46-a11f6d80ae7e",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar2.png?alt=media&token=7d77108b-91a3-451a-b633-da1e03df1ea8",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar3.png?alt=media&token=0d97a0c5-0a10-41f1-a972-3c2941a87c52",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar4.png?alt=media&token=5b398b84-8aa8-465b-8db1-111f2195e6fb",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar5.png?alt=media&token=b82e2b51-cbec-421b-a436-2ee2be88d0c2",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar6.png?alt=media&token=2612629f-0dca-4e65-951d-b7f878a6b463"
  ];

  Widget buildAvatarSelector() {
    return Offstage(
      offstage: !isAvatarListVisible,
      child: Container(
        height: 50.0, // Set the height
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
          itemCount: avatarUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAvatar = avatarUrls[index];
                });
              },
              child: Container(
                width: 65.0,
                padding: const EdgeInsets.all(2),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedAvatar == avatarUrls[index]
                        ? Colors.blue
                        : Colors.transparent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(avatarUrls[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget buildAvatarRow() {
    return Container(
      height: 50.0, // Set the height of the container that holds the list view
      child: ListView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: avatarUrls.length,
        itemBuilder: (context, index) {
          bool isSelected = avatarUrls[index] == _selectedAvatar;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedAvatar = avatarUrls[index];
              });
            },
            child: Container(
              width: 50.0,
              // Approximate width to match the height
              padding: const EdgeInsets.all(2),
              // Reduced padding
              margin: const EdgeInsets.symmetric(horizontal: 4),
              // Spacing between items
              decoration: BoxDecoration(
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.network(avatarUrls[index]),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _selectedAvatar = _selectedAvatar ?? 'https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar-default.png?alt=media&token=7f9fc5da-2c17-4ec4-b5d1-22e46ad8bd33';

    var screenSize = MediaQuery.of(context).size;
    double sidePadding = screenSize.width * 0.3; // Adjust the padding value as needed
    double verticalPadding = screenSize.height * 0.3;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Stack(
          // Use Stack to overlay widgets
          fit: StackFit.expand, // Make Stack fill the screen
          children: <Widget>[
            Image.asset(
              'assets/mono-white.jpg', // This is your background image
              fit: BoxFit.cover, // Cover the entire screen
            ),
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: sidePadding, vertical: verticalPadding),
                  child: Container(
                    width:
                    double.infinity, // Ensure the container fills the width
                    padding: EdgeInsets.all(20.0), // Padding inside the box
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.20), // Semi-transparent white
                      border: Border.all(color: Colors.black26), // Blue border
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.10), // Shadow color
                          spreadRadius: 5,
                          blurRadius: 8,
                          offset: Offset(0, 5), // Position of shadow
                        ),
                      ],
                      borderRadius:
                      BorderRadius.circular(12), // Rounded corners
                    ),
                    child: Column(
                      children: <Widget>[
                        const Text(
                          'Create User Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[

                            GestureDetector(
                              onTap: () {
                                // Handle your avatar selection or image picking logic here
                                setState(() {
                                  isAvatarListVisible = !isAvatarListVisible;
                                });

                              },
                              child: Stack(
                                alignment: Alignment.bottomRight, // Align the icon to the bottom right of the avatar
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2), // Space for the border
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black, // Border color
                                        width: 1.0, // Border width
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      backgroundImage: NetworkImage(_selectedAvatar!), // Assume _selectedAvatar is a valid URL
                                      radius: 22.0, // Adjust the size to fit your layout
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300], // Background color for the icon container
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt, // Pencil icon can be replaced with Icons.camera_alt for a camera icon
                                      size: 17.0, // Adjust the size of the icon
                                      color: Colors.black, // Icon color
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 10.0),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  // Same as Container border radius
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 5.0, sigmaY: 5.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(
                                            0.1), // Adjust the opacity as needed
                                      ),
                                      child: TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Name',
                                          labelStyle:
                                          TextStyle(color: Colors.black,
                                              fontFamily: 'Poppins'),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 5.0, horizontal: 10.0),
                                        ),
                                        style: TextStyle(color: Colors.black,),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 5),
                        buildAvatarSelector(),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(color: Colors.black),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  // Same as Container border radius
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 5.0, sigmaY: 5.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(
                                            0.1), // Adjust the opacity as needed
                                      ),
                                      child: TextFormField(
                                        controller: _referralCodeController,
                                        decoration: const InputDecoration(
                                          labelText: 'Referral Code (Optional)',
                                          labelStyle:
                                          TextStyle(color: Colors.black,
                                              fontFamily: 'Poppins'),
                                          contentPadding: EdgeInsets.symmetric(
                                              vertical: 5.0, horizontal: 10.0),
                                          border: InputBorder.none,
                                          // Removes the default border
                                          enabledBorder: InputBorder.none,
                                          // Removes the enabled border
                                          focusedBorder: InputBorder
                                              .none, // Removes the focused border
                                        ),
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                    8.0), // Border radius to match TextFormField
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 5.0, sigmaY: 5.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7),
                                      // Adjust the opacity as needed
                                      border: Border.all(color: Colors.black),
                                      // Border for the container
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isReferralCodeValid
                                            ? Icons.check
                                            : Icons.search,
                                        color: Colors.black,
                                      ),
                                      onPressed: verifyReferralCode,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 30),
                        if (verificationMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                            child: Text(
                              verificationMessage,
                              style: TextStyle(
                                color: isReferralCodeValid
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 10.0,
                              ),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          // Match the border radius of ElevatedButton
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.01),
                                // Adjust the opacity as needed
                                borderRadius: BorderRadius.circular(10.0),
                                border:
                                Border.all(color: Colors.black, width: 1.3),
                              ),
                              child: TextButton(
                                onPressed: createUserProfile,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(
                                      vertical: 20, horizontal: 20),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                child: const Text('Save Profile',
                                  style: TextStyle(
                                    fontFamily: 'Poppins', // Set the font family
                                    fontSize: 16, // You can also set the font size or other text styles here
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
