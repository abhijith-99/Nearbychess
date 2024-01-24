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
    int losses = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'lose').length;
    int draws = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'draw').length;

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
    };
  }
  // Include the fetchMatchStatistics method (adapted from UserDetailsPage)





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: signOut,
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
                          icon: const Icon(Icons.edit),
                          onPressed: showAvatarSelection,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userData['name'] ?? 'Username',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    // User Statistics
                    FutureBuilder<Map<String, dynamic>>(
                      future: fetchMatchStatistics(FirebaseAuth.instance.currentUser!.uid),
                      builder: (context, statsSnapshot) {
                        if (!statsSnapshot.hasData) return const CircularProgressIndicator();
                        var stats = statsSnapshot.data!;
                        return Column(
                          children: [
                            // Games Played
                            Text(
                              'Games Played: ${stats['totalMatches']}',
                              style: TextStyle(
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
                                  label: '${stats['losses']} Lost',
                                  value: stats['lossPercentage'].toStringAsFixed(1) + '%',
                                  color: Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),

                    // Match History Cards
                    FutureBuilder<List<MatchRecord>>(
                      future: fetchUserMatches(FirebaseAuth.instance.currentUser!.uid),
                      builder: (context, matchSnapshot) {
                        if (!matchSnapshot.hasData) return const CircularProgressIndicator();
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
                                    return ListTile(
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
                                    trailing: Text(
                                      match.result,
                                      style: TextStyle(
                                        color: match.result == 'win' ? Colors.green :
                                        match.result == 'lose' ? Colors.red :
                                        Colors.grey,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            } else {
              return const Text('No user data available.');
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shareReferralCode,
        label: const Text('Share And Win 100'),
        icon: const Icon(Icons.share),
        backgroundColor: Colors.blue,
      ),
    );
  }



  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushNamedAndRemoveUntil('/login_register', (Route<dynamic> route) => false);
    } catch (error) {
      print(error.toString());
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

  void showAvatarSelection() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                padding: const EdgeInsets.all(10.0),
                child: Image.network(avatarImages[index]),
              ),
            );
          },
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


  Future<void> shareReferralCode() async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      var userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        var userData = userDoc.data() as Map<String, dynamic>;
        String referralCode = userData['referralCode'];
        String shareMessage = "Join me on the ultimate chess battleground! Use my code $referralCode to start your journey with extra 100 NBC rewards. Download now: https://example.com/download";
        Share.share(shareMessage);
        print("Referral Code: $referralCode");
        print("Share Message: $shareMessage");
      }
    } catch (error) {
      print('Failed to share: $error');
    }
  }
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