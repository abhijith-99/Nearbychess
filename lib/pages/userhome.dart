import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:mychessapp/main.dart';
import 'package:mychessapp/pages/challengewaitingscreen.dart';
import '../userprofiledetails.dart';
import '../utils.dart';
import 'ChessBoard.dart';
import 'UserDetails.dart';
import 'challenge_request_screen.dart';

import 'package:location/location.dart' as loc;

import 'dart:math' show cos, sqrt, asin, pi;
import 'package:geocoding/geocoding.dart';
import 'package:geocoding/geocoding.dart' hide Location;

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
  String localTimerValue = '20';

  double? get userLat => null;
  double? get userLon => null;

  // Add GoogleMapController
  GoogleMapController? mapController;
  Set<Marker> markers = {};

  LocationData? currentLocation;
  // Location location = Location();
  loc.Location location = loc.Location();


 Future<void> _determinePosition() async {
  bool serviceEnabled;
  loc.PermissionStatus permissionGranted;

  // Check if location services are enabled.
  serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      return;
    }
  }

  // Check for permission.
  permissionGranted = await location.hasPermission();
  if (permissionGranted == loc.PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != loc.PermissionStatus.granted) {
      return;
    }
  }

  // Get the current location.
  currentLocation = await location.getLocation();

  // Update the location on the map.
  mapController?.animateCamera(
    CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        zoom: 15.0,
      ),
    ),
  );

  // Place a marker on the current location.
  setState(() {
    markers.add(
      Marker(
        markerId: const MarkerId("current_location"),
        position: LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        // Include the info window with the user name
        infoWindow: const InfoWindow(
          title: "User Name", // Replace with actual user name fetched from Firestore
          snippet: "Current Location",
        ),
        icon: BitmapDescriptor.defaultMarker, // Replace with custom icon if needed
      ),
    );
  });
}


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupUserListener();
    listenToChallengeRequests();
    onlineUsersStream = const Stream<List<DocumentSnapshot>>.empty();

    _determinePosition();
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

          // ignore: use_build_context_synchronously
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
                challengerImageUrl:
                    challengerImageUrl, // Pass the image URL here
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

  // void setupUserListener() {
  //   var user = FirebaseAuth.instance.currentUser;
  //   if (user != null) {
  //     userSubscription = FirebaseFirestore.instance
  //         .collection('users')
  //         .doc(user.uid)
  //         .snapshots()
  //         .listen((snapshot) {
  //       if (snapshot.exists) {
  //         var userData = snapshot.data() as Map<String, dynamic>;
  //         setState(() {
  //           userLocation = userData['location'] ?? 'Unknown';
  //           onlineUsersStream = fetchOnlineUsers(userLat, userLat);
  //         });
  //       }
  //     });
  //   }
  // }

  void setupUserListener() {
    var user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          var userData = snapshot.data() as Map<String, dynamic>;
          double userLat = userData['latitude'];
          double userLon = userData['longitude'];

          // Reverse geocode the user's coordinates to get the nearest placemark
          List<Placemark> placemarks =
              await placemarkFromCoordinates(userLat, userLon);

          // Assuming we take the first placemark as the major point
          Placemark majorPoint = placemarks.first;

          // Update Firestore with the major point name
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'location': majorPoint.name});

          setState(() {
            userLocation = majorPoint.name ?? 'Unknown';
            onlineUsersStream = fetchOnlineUsers(userLat, userLon);
            // Update your stream if needed, or any other state updates
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

  // Stream<List<DocumentSnapshot>> fetchOnlineUsers(String? location) {
  //   Query query = FirebaseFirestore.instance.collection('users');

  //   if (location != null && location.isNotEmpty) {
  //     query = query.where('location', isEqualTo: location);
  //   }

  //   if (searchText.isNotEmpty) {
  //     String searchEnd = searchText.substring(0, searchText.length - 1) +
  //         String.fromCharCode(searchText.codeUnitAt(searchText.length - 1) + 1);
  //     query = query
  //         .where('name', isGreaterThanOrEqualTo: searchText)
  //         .where('name', isLessThan: searchEnd);
  //   }

  //   return query.snapshots().map((snapshot) => snapshot.docs);
  // }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Stream<List<DocumentSnapshot>> fetchOnlineUsers(
      double? userLat, double? userLon) {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.where((doc) {
              var userData = doc.data() as Map<String, dynamic>;
              var lat = userData['latitude'];
              var lon = userData['longitude'];
              var distance = calculateDistance(userLat, userLon, lat, lon);
              return distance <= 0.1; // 0.1 km is 100 meters
            }).toList());
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        searchText = query;
        onlineUsersStream = fetchOnlineUsers(userLat, userLon);
      });
    });
  }

  void _showChallengeModal(
      BuildContext context, Map<String, dynamic> opponentData) {
    String localBetAmount = betAmount; // Local variable for bet amount
    String localTimerValue =
        this.localTimerValue; // Initialize with the local value
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
                      onPressed: isOnline &&
                              (isChallengeable || currentGameId != null) &&
                              isButtonEnabled
                          ? () async {
                              if (isChallengeable) {
                                setModalState(() =>
                                    challengeButtonCooldown[opponentId] =
                                        false);
                                await _sendChallenge(opponentData['uid'],
                                    localBetAmount, localTimerValue);
                                Navigator.pop(context);
                                Timer(Duration(seconds: 30), () {
                                  setState(() =>
                                      challengeButtonCooldown[opponentId] =
                                          true);
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
                          : null,
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

  Future<void> _sendChallenge(
      String opponentId, String betAmount, String localTimerValue) async {
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

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _determinePosition();
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      // backgroundColor: const Color.fromARGB(255, 223, 225, 237),
      appBar: AppBar(
        toolbarHeight: 0, // AppBar is hidden
        elevation: 0,
      ),

      body: Column(
        children: <Widget>[
          Expanded(
            flex: 3, // 75% of the screen
            child: GoogleMap(
              // onMapCreated: (GoogleMapController controller) {
              //   mapController = controller;
              // },

              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                // Replace with actual user location
                // target: LatLng(37.7749, -122.4194),
                target: LatLng(0, 0),
                zoom: 15,
              ),
              markers: markers,
            ),
          ),

          // if (currentUser != null) UserProfileHeader(userId: currentUser.uid),
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
          // ... rest of the code for GridView.builder ...
          Expanded(
            flex: 1,
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
                                  color: isOnline
                                      ? Colors.green
                                      : Colors.grey
                                          .shade500, // Red border for offline users
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
