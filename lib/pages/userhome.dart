import 'dart:async';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
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
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';


class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  UserHomePageState createState() => UserHomePageState();
}

class UserHomePageState extends State<UserHomePage>
    with WidgetsBindingObserver {

  double _zoomThreshold = 10.0;


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
  String localTimerValue = '5';
  int currentUserChessCoins = 0;

  double? get userLat => null;

  double? get userLon => null;

  String _mapStyle = '';

  // Add GoogleMapController
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  double _currentZoomLevel = 30.0;
  LocationData? currentLocation;
  loc.Location location = loc.Location();

  String? get locationName => null;
  List<Map<String, dynamic>> fetchedUserProfiles =
      []; // To store fetched user profiles
  List<Map<String, dynamic>> searchUserProfiles = [];

  get player1Id => null; // To store search results
  get player2Id => null;

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
          target:
              LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
          zoom: 17.0,
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
          // icon: BitmapDescriptor.fromBytes(markerIcon),
        ),
      );
    });
  }

  Future<void> getUserLocationForWeb() async {
    if (kDebugMode) {}
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

      if (mounted) {
        setState(() {
          userLocation = cityName;
          onlineUsersStream = fetchOnlineUsersWithLocationName(userLocation);
        });
      }
    } catch (e) {
      print('Error getting location for web: $e');
      if (mounted) {
        setState(() {
          userLocation = 'Unknown';
          print('Error getting location for web: ${e.toString()}');
        });
      }
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

    if (mounted) {
      setState(() {});
    }

    // Trigger a rebuild to update the UI
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

    FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> updatedUserProfiles = [];

      for (var change in snapshot.docChanges) {
        var userData = change.doc.data() as Map<String, dynamic>;
        if (userData['uid'] == currentUserId) {
          continue; // Skip the current user's data
        }
        if (change.type == DocumentChangeType.added ||
            change.type == DocumentChangeType.modified) {
          int index = updatedUserProfiles
              .indexWhere((user) => user['uid'] == userData['uid']);
          if (index >= 0) {
            updatedUserProfiles[index] = userData; // Update existing user
          } else {
            updatedUserProfiles.add(userData); // Add new user
          }
        }
      }

      if (mounted) {
        setState(() {
          fetchedUserProfiles = updatedUserProfiles;
          searchUserProfiles = List.from(updatedUserProfiles);
        });
      }
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
    // try {
    //   String userId = FirebaseAuth.instance.currentUser!.uid;
    //   CollectionReference users =
    //       FirebaseFirestore.instance.collection('users');
    //   await users.doc(userId).update({'isOnline': isOnline});
    // } catch (e) {
    //   print('Error updating online status: $e');
    // }


    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      CollectionReference users = FirebaseFirestore.instance.collection('users');
      if (isOnline) {
        // When the user comes online, update both the isOnline flag and the lastSeen timestamp
        await users.doc(userId).update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } else {
        // or set isOnline to false explicitly depending on your app's needs
        await users.doc(userId).update({
          'isOnline': false,
        });
      }
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
    return FirebaseFirestore.instance
        .collection('users')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        var userData = doc.data();
        if (userData['uid'] == currentUserId) {
          return false;
        }

        var distance = calculateDistance(
            userLat, userLon, userData['latitude'], userData['longitude']);
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
                userLat, userLon, 20.0) // Adjust the radius as needed
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


  Future<BitmapDescriptor> createCustomMarkerIcon(String userName, String avatarUrl) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    // Correct canvas size to 100x150
    final Canvas canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 100, 150));

    final Uint8List avatarData = await _downloadImage(avatarUrl);
    final ui.Codec codec = await ui.instantiateImageCodec(avatarData);
    final ui.FrameInfo fi = await codec.getNextFrame();
    final ui.Image avatarImage = fi.image;

    // Your existing code for scaling and drawing the avatar...

    // Calculate the scaling factor to achieve 'object-fit: cover' effect
    final double avatarAspectRatio = avatarImage.width / avatarImage.height;
    const double targetAspectRatio = 10 / 10; // Assuming a square target area for simplicity
    double scale;
    Offset offset;

    if (avatarAspectRatio > targetAspectRatio) {
      // Image is wider than target, scale by height
      scale = 50 / avatarImage.height;
      double croppedWidth = avatarImage.width * scale;
      // Center horizontally
      offset = Offset((50 - croppedWidth) / 2, 0);
    } else {
      // Image is taller than target, scale by width
      scale = 50 / avatarImage.width;
      double croppedHeight = avatarImage.height * scale;
      // Center vertically
      offset = Offset(0, (50 - croppedHeight) / 3);
    }


    // Transform canvas to scale image
    canvas.save();


    // Clip path for circular avatar
    final Path clipPath = Path()..addOval(Rect.fromCircle(center: Offset(50, 35), radius: 25));
    canvas.clipPath(clipPath);
    //
    canvas.translate(25 + offset.dx, 10 + offset.dy);
    canvas.scale(scale, scale);

    // Now draw the image within the clipped and scaled area
    canvas.drawImage(avatarImage, Offset.zero, Paint());

    // Make sure the canvas state is restored after drawing the avatar to remove the clipping effect
    canvas.restore(); // This should match an existing canvas.save() call before the clipping and avatar drawing


    String displayName = userName.length > 7 ? '${userName.substring(0, 7)}...' : userName;
    // Now draw the name without being affected by the previous clipping path
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayName,
        style: const TextStyle(color: Colors.amberAccent, fontSize: 14),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 90);

    // Adjust the Y-offset to ensure the name is positioned correctly within the canvas bounds
    textPainter.paint(canvas, Offset((100 - textPainter.width) / 2,60));

    final ui.Image markerAsImage = await recorder.endRecording().toImage(100, 150);
    final ByteData? byteData = await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(pngBytes);
  }








  Future<Uint8List> _downloadImage(String url) async {
    try {
      final http.Response response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;

      } else {
        throw Exception('Failed to load image');
      }
    }
    catch (e) {
      // Load default image from assets if fetching fails
      final ByteData byteData = await rootBundle.load('assets/NBC-token.png');
      return byteData.buffer.asUint8List();
    }

  }



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

        // print("userdata$userData");
        BitmapDescriptor icon = await createCustomMarkerIcon(userData['name'], userData['avatar'],);

        // Adding marker with default icon
        var userMarker = Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lon),
          icon: icon,
          // Default icon is used automatically, no need to specify
            onTap: () {
              _showChallengeModalFromBottom(context, userData);
            },
        );
        newMarkers.add(userMarker);
      }
    }
    if (mounted) {
      setState(() {
        markers.clear();
        // markers = newMarkers;
        markers.addAll(newMarkers);
      });
    }

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
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      } else {
        var filteredProfiles = fetchedUserProfiles.where((user) {
          String name = user['name'].toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();

        if (mounted) {
          setState(() {
            _filteredPlayers = filteredProfiles;
            _isSearching = true;
          });
        }
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

  void _showChallengeModalFromBottom(
      BuildContext context, Map<String, dynamic> opponentData) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (opponentData['uid'] == currentUserId) {
      return; // Exit the function if the user is trying to challenge themselves
    }
    int currentUserChessCoins = 0;
    int opponentChessCoins = 0;

    String localBetAmount =
        betAmount; // Local variable for bet amount, initially set to class level variable
    String localTimerValue = this
        .localTimerValue; // Initialize with the local value from class level variable
    bool isChallengeable = !(opponentData['inGame'] ?? false);
    String? currentGameId = opponentData['currentGameId'];
    String opponentId = opponentData['uid'];
    bool isOnline = opponentData['isOnline'] ?? false;

    const double tileWidth = 90.0;
    const double tileHeight = 55.0;

    // Initialize the button state for this user if not already set
    challengeButtonCooldown[opponentId] ??= true;
    bool isButtonEnabled = challengeButtonCooldown[opponentId] ?? true;

    // Define bet amount and timer options
    List<Map<String, dynamic>> betAmountOptions = [
      {'value': '5', 'asset': 'assets/NBC-token.png'},
      {'value': '10', 'asset': 'assets/NBC-token.png'},
      {'value': '15', 'asset': 'assets/NBC-token.png'},
    ];
    List<String> timerOptions = ['5', '10', '15'];

    // Function to fetch and update Chess Coins
    Future<void> fetchAndUpdateChessCoins() async {
      currentUserChessCoins = await getUserChessCoins(currentUserId);
      opponentChessCoins = await getUserChessCoins(opponentId);
    }

    showGeneralDialog(
      context: context,
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {


        double screenWidth = MediaQuery.of(context).size.width;
        double containerWidth = screenWidth < 1300 ? screenWidth * 0.8 : screenWidth * 0.4;
        double screenHeight = MediaQuery.of(context).size.height;



        double modalHeight;
        if (screenWidth >= 600 && screenWidth < 900) {
          // Adjust height for screens 600px to 799px
          modalHeight = isOnline && isChallengeable ? screenHeight * 0.50 : screenHeight * 0.30;
        } else if (screenWidth >= 900 && screenWidth <= 1024) {
          // Adjust height for screens 800px to 1024px
          modalHeight = isOnline && isChallengeable ? screenHeight * 0.40 : screenHeight * 0.25;
        } else if (screenWidth > 1024 && screenWidth < 1300) {
          // Adjust height for screens 1025px to 1299px
          modalHeight = isOnline && isChallengeable ? screenHeight * 0.53 : screenHeight * 0.45;
        } else {
          // For wider screens, keep the original logic or adjust as needed
          modalHeight = isOnline && isChallengeable ? screenHeight * 0.6 : screenHeight * 0.4;
        }


        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Align(
              // alignment: Alignment.bottomRight,
              alignment: screenWidth < 1300 ? Alignment.bottomCenter : Alignment.bottomRight,
              child: Container(
                // width: MediaQuery.of(context).size.width * 0.4,
                width: containerWidth,
                height: modalHeight,
                // Full screen height
                padding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 32.0),
                decoration: const BoxDecoration(
                  color: Color(0xFF272727),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20), // Adjust the radius as needed
                    topRight: Radius.circular(20),
                  ),
                ),
                // Modal background color
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Your existing modal content goes here
                      // For example, starting with the "Set your Stake" Text widget
                      const Text(
                        "SET YOUR STAKE",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left:
                                    20.0), // Adjust the left padding as needed
                            child: CircleAvatar(
                              radius: 40,
                              backgroundImage:
                                  NetworkImage(opponentData['avatar']),
                              onBackgroundImageError:
                                  (exception, stackTrace) {},
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 15.0),
                              // Add padding to the username
                              child: Text(
                                opponentData['name'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                  color: Colors.white, // Username text color
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Stack(
                              children: [
                                const Icon(
                                  Icons.email,
                                  color: Colors.white,
                                  size: 22,
                                ), // Your existing icon
                                Positioned(
                                  // Position the unread indicator
                                  top: 0,
                                  right: 0,
                                  child: StreamBuilder<int>(
                                    stream: getUnreadMessageCountStream(
                                        opponentData['uid']),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData &&
                                          snapshot.data! > 0) {
                                        // Show a simple red dot for any number of unread messages
                                        return Container(
                                          width: 12, // Small dot size
                                          height: 12, // Small dot size
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        );
                                      }
                                      return const SizedBox
                                          .shrink(); // No indicator if no unread messages
                                    },
                                  ),
                                ),
                              ],
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MessageScreen(
                                      opponentUId: opponentData['uid']),
                                ),
                              ).then((_) {
                                // Optionally reset the unread count after visiting the message screen
                              });
                            },
                          ),
                          const SizedBox(width: 12),

                          IconButton(
                            icon: const Icon(
                              Icons.visibility, // Eye icon
                              color: Color(0xEAEEECFF), // Icon color
                            ),
                            onPressed: () {
                              // Your onPressed code here, for example, navigating to user details
                              String? userId = opponentData['uid'];
                              if (userId != null) {
                                navigateToUserDetails(context, userId);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Error: User ID is null"),
                                  ),
                                );
                              }
                            },
                          ),

                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(
                        thickness: 2,
                        // Thickness of the divider line
                        indent: 20,
                        // Starting space of the divider (left padding)
                        endIndent: 20,
                        // Ending space of the divider (right padding)
                        color: Colors.grey, // Color of the divider line
                      ),
                      const SizedBox(height: 10),

                      // Bet Amount Selectors
                      Visibility(
                        visible: isChallengeable &&
                            isOnline, // Show only if challengeable and online
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    EdgeInsets.only(left: 50.0, bottom: 10.0),
                                child: Text(
                                  "Bet Amount",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),

                            // Bet Amount Selectors
                            Wrap(
                              spacing: 100.0,
                              runSpacing: 8.0,
                              children: betAmountOptions.map((option) {
                                bool isSelected =
                                    option['value'] == localBetAmount;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      localBetAmount = option['value'];
                                    });
                                  },
                                  child: Container(
                                    width: tileWidth,
                                    height: tileHeight,

                                    padding: EdgeInsets.all(isSelected ? 6 : 8),
                                    decoration: BoxDecoration(
                                      // color: isSelected ? Colors.blue : Colors.grey[200],
                                      color: isSelected
                                          ? const Color(0xFF272727)
                                          : const Color(0xFF8E8E93),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFF40c759),
                                              width: 2)
                                          : null,
                                    ),
                                    child: Row(
                                      // Use Row for horizontal layout
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        const SizedBox(width: 20),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              right:
                                                  5), // Adjust the padding to control the space
                                          child: Text(
                                            option['value'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              decoration: TextDecoration.none,
                                            ),
                                          ),
                                        ),
                                        Image.asset(option['asset'],
                                            width: 15, height: 15),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),


                      Visibility(
                        visible: isChallengeable &&
                            isOnline, // Show only if challengeable and online
                        child: Column(
                          children: [
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    EdgeInsets.only(left: 50.0, bottom: 10.0),
                                child: Text(
                                  "Timer",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                            // Timer Value Selectors
                            Wrap(
                              spacing: 100.0, // Space between chips
                              runSpacing: 12.0,
                              children: timerOptions.map((option) {
                                bool isSelected = option == localTimerValue;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      localTimerValue = option;
                                    });
                                  },
                                  child: Container(
                                    width: tileWidth,
                                    height: tileHeight,

                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      // color: isSelected ? Colors.blue : Colors.grey[200],
                                      color: isSelected
                                          ? const Color(0xFF272727)
                                          : Color(0xFF8E8E93),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: Color(0xFF40c759),
                                              width: 2)
                                          : null,
                                    ),
                                    child: Text(
                                      '$option min',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        decoration: TextDecoration.none,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Rest of the challenge logic and buttons...
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: isChallengeable
                              ? Colors.green
                              : Colors.deepPurple,
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
                                  } else if (opponentChessCoins <
                                      betAmountInt) {
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
                                    Timer(const Duration(seconds: 30), () {
                                      if (mounted) {
                                        setState(() => challengeButtonCooldown[
                                            opponentId] = true);
                                      }
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
                        child: Text(isOnline
                            ? (isChallengeable ? 'Challenge' : 'Watch Game')
                            : 'Player Offline',style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      // Include the rest of your widgets that make up the modal
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1), // Start from the right
            end: Offset.zero, // End at its final position
          ).animate(animation),
          child: child,
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
        .doc(myUserId)
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
    if (mounted) {
      setState(() {
        // Cancel existing stream subscriptions
        userSubscription.cancel();
        challengeRequestsSubscription.cancel();
        _initiateDataStreams();
      });
    }
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
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: const CameraPosition(
                              target: LatLng(0, 0),
                              zoom: 15.0,
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
                          textAlign: TextAlign.center,
                          // 'Players in $cityName',
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
                                return const Center(
                                    child: Text('No players here.'));
                              }

                              // Populate or update fetchedUserProfiles with snapshot data if not searching
                              if (!_isSearching && snapshot.data!.isNotEmpty) {
                                fetchedUserProfiles = snapshot.data!
                                    .map((doc) =>
                                        doc.data() as Map<String, dynamic>)
                                    .where((user) =>
                                        user['uid'] !=
                                        FirebaseAuth.instance.currentUser?.uid)
                                    .toList();

                                fetchedUserProfiles.sort((a, b) {
                                  // Ensure we have valid booleans for comparison
                                  bool aIsOnline =
                                      a['isOnline'] as bool? ?? false;
                                  bool bIsOnline =
                                      b['isOnline'] as bool? ?? false;

                                  // Convert booleans to integers for comparison (true > false)
                                  int aInt = aIsOnline ? 1 : 0;
                                  int bInt = bIsOnline ? 1 : 0;

                                  // Compare the integer representations
                                  return bInt.compareTo(aInt);
                                });
                              }

                              List<Map<String, dynamic>> usersToShow =
                                  _isSearching
                                      ? _filteredPlayers
                                      : fetchedUserProfiles;

                              // Update the logic to handle an empty list after filtering
                              if (usersToShow.isEmpty) {
                                // This condition checks if the list is empty after filtering
                                return Center(
                                  child: Text(
                                    _isSearching
                                        ? 'oops! there is no players.'
                                        : 'oops! there is no players.',
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600),
                                  ),
                                );
                              }



                              return LayoutBuilder(
                                builder: (BuildContext context, BoxConstraints constraints) {
                                  double screenWidth = MediaQuery.of(context).size.width;
                                  // Calculate the number of columns based on screen width
                                  // int crossAxisCount = constraints.maxWidth < 1000 ?  4: 3;

                                  int crossAxisCount;
                                  if (screenWidth >= 600 && screenWidth < 900) {
                                    crossAxisCount = 2; // For screens between 600px and 799px
                                  } else if (screenWidth >= 900 && screenWidth <= 1024) {
                                    crossAxisCount = 3; // For screens between 800px and 1024px
                                  } else {
                                    crossAxisCount = 4; // For screens above 1024px
                                  }


                                  crossAxisCount = crossAxisCount;
                                  double crossAxisSpacing = screenWidth < 1110 ?2 : 5;
                                  double mainAxisSpacing = screenWidth < 1110 ? 2 :5;
                                  double childAspectRatio = screenWidth < 1110 ? 1 : 1;


                                  return GridView.builder(
                                    key: UniqueKey(),
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: crossAxisSpacing,
                                      mainAxisSpacing: mainAxisSpacing,
                                      childAspectRatio: childAspectRatio,
                                    ),
                                    itemCount: usersToShow.length,
                                    itemBuilder: (context, index) {
                                      var userData = usersToShow[index];
                                      return buildPlayerTile(userData, context);
                                    },
                                  );
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            Colors.white, // Background color for the container
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 1,
                            offset: const Offset(
                                0, 1), // changes position of shadow
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
      onTap: () => _showChallengeModalFromBottom(context, userData),
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


          Container(
            width: 80, // Adjust based on your UI needs
            height: 20, // Adjust based on your UI needs
            child: Align(
              alignment: Alignment.center, // Align the child to the center of the container
              child: Text(
                userData['name'] ?? 'Username',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isOnline ? const Color.fromARGB(255, 12, 6, 6) : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )


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
          String avatarUrl =
              snapshot.data!['avatar'] ?? 'path/to/default/avatar.png';
          String userName = snapshot.data!['name'] ?? 'Unknown User';

          return Padding(
            padding: const EdgeInsets.only(top: 5.0, bottom: 5.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
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
