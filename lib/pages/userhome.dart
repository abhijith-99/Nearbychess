import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mychessapp/main.dart';
import 'package:mychessapp/pages/challengewaitingscreen.dart';
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

class UserHomePageState extends State<UserHomePage>
    with WidgetsBindingObserver {
  late Stream<List<DocumentSnapshot>> onlineUsersStream;
  String userLocation = 'Unknown';
  late StreamSubscription<DocumentSnapshot> userSubscription;
  late StreamSubscription<QuerySnapshot> challengeRequestsSubscription;
  String betAmount = '5\$'; // Default value
  Map<String, bool> challengeButtonCooldown = {};
  String searchText = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupUserListener();
    listenToChallengeRequests();
    onlineUsersStream = const Stream<List<DocumentSnapshot>>.empty();
  }

  // This function remains unchanged
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
              FirebaseFirestore.instance
                  .collection('challengeRequests')
                  .doc(latestRequests[challengerId]!.id)
                  .delete();
            }
            latestRequests[challengerId] = change.doc;
          }
        }

        latestRequests.forEach((challengerId, latestRequestDoc) async {
          var challengeData = latestRequestDoc.data() as Map<String, dynamic>;

          // Fetch the challenger's user data
          var userDoc = await FirebaseFirestore.instance.collection('users').doc(challengerId).get();
          String challengerName = userDoc.exists ? (userDoc.data()!['name'] ?? 'Unknown Challenger') : 'Unknown Challenger';
          String challengerImageUrl = userDoc.exists ? (userDoc.data()!['avatar'] ?? '') : ''; // Assuming the field name is 'avatarUrl'


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
                challengerImageUrl: challengerImageUrl, // Pass the image URL here
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
          String gameId = challengeData[
          'gameId']; // Assuming the game ID is stored in the challenge data
          print("challenger$gameId");
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
    challengeRequestsSubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    super.dispose();
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
      CollectionReference users =
      FirebaseFirestore.instance.collection('users');
      await users.doc(userId).update({'isOnline': isOnline});
    } catch (e) {
      print('Error updating online status: $e');
    }
  }


  Stream<List<DocumentSnapshot>> fetchOnlineUsers(String? location) {
    Query query = FirebaseFirestore.instance.collection('users');

    if (location != null && location.isNotEmpty) {
      query = query.where('location', isEqualTo: location);

    }

    if (searchText.isNotEmpty) {
      String searchEnd = searchText.substring(0, searchText.length - 1) +
          String.fromCharCode(searchText.codeUnitAt(searchText.length - 1) + 1);
      query = query.where('name', isGreaterThanOrEqualTo: searchText)
          .where('name', isLessThan: searchEnd);
    }

    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchText = query;
        onlineUsersStream = fetchOnlineUsers(userLocation);
      });
    });
  }

  void _showChallengeModal(BuildContext context, Map<String, dynamic> opponentData) {
    String localBetAmount = betAmount; // Local variable for bet amount
    bool isChallengeable = !(opponentData['inGame'] ?? false);
    String? currentGameId = opponentData['currentGameId'];
    String opponentId = opponentData['uid'];
    bool isOnline = opponentData['isOnline'] ?? false;

    // Initialize the button state for this user if not already set
    challengeButtonCooldown[opponentId] ??= true;
    bool isButtonEnabled = challengeButtonCooldown[opponentId] ?? true;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {

  
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
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
                      Text(
                        opponentData['name'],
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold), // Added bold weight
                      ),
                      Spacer(), // Spacer to push the button to the end of the row

                      ElevatedButton(
                        onPressed: () {
                          String? userId = opponentData['uid'];
                          if (userId != null) {
                            navigateToUserDetails(context, userId);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Error: User ID is null")),
                            );
                          }
                        },
                        child: const Text('Visit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      Text(
                        "Bet Amount:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold), // Added bold weight
                      ),

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
                              localBetAmount = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  ElevatedButton(

                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 20),
                    ),
                    onPressed: isChallengeable && isButtonEnabled
                        ? () async {
                            setModalState(() =>
                                challengeButtonCooldown[opponentId] = false);
                            await _sendChallenge(
                                opponentData['uid'], localBetAmount);
                            Navigator.pop(context);

                            // Start a timer to re-enable the button after 30 seconds
                            Timer(Duration(seconds: 30), () {
                              setState(() =>
                                  challengeButtonCooldown[opponentId] = true);
                            });
                          }
                        : (currentGameId != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ChessBoard(gameId: currentGameId),
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








  Future<void> _sendChallenge(String opponentId, String betAmount) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      try {
        String opponentName = await getUserName(opponentId);
        String currentUserName = await getUserName(currentUserId);

        print('Creating challenge request...');

        DocumentReference challengeDocRef = await FirebaseFirestore.instance
            .collection('challengeRequests')
            .add({
          'challengerId': currentUserId,
          'opponentId': opponentId,
          'betAmount': betAmount,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        print('Challenge request created with ID: ${challengeDocRef.id}');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => ChallengeWaitingScreen(
                currentUserName: currentUserName,
                opponentName: opponentName,
                challengeRequestId: challengeDocRef.id,
                currentUserId: currentUserId,
                opponentId: opponentId,
              ),
            ),
          );
        });




        print('Navigating to ChallengeWaitingScreen...');


        listenToMyChallenge(challengeDocRef.id);
      }
      catch (e) {
        print('Error sending challenge: $e');
      }
    } else {
      print('User is not logged in.');
    }
  }

  // Function to retrieve the user's name from Firestore
  Future<String> getUserName(String userId) async {
    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return userDoc['name'] ??
          'Unknown User'; // Replace 'Unknown User' with a default name of your choice
    } else {
      return 'Unknown User';
    }
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 225, 237),
      appBar: AppBar(
        toolbarHeight: 0, // AppBar is hidden
        elevation: 0,
      ),
      body: Column(
        children: <Widget>[

          if (currentUser != null) UserProfileHeader(userId: currentUser.uid),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600), // Set a maximum width for the search bar
              child: TextField(
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  labelText: 'Search Players in $userLocation',
                  hintText: 'Enter player name...',
                  prefixIcon: const Icon(Icons.search), // Add search icon
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), // Rounded corners for the border
                    borderSide: BorderSide(color: Colors.blueGrey.shade800), // Custom border color

                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), // Padding inside the text field
                  hintStyle: TextStyle(color: Colors.grey.shade500), // Lighter hint text color
                ),
              ),
            ),
          ),



          Text(
            'Players in $userLocation',
            style: const TextStyle(

              fontFamily: 'Poppins',
              color: Color.fromARGB(255, 12, 4, 4),
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          // ... rest of the code for GridView.builder ...
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: onlineUsersStream,
              builder: (context, snapshot) {

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No players Here'));
                }

                var currentUser = FirebaseAuth.instance.currentUser;
                var users = snapshot.data!
                    .where((doc) => doc.id != currentUser!.uid)
                    .map((doc) => doc.data() as Map<String, dynamic>)
                    .toList();

                // Sorting users based on 'isOnline' status
                users.sort((a, b) {
                  bool isOnlineA = a['isOnline'] ?? false;
                  bool isOnlineB = b['isOnline'] ?? false;
                  if (isOnlineA == isOnlineB) return 0;
                  if (isOnlineA && !isOnlineB) return -1;
                  return 1;
                });

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var userData = users[index];
                    String avatarUrl = userData['avatar'];
                    bool isOnline = userData['isOnline'] ??
                        false; // Assuming 'isOnline' is a field in your document
                    return GestureDetector(
                      onTap: () => _showChallengeModal(context, userData),
                      child: Column(
                        children: <Widget>[
                          CircleAvatar(
                            backgroundImage: AssetImage(avatarUrl),
                            radius: 36,
                            backgroundColor: Colors
                                .transparent, // Ensures the background is transparent
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: AssetImage(avatarUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: isOnline
                                      ? null
                                      : const ColorFilter.mode(
                                      Colors.grey,
                                      BlendMode
                                          .saturation), // Dim the avatar if offline
                                ),
                                border: Border.all(

                                  color: isOnline ? Colors.green : Colors.grey.shade500, // Red border for offline users
                                  width: 3,

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

class UserProfileHeader extends StatelessWidget {
  final String userId;

  const UserProfileHeader({Key? key, required this.userId}) : super(key: key);

  Future<Map<String, dynamic>?> fetchCurrentUserProfile(String userId) async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchCurrentUserProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          String avatarUrl = snapshot.data!['avatar'] ?? 'path/to/default/avatar.png'; // Provide a default path if null
          String userName = snapshot.data!['name'] ?? 'Unknown User';

          return Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const UserProfileDetailsPage(),
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: AssetImage(avatarUrl), // Using NetworkImage for the avatar
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.only(top: 20.0, bottom: 10.0),
          child: CircularProgressIndicator(), // Show loading indicator while fetching data
        );
      },
    );
  }
}