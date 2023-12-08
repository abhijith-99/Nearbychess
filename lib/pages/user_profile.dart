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
  String? _selectedLocation;
  String? _selectedAvatar;
  final List<String> _locations = ['Aluva', 'Kakkanad', 'Eranakulam'];
  bool isAvatarListVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> createUserProfile() async {
    if (_nameController.text.isNotEmpty &&
        _selectedLocation != null &&
        _selectedAvatar != null) {
      try {
        CollectionReference users =
        FirebaseFirestore.instance.collection('users');
        String userId = FirebaseAuth.instance.currentUser!.uid;
        await users.doc(userId).set({
          'uid': userId,
          'name': _nameController.text,
          'location': _selectedLocation,
          'avatar': _selectedAvatar,
          'isOnline': true,
          'inGame': false,
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
