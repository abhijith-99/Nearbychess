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
  String localTimerValue = '10';
  int currentUserChessCoins = 0;



  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupUserListener();
    listenToChallengeRequests();
    fetchCurrentUserChessCoins();
    onlineUsersStream = const Stream<List<DocumentSnapshot>>.empty();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      await checkAndUpdateDailyLoginBonus(userId); // Ensure this completes
      // Introduce a slight delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          showDailyBonusDialogIfNeeded(context, userId);
        }
      });

    });
    listenForReferralBonus();
  }

  void listenForReferralBonus() {
    String myUserId = FirebaseAuth.instance.currentUser!.uid;
    FirebaseFirestore.instance
        .collection('users')
        .doc(myUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()!.containsKey('referralBonusInfo')) {
        var bonusInfo = snapshot.data()!['referralBonusInfo'];
        if (bonusInfo != null) {
          showReferralBonusPopup(bonusInfo);
          // Optionally, remove the referral bonus info after showing the popup
          FirebaseFirestore.instance.collection('users').doc(myUserId).update({'referralBonusInfo': FieldValue.delete()});
        }
      }
    });
  }

  void showReferralBonusPopup(Map<String, dynamic> bonusInfo) {
    String message;
    if (bonusInfo['type'] == 'received') {
      message = "Claimed referral from ${bonusInfo['referrerName']}.";
    } else {
      message = "${bonusInfo['referredName']} entered with your referral.";
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          title: Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/NBC-token.png'),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                "100",
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          actions: <Widget>[
            Center(
              child: TextButton(
                child: const Text("OK"),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        );
      },
    );
  }



  Future<void> checkAndUpdateDailyLoginBonus(String userId) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception("User does not exist!");
      }

      var userData = snapshot.data() as Map<String, dynamic>;
      Timestamp? lastLoginDate = userData['lastLoginDate'];
      int consecutiveLoginDays = userData['consecutiveLoginDays'] ?? 0;
      bool bonusReadyToClaim = userData['bonusReadyToClaim'] ?? false;

      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime lastLogin = lastLoginDate?.toDate() ?? DateTime(1970);
      DateTime lastLoginDay = DateTime(lastLogin.year, lastLogin.month, lastLogin.day);

      if (lastLoginDay.isBefore(today) && !bonusReadyToClaim) {
        consecutiveLoginDays = lastLoginDay.add(Duration(days: 1)).isBefore(today) ? 1 : consecutiveLoginDays + 1;

        transaction.update(userRef, {
          'consecutiveLoginDays': consecutiveLoginDays,
          'bonusReadyToClaim': true,
          'lastLoginDate': Timestamp.fromDate(now)
        });
      }
    }).catchError((error) {
      print("Error updating daily bonus: $error");
      // Handle the error appropriately
    });
  }

  Future<void> showDailyBonusDialogIfNeeded(BuildContext context, String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      var userData = userDoc.data() as Map<String, dynamic>;
      bool bonusReadyToClaim = userData['bonusReadyToClaim'] ?? false;
      int consecutiveLoginDays = userData['consecutiveLoginDays'] ?? 0;

      if (bonusReadyToClaim) {
        // Calculate bonus amount based on consecutiveLoginDays
        int bonusAmount = calculateBonusAmount(consecutiveLoginDays);

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              contentPadding: EdgeInsets.symmetric(vertical: 10), // Adjust the vertical padding
              title: Center(
                child: Column(
                  children: [
                    Text(
                      "Daily Login Bonus",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "Login Bonus Day $consecutiveLoginDays",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min, // Set the mainAxisSize to MainAxisSize.min
                children: [
                  Container(
                    child: CircleAvatar(
                      radius: 80,
                      backgroundImage: AssetImage('assets/NBC-token.png'),
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    "$bonusAmount NBC",
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  ElevatedButton(
                    child: const Text("Claim Bonus"),
                    onPressed: () {
                      claimDailyBonus(userId, bonusAmount);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            );
          },
        );
      }
    }
  }

  int calculateBonusAmount(int consecutiveLoginDays) {
    return 20 + (consecutiveLoginDays - 1) * 5;
  }

  Future<void> claimDailyBonus(String userId, int bonusAmount) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (snapshot.exists) {
        var userData = snapshot.data() as Map<String, dynamic>;
        int currentBalance = userData['chessCoins'] ?? 0;
        transaction.update(userRef, {
          'chessCoins': currentBalance + bonusAmount,
          'bonusReadyToClaim': false
        });
      }
    });
  }


  void fetchCurrentUserChessCoins() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    currentUserChessCoins = await getUserChessCoins(userId);
    setState(() {}); // Trigger a rebuild to update the UI
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
          var userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(challengerId)
              .get();
          String challengerName = userDoc.exists
              ? (userDoc.data()!['name'] ?? 'Unknown Challenger')
              : 'Unknown Challenger';
          String challengerImageUrl = userDoc.exists
              ? (userDoc.data()!['avatar'] ?? '')
              : ''; // Assuming the field name is 'avatarUrl'

          showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return ChallengeRequestScreen(
                challengerName: challengerName,
                challengerUID: challengerId,
                opponentUID: currentUserId,
                betAmount: challengeData['betAmount'],
                localTimerValue: challengeData['localTimerValue'],
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
            currentUserChessCoins = userData['chessCoins'] ?? 0;
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
      query = query
          .where('name', isGreaterThanOrEqualTo: searchText)
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

  Future<int> getUserChessCoins(String userId) async {
    DocumentSnapshot userDoc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();

    if (userDoc.exists) {
      // Cast the data to Map<String, dynamic> before accessing its properties
      var userData = userDoc.data() as Map<String, dynamic>;
      return userData['chessCoins'] ?? 0;
    } else {
      return 0; // Handle this case appropriately
    }
  }




  void _showChallengeModal(BuildContext context, Map<String, dynamic> opponentData) {
    String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    int currentUserChessCoins = 0;
    int opponentChessCoins = 0;
    String localBetAmount = betAmount; // Local variable for bet amount
    String localTimerValue = this.localTimerValue; // Initialize with the local value
    bool isChallengeable = !(opponentData['inGame'] ?? false);
    String? currentGameId = opponentData['currentGameId'];
    String opponentId = opponentData['uid'];
    bool isOnline = opponentData['isOnline'] ?? false;

    // Initialize the button state for this user if not already set
    challengeButtonCooldown[opponentId] ??= true;
    bool isButtonEnabled = challengeButtonCooldown[opponentId] ?? true;

    // Function to fetch the current user's Chess Coins and update the state
    // Fetch and update the current user's and opponent's Chess Coins
    Future<void> fetchAndUpdateChessCoins() async {
      currentUserChessCoins = await getUserChessCoins(currentUserId);
      opponentChessCoins = await getUserChessCoins(opponentId);
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // ... existing code for modal layout ...
                    const Text(
                      "Set your Stake",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage(opponentData['avatar']),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            opponentData['name'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            String? userId = opponentData['uid'];
                            if (userId != null) {
                              navigateToUserDetails(context, userId);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Error: User ID is null")),
                              );
                            }
                          },
                          child: const Text('Visit'),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
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
                            decoration: InputDecoration(
                              labelText: 'Bet Amount',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: localTimerValue,
                            items: ['5', '10', '15', '20'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text('$value min'),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setModalState(() {
                                  localTimerValue = newValue;
                                });
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Timer',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 20),
                      ),
                      onPressed: isOnline && (isChallengeable || currentGameId != null) && isButtonEnabled
                          ? () async {
                        int betAmountInt = int.parse(localBetAmount.replaceAll('\$', ''));
                        await fetchAndUpdateChessCoins();
                        if (currentUserChessCoins < betAmountInt) {
                          showInsufficientFundsDialog("You do not have enough Chess Coins to place this bet.");
                        } else if (opponentChessCoins < betAmountInt) {
                          showInsufficientFundsDialog("Opponent does not have enough Chess Coins for this bet.");
                        }
                        else {
                          if (isChallengeable) {
                            setModalState(() =>
                            challengeButtonCooldown[opponentId] = false);
                            await _sendChallenge(
                                opponentData['uid'], localBetAmount,
                                localTimerValue);
                            Navigator.pop(context);
                            Timer(Duration(seconds: 30), () {
                              setState(() =>
                              challengeButtonCooldown[opponentId] = true);
                            });
                          } else if (currentGameId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ChessBoard(gameId: currentGameId),
                              ),
                            );
                          }
                        }
                      }
                          : null, // Disable the button if conditions are not met
                      child: Text(isOnline
                          ? (isChallengeable ? 'Challenge' : 'Watch Game')
                          : 'Player Offline'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendChallenge(String opponentId, String betAmount, String localTimerValue) async {

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
          'localTimerValue': localTimerValue,
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
      } catch (e) {
        print('Error sending challenge: $e');
      }
    } else {
      print('User is not logged in.');
    }
  }

  void showInsufficientFundsDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Insufficient Chess Coins"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
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

  Stream<int> getUnreadMessageCountStream(String userId) {
    String myUserId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = getChatId(myUserId, userId);

    return FirebaseFirestore.instance
        .collection('userChats')
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        var userData = doc.data()?[chatId] as Map<String, dynamic>?;
        return userData?['unreadCount'] ?? 0;
      }
      return 0;
    });
  }




  String getChatId(String user1, String user2) {
    var sortedIds = [user1, user2]..sort();
    return sortedIds.join('_');
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 223, 225, 237),
      body: SafeArea( // Wrap the content in SafeArea
        child: Stack(
          children: [
            // Your existing Column with user profile and grid
            Column(
              children: <Widget>[
                if (currentUser != null) UserProfileHeader(userId: currentUser.uid),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Container(
                    constraints: const BoxConstraints(
                        maxWidth: 600), // Set a maximum width for the search bar
                    child: TextField(
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        labelText: 'Search Players in $userLocation',
                        hintText: 'Enter player name...',
                        prefixIcon: const Icon(Icons.search), // Add search icon
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              10), // Rounded corners for the border
                          borderSide: BorderSide(
                              color: Colors.blueGrey.shade800), // Custom border color
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 20), // Padding inside the text field
                        hintStyle: TextStyle(
                            color: Colors.grey.shade500), // Lighter hint text color
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
                          bool isOnline = userData['isOnline'] ?? false;
                          String userId = userData['uid']; // Assuming each user has a unique 'uid'

                          // Inside GridView.builder
                          return StreamBuilder<int>(
                            stream: getUnreadMessageCountStream(userId),
                            builder: (context, snapshot) {
                              int unreadCount = snapshot.data ?? 0;
                              return GestureDetector(
                                onTap: () => _showChallengeModal(context, userData),
                                child: Column(
                                  children: <Widget>[
                                    Stack(
                                      alignment: Alignment.topRight,
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
                                                color: isOnline
                                                    ? Colors.green
                                                    : Colors.grey
                                                    .shade500, // Red border for offline users
                                                width: 3,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Unread count badge
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 0,
                                            child: Container(
                                              padding: EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '$unreadCount',
                                                style: TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      userData['name'] ?? 'Username',
                                      style: TextStyle(
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
                      );
                    },
                  ),
                ),
              ],
            ),
            // Positioned widget to show balance
            Positioned(
              top: 20, // Adjust top padding as needed
              right: 5, // Adjust right padding as needed
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currentUserChessCoins',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    CircleAvatar(
                      backgroundImage: AssetImage('assets/NBC-token.png'),
                      radius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class UserProfileHeader extends StatelessWidget {
  final String userId;

  const UserProfileHeader({Key? key, required this.userId}) : super(key: key);

  Future<Map<String, dynamic>?> fetchCurrentUserProfile(String userId) async {
    var doc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchCurrentUserProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          String avatarUrl = snapshot.data!['avatar'] ??
              'path/to/default/avatar.png'; // Provide a default path if null
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
                    backgroundImage: AssetImage(
                        avatarUrl), // Using NetworkImage for the avatar
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
          child:
          CircularProgressIndicator(), // Show loading indicator while fetching data
        );
      },
    );
  }
}