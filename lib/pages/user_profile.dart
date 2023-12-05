import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
// import 'package:geocoding/geocoding.dart';
import 'package:mychessapp/pages/userhome.dart';

import 'package:location/location.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedLocation;
  String? _selectedAvatar;
  final List<String> _locations = ['Aluva', 'Kakkanad', 'Eranakulam'];
  bool isAvatarListVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }


  // Future<void> createUserProfile() async {
  //   Location location = new Location();
  //   bool _serviceEnabled;
  //   PermissionStatus _permissionGranted;
  //   LocationData _locationData;

  //   _serviceEnabled = await location.serviceEnabled();
  //   if (!_serviceEnabled) {
  //     _serviceEnabled = await location.requestService();
  //     if (!_serviceEnabled) {
  //       return;
  //     }
  //   }

  //   _permissionGranted = await location.hasPermission();
  //   if (_permissionGranted == PermissionStatus.denied) {
  //     _permissionGranted = await location.requestPermission();
  //     if (_permissionGranted != PermissionStatus.granted) {
  //       return;
  //     }
  //   }

  //   _locationData = await location.getLocation();

  //   if (_nameController.text.isNotEmpty &&
  //       _selectedLocation != null &&
  //       _selectedAvatar != null) {
  //     try {
  //       CollectionReference users =
  //           FirebaseFirestore.instance.collection('users');
  //       String userId = FirebaseAuth.instance.currentUser!.uid;
  //       await users.doc(userId).set({
  //         'uid': userId,
  //         'name': _nameController.text,
  //         'location': _selectedLocation,
  //         'avatar': _selectedAvatar,
  //         'isOnline': true,
  //         'inGame': false,
  //         'latitude': _locationData.latitude, // Add latitude
  //         'longitude': _locationData.longitude, // Add longitude
  //       });
  //       Navigator.of(context).pushReplacement(
  //         MaterialPageRoute(builder: (context) => const UserHomePage()),
  //       );
  //       print("jdi");
  //     } catch (e) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Error creating profile: $e')),
  //       );
  //     }
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Please fill in all fields')),
  //     );
  //   }
  // }









  Future<void> createUserProfile() async {
  
  Location location = new Location();
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;
  LocationData _locationData;

  // Check and request location service and permission
  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      return;
    }
  }

  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      return;
    }
  }

  _locationData = await location.getLocation();

  // Check if name and avatar are selected
  if (_nameController.text.isNotEmpty && _selectedAvatar != null) {
    try {
      CollectionReference users = FirebaseFirestore.instance.collection('users');
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await users.doc(userId).set({
        'uid': userId,
        'name': _nameController.text,
        'avatar': _selectedAvatar,
        'isOnline': true,
        'inGame': false,
        'latitude': _locationData.latitude, // Store latitude
        'longitude': _locationData.longitude, // Store longitude
      });
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


   List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
    _locationData.latitude!,
    _locationData.longitude!,
  );
  geocoding.Placemark place = placemarks[0];
  String city = place.locality ?? 'Unknown';
  
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
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 20),
                  const Text(
                    'Create User Profile',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

             

                  const SizedBox(height: 20),
                  buildAvatarSelector(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: createUserProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F6669),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('Save Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
