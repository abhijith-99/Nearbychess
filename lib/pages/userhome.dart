import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'dart:math' show asin, cos, max, sqrt;
import 'package:geocoding/geocoding.dart';
import 'package:location/location.dart';
import 'geocoding_web.dart';
import 'message_scren.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  UserHomePageState createState() => UserHomePageState();
}

class UserHomePageState extends State<UserHomePage>
    with WidgetsBindingObserver {
  late Stream<List<DocumentSnapshot>> onlineUsersStream;
  String userLocation = 'nowhere';

  late StreamSubscription<DocumentSnapshot> userSubscription;
  late StreamSubscription<QuerySnapshot> challengeRequestsSubscription;





  List<Map<String, dynamic>> _filteredPlayers = [];
  bool _isSearching = false;




  String betAmount = '5'; // Default value
  Map<String, bool> challengeButtonCooldown = {};
  String searchText = '';
  Timer? _debounce;
  String localTimerValue = '10';
  int currentUserChessCoins = 0;

  double? get userLat => null;

  double? get userLon => null;

  String _mapStyle = '';

  // Add GoogleMapController
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  LocationData? currentLocation;
  loc.Location location = loc.Location();

  String? get locationName => null;
  List<Map<String, dynamic>> fetchedUserProfiles =
      []; // To store fetched user profiles
  List<Map<String, dynamic>> searchUserProfiles = [];

  get player1Id => null; // To store search results
  get player2Id => null;

  Future<Uint8List> createCustomMarker(
      String userName, double zoomLevel) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Adjust the size based on the zoom level
    final double iconSize = 50.0 * zoomLevel / 20.0; // Example scaling factor
    const double fontSize = 20.0; // Adjust font size based on zoom level

    final double textMaxWidth = iconSize - 10.0;

    // Define paint for the pin
    final Paint paintPin = Paint()..color = Colors.red;
    final double pinWidth = iconSize /2; // Width of the pin body
    final double pinHeight = iconSize; // Total height of the pin
    final double circleRadius = pinWidth / 2; // Radius of the circular head

// Center of the circular head
    final Offset circleCenter = Offset(iconSize / 2, circleRadius);
// Tip of the pin
    final Offset pinTip = Offset(iconSize / 2, iconSize);

    final Path pinPath = Path()
    // Start at the center top of the circular head
      ..addOval(Rect.fromCircle(center: circleCenter, radius: circleRadius))
    // Draw the smaller circle (hole of the pin)
      ..addOval(Rect.fromCircle(
          center: circleCenter, radius: circleRadius / 2))
    // Move to the bottom of the circular head
      ..moveTo(circleCenter.dx + circleRadius, circleCenter.dy)
    // Draw the body of the pin down to the tip
      ..lineTo(pinTip.dx, pinTip.dy)
    // Draw the left side of the pin body up to the bottom of the head
      ..lineTo(circleCenter.dx - circleRadius, circleCenter.dy)
      ..close();

// Create a paint for the pin hole (same as the background)
    final Paint paintHole = Paint()..color = Colors.white;

// Draw the pin path
    canvas.drawPath(pinPath, paintPin);

// Draw the hole path
    final Path holePath = Path()
      ..addOval(Rect.fromCircle(
          center: circleCenter, radius: circleRadius / 2));
    canvas.drawPath(holePath, paintHole);
    // Calculate the total height of the canvas to fit the icon and the text
    final double canvasHeight = iconSize + fontSize; // Space for text

    // Draw the text
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: userName,
        style: const TextStyle(
          fontSize: 20,
          color: Colors.yellowAccent, // Text color
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 1, // Allow text to wrap to the second line
    );
    textPainter.layout(
        maxWidth: textMaxWidth); // Set the maximum width for text
    final Offset textOffset =
        Offset((iconSize - textPainter.width) / 2, iconSize);
    textPainter.paint(canvas, textOffset);
    // Convert canvas to image
    final ui.Image markerAsImage = await pictureRecorder
        .endRecording()
        .toImage(iconSize.toInt(), canvasHeight.toInt());

    // Convert image to bytes
    final ByteData? byteData =
        await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List uint8List = byteData!.buffer.asUint8List();

    return uint8List;
  }



  Future<ui.Image> loadImage(Uint8List img) async {
    final Completer<ui.Image> completer = new Completer();
    ui.decodeImageFromList(img, (ui.Image img) {
      return completer.complete(img);
    });
    return completer.future;
  }

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

    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    String userName =
        userDoc['name']; // Replace 'name' with your Firestore field
    String userAvatar = userDoc['avatar'];

    // Create the custom marker
    final Uint8List markerIcon =
        await createCustomMarker(userName, _currentZoomLevel);

    // Update the location on the map.
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target:
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
          zoom: 15.0,
        ),
      ),
    );

    // Place a marker on the current location.
    setState(() {
      markers.add(
        Marker(
          markerId: const MarkerId("current_location"),
          position:
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
          icon: BitmapDescriptor.fromBytes(markerIcon),
        ),
      );
    });
  }

  Future<void> getUserLocationForWeb() async {
    if (kDebugMode) {
      print("getuserlocationforweb is called");
    }
    try {
      loc.Location location = loc.Location();
      bool _serviceEnabled;
      loc.PermissionStatus _permissionGranted;
      loc.LocationData _locationData;

      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          throw Exception('Location services are disabled.');
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == loc.PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != loc.PermissionStatus.granted) {
          throw Exception('Location permissions are denied');
        }
      }

      _locationData = await location.getLocation();
      String cityName = await getPlaceFromCoordinates(
        _locationData.latitude!,
        _locationData.longitude!,
      );

      setState(() {
        userLocation = cityName;
        onlineUsersStream = fetchOnlineUsersWithLocationName(userLocation);
      });
    } catch (e) {
      print('Error getting location for web: $e');
      setState(() {
        userLocation = 'Unknown';
        print('Error getting location for web: ${e.toString()}');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setupUserListener();
    listenToChallengeRequests();
    fetchCurrentUserChessCoins();
    onlineUsersStream = const Stream<List<DocumentSnapshot>>.empty();
    fetchedUserProfiles;


    _loadMapStyle();
    _determinePosition().then((_) {
      setupOpponentsListener();
    });

    if (kIsWeb) {
      getUserLocationForWeb();
    }
  }

  Future<void> _loadMapStyle() async {
    _mapStyle = await rootBundle.loadString('assets/new_map.json');

    if (mapController != null) {
      mapController!.setMapStyle(_mapStyle);
    }

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
      if (snapshot.exists &&
          snapshot.data()!.containsKey('referralBonusInfo')) {
        var bonusInfo = snapshot.data()!['referralBonusInfo'];
        if (bonusInfo != null) {
          showReferralBonusPopup(bonusInfo);
          // Optionally, remove the referral bonus info after showing the popup
          FirebaseFirestore.instance
              .collection('users')
              .doc(myUserId)
              .update({'referralBonusInfo': FieldValue.delete()});
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          title: const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage('assets/NBC-token.png'),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
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
    DocumentReference userRef =
        FirebaseFirestore.instance.collection('users').doc(userId);

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
      DateTime lastLoginDay =
          DateTime(lastLogin.year, lastLogin.month, lastLogin.day);

      if (lastLoginDay.isBefore(today) && !bonusReadyToClaim) {
        consecutiveLoginDays =
            lastLoginDay.add(Duration(days: 1)).isBefore(today)
                ? 1
                : consecutiveLoginDays + 1;

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

  Future<void> showDailyBonusDialogIfNeeded(
      BuildContext context, String userId) async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

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
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              // Adjust the vertical padding
              title: Center(
                child: Column(
                  children: [
                    const Text(
                      "Daily Login Bonus",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Login Bonus Day $consecutiveLoginDays",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                // Set the mainAxisSize to MainAxisSize.min
                children: [
                  Container(
                    child: const CircleAvatar(
                      radius: 80,
                      backgroundImage: AssetImage('assets/NBC-token.png'),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "$bonusAmount NBC",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 5),
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
    DocumentReference userRef =
        FirebaseFirestore.instance.collection('users').doc(userId);
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

          String player1Id = challengeData['challengerId']; // Example
          String player2Id = challengeData['opponentId']; // Example
          String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

          bool userIsSpectator =
              currentUserId != player1Id && currentUserId != player2Id;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  // ChessBoard(gameId: gameId, isSpectator: true),
                  ChessBoard(
                      gameId: gameId,
                      isSpectator: userIsSpectator,
                      opponentUID: player2Id),
            ),
          ).then((_) {
            // User has left the Chessboard, update the inGame status
            updateInGameState(false);
          });
        }
      }
    });
  }

  // Function to get the human-readable location name from coordinates
  Future<String> getLocationName(double latitude, double longitude) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks[0];
      return placemark.locality ?? placemark.name ?? 'Unknown Location';
    } else {
      return 'Unknown Location';
    }
  }


  void setupUserListener() {
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      List<Map<String, dynamic>> updatedUserProfiles = [];

      for (var change in snapshot.docChanges) {
        var userData = change.doc.data() as Map<String, dynamic>;
        if (userData['uid'] == currentUserId) {
          continue; // Skip the current user's data
        }
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          int index = updatedUserProfiles.indexWhere((user) => user['uid'] == userData['uid']);
          if (index >= 0) {
            updatedUserProfiles[index] = userData; // Update existing user
          } else {
            updatedUserProfiles.add(userData); // Add new user
          }
        }
      }


      setState(() {
        fetchedUserProfiles = updatedUserProfiles;
        searchUserProfiles = List.from(updatedUserProfiles);

      });
    });
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
    super.didChangeAppLifecycleState(state);
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

  double calculateDistance(lat1, lon1, lat2, lon2) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      // handle null case, maybe return a default value or throw an exception
      return 0.0; // Example default value
    }

    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  Stream<List<DocumentSnapshot>> fetchNearbyOpponents(
      double userLat, double userLon, double radiusInKm) {
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    print("current userod from fetchnearby $currentUserId");
    return FirebaseFirestore.instance
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {

        // var userData = doc.data();
        var userData = doc.data();
        if (userData['uid'] == currentUserId) {
          return false;
        }

        var distance = calculateDistance(userLat, userLon, userData['latitude'], userData['longitude']);
        return distance <= radiusInKm;

      }).toList();
    });
  }

  void setupOpponentsListener() {
    _determinePosition().then((_) {
      // Check if currentLocation is not null before using it
      if (currentLocation != null) {
        double userLat = currentLocation!.latitude!;
        double userLon = currentLocation!.longitude!;

        // Now call fetchNearbyOpponents with the actual latitude and longitude
        fetchNearbyOpponents(
                userLat, userLon, 10.0) // Adjust the radius as needed
            .listen((userDocs) {
          updateMarkers(userDocs);
        });
      }
    });
  }


  Stream<List<DocumentSnapshot>> fetchOnlineUsersWithLocationName(String city) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('city', isEqualTo: city)
        .snapshots()
        .map((snapshot) => snapshot.docs); // Keep it as DocumentSnapshot
  }

  double _currentZoomLevel = 30.0; // Starting with a default zoom level

  void updateMarkers(List<DocumentSnapshot> userDocs) async {
    Set<Marker> newMarkers = {};
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    for (var doc in userDocs) {
      var userData = doc.data() as Map<String, dynamic>;
      if (userData['uid'] == currentUserId) continue;

      double? lat = userData['latitude'] as double?;
      double? lon = userData['longitude'] as double?;

      if (lat != null && lon != null) {
        // Pass the current zoom level to createCustomMarker
        final Uint8List markerIcon =
            await createCustomMarker(userData['name'], _currentZoomLevel);

        var userMarker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lon),
          icon: BitmapDescriptor.fromBytes(markerIcon),
          onTap: () {
            _showChallengeModal(context, userData);
          },
        );
        newMarkers.add(userMarker);
      }
    }

    setState(() {
      markers.clear();
      markers = newMarkers;
    });
  }

  void updateUserLocation(LocationData location) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    await userRef.update({
      'latitude': location.latitude,
      'longitude': location.longitude,
    });
  }



  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _isSearching = false;
        });
      } else {
        var filteredProfiles = fetchedUserProfiles.where((user) {
          String name = user['name'].toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        setState(() {
          _filteredPlayers = filteredProfiles;
          _isSearching = true;
        });
      }
    });
  }



  Future<List<Map<String, dynamic>>> fetchUsersByName(String searchName) async {
    // Perform a case-insensitive search
    String searchKey = searchName.toLowerCase();

    // Query Firestore for users whose names start with the search term
    QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('name_lowercase', isGreaterThanOrEqualTo: searchKey)
        .where('name_lowercase', isLessThanOrEqualTo: searchKey + '\uf8ff')
        .get();

    // Map the documents to a List of Maps
    List<Map<String, dynamic>> userProfiles = querySnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    return userProfiles;
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

  void _showChallengeModal(
      BuildContext context, Map<String, dynamic> opponentData) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    // Add this check at the beginning of the method
    if (opponentData['uid'] == currentUserId) {
      return; // Exit the function if the user is trying to challenge themselves
    }
    int currentUserChessCoins = 0;
    int opponentChessCoins = 0;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // ... existing code for modal layout ...
                    const Text(
                      "Set your Stake",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        // fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(opponentData['avatar']),
                          onBackgroundImageError: (exception, stackTrace) {
                          },
                        ),
                        const SizedBox(width: 2),
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

                        // Message Icon Button
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline),
                          color: Colors.blue,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MessageScreen(opponentUId: opponentData['uid']),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 8),
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
                    SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              value: localBetAmount,
                              items: [
                                {'value': '5', 'image': 'assets/NBC-token.png'},
                                {'value': '10', 'image': 'assets/NBC-token.png'},
                                {'value': '15', 'image': 'assets/NBC-token.png'},
                              ].map((Map<String, String> item) {
                                return DropdownMenuItem<String>(
                                  value: item['value'],
                                  child: Row(
                                    children: <Widget>[
                                      Text('${item['value']}'),
                                      const SizedBox(width: 8),
                                      Image.asset(item['image']!, width: 20, height: 20),
                                    ],
                                  ),
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
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black54, width: 1.0),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: localTimerValue,
                            items: ['5', '10', '15'].map((String value) {
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
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Adjust padding as needed
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.black54, width: 1.0), // Use a lighter color for the enabled border if you prefer
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.blue, width: 2.0), // Use a more prominent color when the field is focused
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
                        backgroundColor: isChallengeable ? Colors.green : Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 20),
                      ),
                      onPressed: isOnline &&
                              (isChallengeable || currentGameId != null) &&
                              (isChallengeable ? isButtonEnabled : true)
                          ? () async {
                              // Only perform the coin check if the user is challenging, not watching
                              if (isChallengeable) {
                                int betAmountInt = int.parse(
                                    localBetAmount.replaceAll('\$', ''));
                                await fetchAndUpdateChessCoins();
                                if (currentUserChessCoins < betAmountInt) {
                                  showInsufficientFundsDialog(
                                      "You do not have enough Chess Coins to place this bet.");
                                } else if (opponentChessCoins < betAmountInt) {
                                  showInsufficientFundsDialog(
                                      "Opponent does not have enough Chess Coins for this bet.");
                                } else {
                                  // Rest of the challenge logic
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
                                }
                              } else if (currentGameId != null) {
                                // Bypass the coin check for watching
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        // ChessBoard(gameId: currentGameId, isSpectator: true),
                                        ChessBoard(
                                            gameId: currentGameId,
                                            isSpectator: true,
                                            opponentUID: player1Id),
                                  ),
                                );
                              }
                            }
                          : null,
                      // Disable the button if conditions are not met
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

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _determinePosition();
    mapController?.setMapStyle(_mapStyle);
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


  void _initiateDataStreams() {
    setupUserListener();
    listenToChallengeRequests();
    fetchCurrentUserChessCoins();
    if (kIsWeb) {
      getUserLocationForWeb();
    } else {
      _determinePosition().then((_) {
        setupOpponentsListener();
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      // Cancel existing stream subscriptions
      userSubscription.cancel();
      challengeRequestsSubscription.cancel();
      _initiateDataStreams();
    });
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? currentUser = auth.currentUser;
    final String userId = currentUser?.uid ?? '';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
      backgroundColor: const Color.fromARGB(255, 223, 225, 237),
      child: SafeArea(
        child: Stack(
          // Use Stack to overlay widgets
          children: [
            Row(
              // Use Row to divide the screen into two sections
              children: [
                // Left section - Google Map (60% width)
                Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 13.0, top: 13.0, bottom: 13.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                            40), // Adjust the radius as needed
                        child: GoogleMap(
                          // Your GoogleMap properties here
                          // padding: const EdgeInsets.all(20),
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: const CameraPosition(
                            target: LatLng(0, 0),
                            zoom: 45,
                          ),
                          markers: markers,
                        ),
                      ),
                    )),

                // Right section - User Avatar, Search, and List (40% width)
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      if (currentUser != null)
                        UserProfileHeader(userId: currentUser.uid),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        child: TextField(
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'Enter player name...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.blueGrey.shade800),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 10),
                            hintStyle: TextStyle(color: Colors.grey.shade500),
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
                              return const Center(child: Text('No players here.'));
                            }

                            // Populate or update fetchedUserProfiles with snapshot data if not searching
                            if (!_isSearching && snapshot.data!.isNotEmpty) {
                              fetchedUserProfiles = snapshot.data!
                                  .map((doc) => doc.data() as Map<String, dynamic>)
                                  .where((user) => user['uid'] != FirebaseAuth.instance.currentUser?.uid)
                                  .toList();

                              fetchedUserProfiles.sort((a, b) {
                                // Ensure we have valid booleans for comparison
                                bool aIsOnline = a['isOnline'] as bool? ?? false;
                                bool bIsOnline = b['isOnline'] as bool? ?? false;

                                // Convert booleans to integers for comparison (true > false)
                                int aInt = aIsOnline ? 1 : 0;
                                int bInt = bIsOnline ? 1 : 0;

                                // Compare the integer representations
                                return bInt.compareTo(aInt);
                              });
                            }


                            List<Map<String, dynamic>> usersToShow = _isSearching ? _filteredPlayers : fetchedUserProfiles;

                            // Update the logic to handle an empty list after filtering
                            if (usersToShow.isEmpty) {
                              // This condition checks if the list is empty after filtering
                              return Center(
                                child: Text(
                                  _isSearching ? 'oops!  No players found with that name.' : 'oops!  No players found with that name..',
                                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                                ),
                              );
                            }


                            return GridView.builder(
                              key: UniqueKey(),
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 5,
                                mainAxisSpacing: 5,
                                childAspectRatio: 1,
                              ),
                              // GridView.builder properties...
                              itemCount: usersToShow.length,
                              itemBuilder: (context, index) {
                                var userData = usersToShow[index];
                                return buildPlayerTile(userData, context);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Positioned(
              top: 10,
              right: 10,
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container();
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const Text('Loading...');
                  }

                  int chessCoins = (snapshot.data!.data()
                          as Map<String, dynamic>)['chessCoins'] ??
                      0;

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white, // Background color for the container
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 1,
                          offset: const Offset(0, 1), // changes position of shadow
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$chessCoins',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const CircleAvatar(
                          backgroundImage: AssetImage('assets/NBC-token.png'),
                          radius: 10,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }


  Widget buildPlayerTile(Map<String, dynamic> userData, BuildContext context) {
    String avatarUrl = userData['avatar'];
    bool isOnline = userData['isOnline'] ?? false;
    String userId = userData['uid']; // Assuming each user has a unique 'uid'

    // Check if the tile is for the current user
    if (userData['uid'] == FirebaseAuth.instance.currentUser?.uid) {
      // Return an empty container or some other appropriate widget
      return Container();
    }

    return GestureDetector(
      onTap: () => _showChallengeModal(context, userData),
      child: Column(
        children: <Widget>[
          Stack(
            alignment: Alignment.topRight,
            children: <Widget>[
              CircleAvatar(
                backgroundImage: NetworkImage(avatarUrl),
                radius: 36,
                backgroundColor: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(avatarUrl),
                      fit: BoxFit.cover,
                      colorFilter: isOnline
                          ? null
                          : const ColorFilter.mode(
                              Colors.grey, BlendMode.saturation),
                    ),
                    border: Border.all(
                      color: isOnline ? Colors.green : Colors.grey.shade500,
                      width: 3,
                    ),
                  ),
                ),
              ),

              StreamBuilder<int>(
                stream: getUnreadMessageCountStream(userId),
                builder: (context, snapshot) {
                  int unreadCount = snapshot.data ?? 0;
                  if (unreadCount > 0) {
                    return Positioned(
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),


            ],
          ),
          const SizedBox(height: 6),
          Text(
            userData['name'] ?? 'Username',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: isOnline ? const Color.fromARGB(255, 12, 6, 6) : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class UserProfileHeader extends StatefulWidget {
  final String userId;

  const UserProfileHeader({Key? key, required this.userId}) : super(key: key);

  @override
  _UserProfileHeaderState createState() => _UserProfileHeaderState();
}

class _UserProfileHeaderState extends State<UserProfileHeader> {
  Future<Map<String, dynamic>?>? _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = fetchCurrentUserProfile(widget.userId);
  }

  Future<Map<String, dynamic>?> fetchCurrentUserProfile(String userId) async {
    var doc =
    await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() as Map<String, dynamic> : null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _userProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          String avatarUrl = snapshot.data!['avatar'] ??
              'path/to/default/avatar.png';
          String userName = snapshot.data!['name'] ?? 'Unknown User';


          return Padding(
            padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () =>
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UserProfileDetailsPage(),
                        ),
                      ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(
                        avatarUrl), // Using NetworkImage for the avatar
                  ),
                ),
                const SizedBox(height: 4),
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
        return Container(); // Show a loading or empty container when data is not yet available
      },
    );
  }
}
