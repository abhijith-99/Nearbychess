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
          print("Location Data: Latitude: ${_locationData.latitude}, Longitude: ${_locationData.longitude}");
  
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
              print("4567890using web $detailedLocationName");
  
            } else {
              // Use mobile implementation
              List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
                _locationData.latitude!,
                _locationData.longitude!,
              );
              if (placemarks.isNotEmpty) {
                geocoding.Placemark place = placemarks.first;
                detailedLocationName = place.subLocality ?? place.locality ?? place.subAdministrativeArea ?? place.administrativeArea ?? 'Unknown';
  
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
              CollectionReference users = FirebaseFirestore.instance.collection('users');
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
  
              });
  
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
      // Initialize with a default avatar if none is selected
      _selectedAvatar = _selectedAvatar ?? 'assets/avatars/avatar-default.png';
  
      return Offstage(
        offstage: !isAvatarListVisible,
        child: buildAvatarRow(), // The method you already have
      );
    }
  
  
  
  
  
    Widget buildAvatarRow() {
      List<String> avatarImages = [
        'assets/avatars/avatar1.png',
        'assets/avatars/avatar2.png',
        'assets/avatars/avatar3.png',
        'assets/avatars/avatar4.png',
        'assets/avatars/avatar5.png',
        'assets/avatars/avatar6.png',
        //'assets/avatars/avatar-default.png'
  
      ];
  
      return Container(
        height: 50.0, // Set the height of the container that holds the list view
        child: ListView.builder(
          shrinkWrap: true,
          scrollDirection: Axis.horizontal,
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
                width: 50.0, // Approximate width to match the height
                padding: const EdgeInsets.all(2), // Reduced padding
                margin: const EdgeInsets.symmetric(horizontal: 4), // Spacing between items
                decoration: BoxDecoration(
                  border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(avatarImages[index]),
              ),
            );
          },
        ),
      );
    }
  
  
  
  
    @override
    Widget build(BuildContext context) {
      _selectedAvatar = _selectedAvatar ?? 'assets/avatars/avatar-default.png';
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
                        const SizedBox(height: 30),
  
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            GestureDetector(
                              onTap: () {
                                // Toggle the avatar selection view
                                setState(() {
                                  isAvatarListVisible = !isAvatarListVisible;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(2), // Space for the border
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black, // Border color
                                    width: 1.0, // Border width
                                  ),
                                ),
                              child: CircleAvatar(
                                backgroundImage: AssetImage(_selectedAvatar!),
                                radius: 22.0, // Adjust the size to fit your layout
                                backgroundColor: Colors.white,
                              ),
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
                                  borderRadius: BorderRadius.circular(8.0), // Same as Container border radius
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1), // Adjust the opacity as needed
                                      ),
                                      child: TextFormField(
                                        controller: _nameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Name',
                                          labelStyle: TextStyle(color: Colors.black),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                        ),
                                        style: TextStyle(color: Colors.black),
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
                                  borderRadius: BorderRadius.circular(8.0), // Same as Container border radius
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1), // Adjust the opacity as needed
                                      ),
                                      child: TextFormField(
                                        controller: _referralCodeController,
                                        decoration: InputDecoration(
                                          labelText: 'Referral Code (Optional)',
                                          labelStyle: TextStyle(color: Colors.black),
                                          contentPadding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                          border: InputBorder.none, // Removes the default border
                                          enabledBorder: InputBorder.none, // Removes the enabled border
                                          focusedBorder: InputBorder.none, // Removes the focused border
                                        ),
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
  
                            const SizedBox(width: 10,),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8.0), // Border radius to match TextFormField
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.7), // Adjust the opacity as needed
                                      border: Border.all(color: Colors.black), // Border for the container
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        isReferralCodeValid ? Icons.check : Icons.search,
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
                        const SizedBox(height: 10),
                        if (verificationMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0,left: 8.0),
                            child: Text(
                              verificationMessage,
                              style: TextStyle(
                                color: isReferralCodeValid ? Colors.green : Colors.red,
                                fontSize: 10.0,
                              ),
                            ),
                          ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.0), // Match the border radius of ElevatedButton
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1), // Adjust the opacity as needed
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(color: Colors.black, width: 1.3),
                              ),
                              child: TextButton(
                                onPressed: createUserProfile,
                                style: TextButton.styleFrom(
                                  primary: Colors.black, // Text color
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                ),
                                child: const Text('Save Profile'),
                              ),
                            ),
                          ),
                        )
  
  
  
  
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
