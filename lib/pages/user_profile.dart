  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:geocoding/geocoding.dart' as geocoding;
  import 'package:geocoding/geocoding.dart';
  import 'package:mychessapp/pages/userhome.dart';

  import 'package:location/location.dart';
  import 'package:location/location.dart' as loc;



  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'geocoding_stub.dart'
  if (dart.library.html) 'geocoding_web.dart';




  class UserProfilePage extends StatefulWidget {
    const UserProfilePage({Key? key}) : super(key: key);

    @override
    _UserProfilePageState createState() => _UserProfilePageState();
  }

  class _UserProfilePageState extends State<UserProfilePage> {
    final TextEditingController _nameController = TextEditingController();
    String? _selectedLocation;
    String? _selectedAvatar;
    bool isAvatarListVisible = false;

    @override
    void dispose() {
      _nameController.dispose();
      super.dispose();
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
            // city = await getPlaceFromCoordinates(
            //   _locationData.latitude!,
            //   _locationData.longitude!,
            // );
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

          // print("Geocoded place name: $detailedLocationName");



          city = await getPlaceFromCoordinates(
            _locationData.latitude!,
            _locationData.longitude!,
          );
          print("City name: $city");



          if (_nameController.text.isNotEmpty && _selectedAvatar != null) {
            CollectionReference users = FirebaseFirestore.instance.collection('users');
            String userId = FirebaseAuth.instance.currentUser!.uid;
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
            });

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const UserHomePage()),
            );



          } else {
            // Un-comment this line to show the snackbar when fields are not filled
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(content: Text('Please fill in all fields')),
            // );
          }
        } else {
          throw Exception('Invalid location coordinates');
        }
      } catch (e) {
        print('Error in createUserProfile: $e');
        // Un-comment this line to show the snackbar when an error occurs
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error in creating profile: $e')),
        // );
      }
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
