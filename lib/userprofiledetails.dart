import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mychessapp/pages/UserDetails.dart';
import 'package:share_plus/share_plus.dart';

// Include the StatisticText and MatchRecord classes from your UserDetailsPage

class UserProfileDetailsPage extends StatefulWidget {
  const UserProfileDetailsPage({Key? key}) : super(key: key);

  @override
  _UserProfileDetailsPageState createState() => _UserProfileDetailsPageState();
}

class _UserProfileDetailsPageState extends State<UserProfileDetailsPage> {
  // ... existing variables and functions from your UserProfileDetailsPage
  Future<Map<String, dynamic>> fetchMatchStatistics(String userId) async {
    var matchesQuerySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('matches')
        .get();

    int totalMatches = matchesQuerySnapshot.docs.length;
    int wins = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'win').length;
    int losses = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'loss').length;
    int draws = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'draw').length;
    double totalBetAmount = matchesQuerySnapshot.docs.fold(0, (sum, doc) => sum + (doc.data()['betAmount'] ?? 0));

    double winPercentage = totalMatches > 0 ? (wins / totalMatches) * 100 : 0;
    double lossPercentage = totalMatches > 0 ? (losses / totalMatches) * 100 : 0;
    double drawPercentage = totalMatches > 0 ? (draws / totalMatches) * 100 : 0;

    return {
      'totalMatches': totalMatches,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'winPercentage': winPercentage,
      'lossPercentage': lossPercentage,
      'drawPercentage': drawPercentage,
      'totalBetAmount': totalBetAmount,
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [

          Padding(
            padding: const EdgeInsets.only(right: 16.0), // Adjust the value as needed
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red, // Background color
                borderRadius: BorderRadius.circular(6.0), // Rounded corners
              ),
              child: TextButton(
                onPressed: signOut,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
                ),
                child: const Text('SIGN OUT', style: TextStyle(fontSize: 16),),
              ),
            ),
          ),

        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: fetchUserProfile(),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.done) {
            if (profileSnapshot.hasData) {
              var userData = profileSnapshot.data!;
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // User Avatar and Name
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: NetworkImage(userData['avatar'] ?? 'default_avatar_url'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt),
                          onPressed: showAvatarSelection,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      mainAxisSize: MainAxisSize.min, // Use the minimum amount of space
                      crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
                      children: [
                        Flexible(
                          child: Text(
                            userData['name'] ?? 'Username',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis, // Add ellipsis for longer names
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => editUsername(userData['name'] ?? ''),
                          // Optionally adjust padding if necessary
                          padding: const EdgeInsets.symmetric(horizontal: 15), // Adjust the padding as needed
                        ),
                      ],
                    ),


                    const SizedBox(height: 20),

                    // User Statistics
                    FutureBuilder<Map<String, dynamic>>(
                      future: fetchMatchStatistics(FirebaseAuth.instance.currentUser!.uid),
                      builder: (context, statsSnapshot) {
                        if (!statsSnapshot.hasData) return Container();
                        var stats = statsSnapshot.data!;
                        return Column(
                          children: [
                            // Games Played
                            Text(
                              'Games Played: ${stats['totalMatches']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Win / Draw / Lost Statistics
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                StatisticText(
                                  label: '${stats['wins']} Won',
                                  value: stats['winPercentage'].toStringAsFixed(1) + '%',
                                  color: Colors.green,

                                ),
                                StatisticText(
                                  label: '${stats['draws']} Drawn',
                                  value: stats['drawPercentage'].toStringAsFixed(1) + '%',
                                  color: Colors.grey,
                                ),
                                StatisticText(
                                  label: '${stats['losses']} Loss',
                                  value: stats['lossPercentage'].toStringAsFixed(1) + '%',
                                  color: Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Container to create the horizontal bar
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(bottom: 16.0), // Adds horizontal padding to the container
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.0), // Applies rounded corners to the outer container
                                child: Container(
                                  height: 10.0, // Height of the bar
                                  decoration: const BoxDecoration(
                                    color: Colors.black26, // Background color for the entire bar
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        flex: stats['wins'], // Proportion of wins
                                        child: Container(color: Colors.green),
                                      ),
                                      Expanded(
                                        flex: stats['draws'], // Proportion of draws
                                        child: Container(color: Colors.grey),
                                      ),
                                      Expanded(
                                        flex: stats['losses'], // Proportion of losses
                                        child: Container(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    FutureBuilder<List<MatchRecord>>(
                      future: fetchUserMatches(FirebaseAuth.instance.currentUser!.uid),
                      builder: (context, matchSnapshot) {
                        if (!matchSnapshot.hasData) return Container();
                        if (matchSnapshot.data!.isEmpty) return const Text('No match history available');

                        return ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: matchSnapshot.data!.length,
                          itemBuilder: (context, index) {
                            MatchRecord match = matchSnapshot.data![index];
                            return Card(
                              child: FutureBuilder<Map<String, dynamic>>(
                                future: getOpponentDetails(match.opponentUid),
                                builder: (context, opponentSnapshot) {
                                  if (!opponentSnapshot.hasData) {
                                    return const ListTile(
                                      leading: CircleAvatar(child: Icon(Icons.person)),
                                      title: Text('Loading...'),
                                    );
                                  }
                                  var opponentData = opponentSnapshot.data!;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundImage: NetworkImage(opponentData['avatar'] ?? 'default_avatar_url'),
                                    ),
                                    title: Text(opponentData['name'] ?? 'Unknown'),
                                    subtitle: Text("Played on ${DateFormat('dd/MM/yyyy').format(match.time)}"),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: match.result == 'win' ? Colors.green : match.result == 'loss' ? Colors.red : Colors.grey,
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            match.result.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8), // Space between the result and amount
                                        Text(
                                          "${match.bet.toStringAsFixed(2)}NBC",
                                          style: TextStyle(
                                            color: match.result == 'win' ? Colors.green :
                                            match.result == 'loss' ? Colors.red :
                                            Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    )
                  ],
                ),
              );
            } else {
              return const Text('No user data available.');
            }
          } else {
            return Container();
          }
        },
      ),
      // floatingActionButton: FloatingActionButton.extended(
      //   onPressed: shareReferralCode,
      //   label: const Text('Share And Win 100'),
      //   icon: const Icon(Icons.share),
      //   backgroundColor: Colors.blue,
      // ),
    );
  }



  Future<void> signOut() async {
    // Show confirmation dialog
    bool confirm = await showSignOutConfirmationDialog();
    if (confirm) {
      try {
        // Assuming the user's ID is stored in FirebaseAuth
        String userId = FirebaseAuth.instance.currentUser!.uid;

        // Update the user's online status to 'offline' in Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'isOnline': false, // Adjust the field name and value as necessary
          'lastOnline': FieldValue.serverTimestamp(), // Optional: record last online timestamp
        });

        // Sign out the user from FirebaseAuth
        await FirebaseAuth.instance.signOut();

        // Navigate to the login/register screen and remove all routes from the stack
        Navigator.of(context).pushNamedAndRemoveUntil('/login_register', (Route<dynamic> route) => false);
      } catch (error) {
        print(error.toString());
      }
    }
  }


  Future<bool> showSignOutConfirmationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade300, // Chessboard-themed background color.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded shape.
          side: BorderSide(color: Colors.black, width: 2), // Black border.
        ),
        title: const Text('Confirm Sign Out', style: TextStyle(color: Colors.white)), // Dialog title.
        content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white)), // Dialog content.
        actions: <Widget>[
          // Cancel button.
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black, backgroundColor: Colors.white, // Button color.
            ),
            onPressed: () => Navigator.of(context).pop(false), // Close dialog without signing out.
            child: const Text('Cancel'),
          ),
          // Sign Out button.
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.black, // Button color.
            ),
            onPressed: () => Navigator.of(context).pop(true), // Proceed with sign out.
            child: const Text('Sign Out'),
          ),
        ],
      ),
    ) ?? false; // Returning false if the dialog is dismissed
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

  Future<void> updateUsername(String newUsername) async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(userId).update({'name': newUsername});
    setState(() {}); // This will refresh the UI with the updated username
  }


  Future<void> editUsername(String currentUsername) async {
    TextEditingController usernameController = TextEditingController(text: currentUsername);

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white, // Matching the chessboard-themed background color.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), // Rounded shape.
            side: const BorderSide(color: Colors.black, width: 1), // Black border for consistency.
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.5, // Set dialog width to 70% of screen width
            child: Row( // Row for horizontal alignment
              children: [
                Expanded( // Expanded to take available space
                  child: TextField(
                    controller: usernameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter new username',
                      errorText: validateUsername(usernameController.text),
                      border: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white), // Adjusted for theme consistency.
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      hintStyle: TextStyle(color: Colors.black.withOpacity(0.7)), // Hint text style for visibility.
                    ),
                    style: const TextStyle(color: Colors.black), // Text input color for visibility.
                    cursorColor: Colors.black, // Cursor color for visibility.
                    onChanged: (value) {
                      // Trigger UI update for error message without using setState as it is a stateful builder
                      (context as Element).markNeedsBuild();
                    },
                  ),
                ),
                const SizedBox(width: 8), // SizedBox for spacing between TextField and TextButton
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white, backgroundColor: Colors.green, // Button color.
                  ),
                  onPressed: () {
                    if (validateUsername(usernameController.text) == null) {
                      updateUsername(usernameController.text);
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            ),
          ),
        );
      },
    );

  }


  String? validateUsername(String username) {
    if (username.length > 10) {
      return 'Username cannot be more than 10 characters';
    }
    if (username.length <= 1) {
      return 'Username must be more than one character';
    }
    // This regex allows for letters, numbers, and whitespaces but not as the first character.
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9 ]*[a-zA-Z0-9]$').hasMatch(username)) {
      return 'Username must start with a letter and end with a letter or number';
    }
    // This regex allows for special characters as long as they are not at the beginning.
    if (username.contains(RegExp(r'[!@#<>?":_`~;[\]\\|=+)(*&^%$£€.,-]'))) {
      if(!RegExp(r'^[a-zA-Z][a-zA-Z0-9 !@#<>?":_`~;[\]\\|=+)(*&^%$£€.,-]*[a-zA-Z0-9]$').hasMatch(username)) {
        return 'Special characters are allowed only along with letters and numbers';
      }
    }
    return null;
  }



  void showAvatarSelection() {
    String? selectedAvatar; // Temporarily store the selected avatar URL

    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Calculate the number of items per row based on the dialog width
        var dialogWidth = MediaQuery.of(context).size.width * 0.5; // Dialog width is 80% of screen width
        var itemPadding = 10.0; // Padding around each item
        var spacing = 8.0; // Spacing between items
        var itemCount = 6; // Number of items per row
        var totalPadding = itemPadding * 2 * itemCount; // Total padding for all items
        var totalSpacing = spacing * (itemCount - 1); // Total spacing between items
        var itemWidth = (dialogWidth - totalPadding - totalSpacing) / itemCount; // Calculate adjusted item width

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // Rounded corners for the dialog
          ),
          child: Container(
            width: dialogWidth, // Use the calculated dialog width
            padding: const EdgeInsets.all(8.0), // Adjust padding for the container
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min, // To make the dialog height wrap its content
                  children: [
                    GridView.builder(
                      shrinkWrap: true, // Ensure the GridView only takes needed space
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: itemCount, // Dynamic count based on screen size
                        crossAxisSpacing: spacing, // Spacing between items on the cross axis
                        mainAxisSpacing: spacing, // Spacing between items on the main axis
                        childAspectRatio: (itemWidth / itemWidth), // Maintain square aspect ratio
                      ),
                      itemCount: avatarImages.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => setState(() {
                            selectedAvatar = avatarImages[index]; // Update the selected avatar
                          }),
                          child: Padding(
                            padding: EdgeInsets.all(itemPadding), // Padding around each image
                            child: Image.network(
                              avatarImages[index],
                              fit: BoxFit.cover, // Cover the area without distorting the image
                            ),
                          ),
                        );
                      },
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white, backgroundColor: Colors.blue, // Button background color
                      ),
                      onPressed: selectedAvatar != null ? () {
                        updateAvatar(selectedAvatar!);
                        Navigator.pop(context);
                      } : null, // Disable the button if no avatar is selected
                      child: const Text('Set Avatar'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }






  final List<String> avatarImages = [
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar1.png?alt=media&token=7fc8ed85-7d37-43b7-bd46-a11f6d80ae7e",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar2.png?alt=media&token=7d77108b-91a3-451a-b633-da1e03df1ea8",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar3.png?alt=media&token=0d97a0c5-0a10-41f1-a972-3c2941a87c52",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar4.png?alt=media&token=5b398b84-8aa8-465b-8db1-111f2195e6fb",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar5.png?alt=media&token=b82e2b51-cbec-421b-a436-2ee2be88d0c2",
    "https://firebasestorage.googleapis.com/v0/b/chessapp-68652.appspot.com/o/avatar6.png?alt=media&token=2612629f-0dca-4e65-951d-b7f878a6b463"
  ];


  // Future<void> shareReferralCode() async {
  //   try {
  //     String userId = FirebaseAuth.instance.currentUser!.uid;
  //     var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  //     if (userDoc.exists) {
  //       var userData = userDoc.data() as Map<String, dynamic>;
  //       String referralCode = userData['referralCode'];
  //
  //       String shareMessage = "Join me on the ultimate chess battleground! Use my code $referralCode to start your journey with extra 100 NBC rewards. Download now: https://example.com/download";
  //       Share.share(shareMessage);
  //       print("Referral Code: $referralCode");
  //       print("Share Message: $shareMessage");
  //     }
  //   } catch (error) {
  //     print('Failed to share: $error');
  //   }
  // }
}


Future<List<MatchRecord>> fetchUserMatches(String userId) async {
  var matchesQuerySnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('matches')
      .get();
  print("Fetched ${matchesQuerySnapshot.docs.length} matches");
  return matchesQuerySnapshot.docs
      .map((doc) => MatchRecord.fromFirestore(doc))
      .toList()
    ..sort((a, b) => b.time.compareTo(a.time));
}

Future<Map<String, dynamic>> getOpponentDetails(String opponentUid) async {
  var opponentDoc = await FirebaseFirestore.instance.collection('users').doc(opponentUid).get();
  if (opponentDoc.exists) {
    return opponentDoc.data() as Map<String, dynamic>;
  }
  return {'name': 'Unknown', 'avatar': 'assets/avatars/default.png', 'location': 'Unknown Location'};
}




