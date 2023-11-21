import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../userprofiledetails.dart';
import '../utils.dart';
import 'ChessBoard.dart';
import 'UserDetails.dart';
import 'challenge_request_screen.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({Key? key}) : super(key: key);

  @override
  UserHomePageState createState() => UserHomePageState();
}

class UserHomePageState extends State<UserHomePage> with WidgetsBindingObserver {
  late Stream<List<DocumentSnapshot>> onlineUsersStream;
  String userLocation = 'Unknown';
  late StreamSubscription<DocumentSnapshot> userSubscription;
  late StreamSubscription<QuerySnapshot> challengeRequestsSubscription;
  // Declare betAmount as a class field
  String betAmount = '5\$'; // Default value
  Map<String, bool> challengeButtonCooldown = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupUserListener();
    listenToChallengeRequests();
    onlineUsersStream = const Stream<List<DocumentSnapshot>>.empty();
  }

  //new change

  void listenToChallengeRequests() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      challengeRequestsSubscription = FirebaseFirestore.instance
          .collection('challengeRequests')
          .where('opponentId', isEqualTo: currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
        Map<String, DocumentSnapshot> latestRequests = {};
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var challengeData = change.doc.data() as Map<String, dynamic>;
            String challengerId = challengeData['challengerId'];
            if (latestRequests.containsKey(challengerId)) {
              FirebaseFirestore.instance.collection('challengeRequests').doc(latestRequests[challengerId]!.id).delete();
            }
            latestRequests[challengerId] = change.doc;
          }
        }

        latestRequests.forEach((challengerId, latestRequestDoc) async {
          var challengeData = latestRequestDoc.data() as Map<String, dynamic>;

          // Fetch the challenger's user data
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(challengerId).get();
          String challengerName = userDoc.exists ? (userDoc.data()!['name'] ?? 'Unknown Challenger') : 'Unknown Challenger';

          // Show the challenge request dialog for the latest request
          showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return ChallengeRequestScreen(
                challengerName: challengerName,
                challengerUID: challengerId,
                opponentUID: currentUserId,
                betAmount: challengeData['betAmount'],
                challengeId: latestRequestDoc.id,
              );
            },
          ).then((accepted) {
            // Handle post-acceptance logic if needed
          });
        });
      });
    }
  }



  void listenToMyChallenge(String challengeId) {
    FirebaseFirestore.instance
        .collection('challengeRequests')
        .doc(challengeId)
        .snapshots()
        .listen((challengeSnapshot) {
      if (challengeSnapshot.exists) {
        var challengeData = challengeSnapshot.data() as Map<String, dynamic>;
        if (challengeData['status'] == 'accepted') {
          // Challenge accepted, navigate to the ChessBoard
          String gameId = challengeData['gameId']; // Assuming the game ID is stored in the challenge data
          print("challenger"+gameId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChessBoard(gameId: gameId),
            ),
          ).then((_) {
            // User has left the Chessboard, update the inGame status
            updateInGameState(false);
          });
        }
      }
    });
  }

  void setupUserListener() {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          var userData = snapshot.data() as Map<String, dynamic>;
          setState(() {
            userLocation = userData['location'] ?? 'Unknown';
            onlineUsersStream = fetchOnlineUsers(userLocation);
          });
        }
      });
    }
  }

  void navigateToUserDetails(BuildContext context, String userId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => UserDetailsPage(userId: userId),
    ));
  }

  @override
  void dispose() {
    userSubscription.cancel();
    super.dispose();
    challengeRequestsSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      setUserOnlineStatus(false);
    } else if (state == AppLifecycleState.resumed) {
      setUserOnlineStatus(true);
    }
  }

  Future<void> setUserOnlineStatus(bool isOnline) async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      CollectionReference users = FirebaseFirestore.instance.collection('users');
      await users.doc(userId).update({'isOnline': isOnline});
    } catch (e) {
      print('Error updating online status: $e');
    }
  }


  Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    }
    return null;
  }

  Stream<List<DocumentSnapshot>> fetchOnlineUsers(String? location) {
    if (location == null || location.isEmpty) {
      // Return an empty stream or handle the null case as needed
      return const Stream<List<DocumentSnapshot>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .where('location', isEqualTo: location)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  void _showChallengeModal(BuildContext context, Map<String, dynamic> opponentData) {
    String localBetAmount = betAmount; // Local variable for bet amount
    bool isChallengeable = !(opponentData['inGame'] ?? false);
    String? currentGameId = opponentData['currentGameId'];
    String opponentId = opponentData['uid'];

    // Initialize the button state for this user if not already set
    challengeButtonCooldown[opponentId] ??= true;
    bool isButtonEnabled = challengeButtonCooldown[opponentId] ?? true;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // Using StatefulBuilder here
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: AssetImage(opponentData['avatar']),
                        backgroundColor: Colors.transparent,
                      ),
                      SizedBox(width: 5), // Space between avatar and name
                      Text(opponentData['name'],
                          style: TextStyle(fontSize: 20)),
                      Spacer(), // Spacer to push the button to the end of the row
                      ElevatedButton(
                        onPressed: () {
                          String? userId = opponentData['uid'];
                          if (userId != null) {
                            navigateToUserDetails(context, userId);
                          } else {
                            // Handle the null case, maybe show an error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error: User ID is null")),
                            );
                          }
                        },
                        child: Text('Visit'),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Bet Amount:"),
                      DropdownButton<String>(
                        value: localBetAmount,
                        items: ['5\$', '10\$', '15\$'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setModalState(() {
                              // Update localBetAmount using the modal's local setState
                              localBetAmount = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: isChallengeable && isButtonEnabled
                        ? () async {
                      setModalState(() => challengeButtonCooldown[opponentId] = false);
                      await _sendChallenge(opponentData['uid'], localBetAmount);
                      Navigator.pop(context);

                      // Start a timer to re-enable the button after 30 seconds
                      Timer(Duration(seconds: 30), () {
                        setState(() => challengeButtonCooldown[opponentId] = true);
                      });
                    }
                        : (currentGameId != null
                        ? () {
                      // Logic to watch the game
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChessBoard(gameId: currentGameId),
                        ),
                      );
                    }
                        : null), // Disable the button if no game ID is available
                    child: Text(isChallengeable ? 'Challenge' : 'Watch Game'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Function to send a challenge
  Future<void> _sendChallenge(String opponentId, String betAmount) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      // Try to send the challenge and handle any potential errors

      try {
        String opponentName = await getUserName(opponentId);
        DocumentReference challengeDocRef = await FirebaseFirestore.instance
            .collection('challengeRequests')
            .add({
          'challengerId': currentUserId,
          'opponentId': opponentId,
          'betAmount': betAmount,
          'status': 'pending',
          'timestamp': FieldValue
              .serverTimestamp(), // It's a good practice to store the time of the challenge
        });

        // After sending the challenge, display an alert on the challenger's screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Challenge sent to $opponentName with bet $betAmount')),
        );

        Future.delayed(const Duration(seconds: 30), () async {
          // Retrieve the challenge again to see if its status has changed
          DocumentSnapshot challengeSnapshot = await challengeDocRef.get();

          if (challengeSnapshot.exists &&
              challengeSnapshot['status'] == 'pending') {
            // If the challenge is still pending, delete it
            await challengeDocRef.delete();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Challenge to $opponentName has expired and been removed')),
            );
          }
        });
        // Call listenToMyChallenge here with the new challenge ID
        listenToMyChallenge(challengeDocRef.id);
        // Return the challenge ID
        // return challengeDocRef.id;
      } catch (e) {
        // If sending the challenge fails, log the error and return an empty string or handle the error as needed
        print('Error sending challenge: $e');
        // return ''; // Or handle the error appropriately
      }
    } else {
      // If the user is not logged in, handle this case as well
      print('User is not logged in.');
      // return ''; // Or handle the error appropriately
    }
  }

  // Function to retrieve the user's name from Firestore
  Future<String> getUserName(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return userDoc['name'] ?? 'Unknown User'; // Replace 'Unknown User' with a default name of your choice
    } else {
      return 'Unknown User';
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 225, 237),
      appBar: AppBar(
        toolbarHeight: 0, // AppBar is hidden
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[
          FutureBuilder<Map<String, dynamic>?>(
            future: fetchCurrentUserProfile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                String avatarUrl = snapshot.data!['avatar'];
                String userName = snapshot.data!['name'] ?? 'Unknown';
                return Padding(
                  padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) =>
                              const UserProfileDetailsPage()),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: AssetImage(avatarUrl),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0), // Padding after username
                        child: Text(
                          userName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color.fromARGB(255, 12, 6, 6),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const Padding(
                padding: EdgeInsets.only(top: 20.0, bottom: 10.0),
                child: Center(
                  child: CircleAvatar(
                    radius: 60,
                    child: Text('?', style: TextStyle(fontSize: 30)),
                  ),
                ),
              );
            },
          ),


          const Text(
            'Players Nearby',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color.fromARGB(255, 12, 4, 4),
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: onlineUsersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No players Here'));
                }

                var currentUser = FirebaseAuth.instance.currentUser;
                var filteredUsers = snapshot.data!
                    .where((doc) => doc.id != currentUser!.uid)
                    .toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    var userData = filteredUsers[index].data() as Map<String, dynamic>;
                    String avatarUrl = userData['avatar'];
                    bool isOnline = userData['isOnline'] ?? false; // Assuming 'isOnline' is a field in your document
                    return GestureDetector(
                      onTap: isOnline ? () => _showChallengeModal(context, userData) : null, // Disable onTap for offline players
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundImage: AssetImage(avatarUrl),
                            radius: 36,
                            backgroundColor: Colors.transparent, // Ensures the background is transparent
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: AssetImage(avatarUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: isOnline ? null : ColorFilter.mode(Colors.grey, BlendMode.saturation), // Dim the avatar if offline
                                ),
                                border: Border.all(
                                  color: isOnline ? Colors.green : Colors.red.shade900, // Red border for offline users
                                  width: 5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userData['name'] ?? 'Username',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color.fromARGB(255, 12, 6, 6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
