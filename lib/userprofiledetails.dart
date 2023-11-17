import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileDetailsPage extends StatefulWidget {
  const UserProfileDetailsPage({Key? key}) : super(key: key);

  @override
  _UserProfileDetailsPageState createState() => _UserProfileDetailsPageState();
}

class _UserProfileDetailsPageState extends State<UserProfileDetailsPage> {
  final List<String> locations = ['Aluva', 'Kakkanad', 'Eranakulam'];
  String? selectedLocation;
  bool isEditingLocation = false;

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
      // Replace current route with the login route
      Navigator.of(context).pushNamedAndRemoveUntil('/login_register', (Route<dynamic> route) => false);
    } catch (error) {
      print(error.toString());
      // Optionally handle the error, e.g., show an error message.
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

  Future<void> updateLocation(String newLocation) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'location': newLocation});
    setState(() {
      isEditingLocation = false;
    });
  }

  void showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(avatarImages[index]),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            var userData = snapshot.data!;
            String avatarUrl = userData['avatar'];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4.0,
                    child: ListTile(
                      title: Text('Name: ${userData['name']}'),
                      leading: CircleAvatar(
                        backgroundImage: AssetImage(avatarUrl),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    child: const Text('Edit Avatar'),
                    onPressed: showAvatarSelection,
                  ),
                  isEditingLocation
                      ? Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedLocation,
                        items: locations.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            selectedLocation = newValue;
                          });
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(primary: Theme.of(context).primaryColor),
                        onPressed: () {
                          if (selectedLocation != null) {
                            updateLocation(selectedLocation!);
                          }
                        },
                        child: const Text('Update Location'),
                      ),
                    ],
                  )
                      : ListTile(
                    title: const Text('Location'),
                    subtitle: Text(userData['location'] ?? 'Not set'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        setState(() {
                          isEditingLocation = true;
                          selectedLocation = userData['location'];
                        });
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: signOut,
                    child: const Text('Sign Out'),
                    style: ElevatedButton.styleFrom(
                      primary: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

