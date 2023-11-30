import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


// Define the MatchRecord class
class MatchRecord {
  final String opponentUid;
  final String result;
  final DateTime time;
  final double bet; // Adding the bet field

  MatchRecord({required this.opponentUid, required this.result, required this.time, required this.bet});

  factory MatchRecord.fromFirestore(DocumentSnapshot matchDoc) {
    Map<String, dynamic> data = matchDoc.data() as Map<String, dynamic>;
    return MatchRecord(
      opponentUid: data['opponentUid'] ?? '',
      result: data['result'] ?? '',
      time: (data['time'] as Timestamp).toDate(),
      bet: (data['bet'] ?? 0).toDouble(), // Handle the bet field, defaulting to 0 if not present
    );
  }
}

class StatisticText extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatisticText({
    Key? key,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}


class WinDrawLossPainter extends CustomPainter {
  final double wins;
  final double draws;
  final double losses;

  WinDrawLossPainter({required this.wins, required this.draws, required this.losses});

  @override
  void paint(Canvas canvas, Size size) {
    double total = wins + draws + losses;
    double winWidth = (wins / total) * size.width;
    double drawWidth = (draws / total) * size.width;
    double lossWidth = (losses / total) * size.width;

    Paint paint = Paint();
    // Draw wins
    paint.color = Colors.green;
    canvas.drawRect(Rect.fromLTWH(0, 0, winWidth, size.height), paint);

    // Draw draws
    paint.color = Colors.grey;
    canvas.drawRect(Rect.fromLTWH(winWidth, 0, drawWidth, size.height), paint);

    // Draw losses
    paint.color = Colors.red;
    canvas.drawRect(Rect.fromLTWH(winWidth + drawWidth, 0, lossWidth, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class WinDrawLossText extends StatelessWidget {
  final IconData icon;
  final double percent;
  final int count;
  final Color color;

  const WinDrawLossText({super.key, 
    required this.icon,
    required this.percent,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${percent.toStringAsFixed(1)}% ${count.toString()}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}



class UserDetailsPage extends StatefulWidget {
  final String userId;

  const UserDetailsPage({Key? key, required this.userId}) : super(key: key);

  @override
  _UserDetailsPageState createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage> {
  Map<String, dynamic>? userDetails;

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
  }

  Future<void> fetchUserDetails() async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (doc.exists) {
      setState(() {
        userDetails = doc.data();
      });
    }
  }

  Future<List<MatchRecord>> fetchUserMatches(String userId) async {
    var matchesQuerySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('matches')
        .get();

    return matchesQuerySnapshot.docs
        .map((doc) => MatchRecord.fromFirestore(doc))
        .toList();
  }

  Future<Map<String, dynamic>> getOpponentDetails(String opponentUid) async {
    var opponentDoc = await FirebaseFirestore.instance.collection('users').doc(opponentUid).get();
    if (opponentDoc.exists) {
      var data = opponentDoc.data() as Map<String, dynamic>;
      return {
        'name': data['name'] ?? 'Unknown',
        'avatar': data['avatar'] ?? 'assets/avatars/default.png', // Make sure you have a default avatar image at this path
        'location': data['location'] ?? 'Unknown Location', // Fetching the location
      };
    }
    return {
      'name': 'Unknown',
      'avatar': 'assets/avatars/default.png',
      'location': 'Unknown Location',
    };
  }

  Future<Map<String, dynamic>> fetchMatchStatistics(String userId) async {
    var matchesQuerySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('matches')
        .get();

    int totalMatches = matchesQuerySnapshot.docs.length;
    int wins = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'win').length;
    int losses = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'lose').length;
    int draws = matchesQuerySnapshot.docs.where((doc) => doc.data()['result'] == 'draw').length; // Assuming 'draw' is the result for draws

    // Calculate percentages
    double winPercentage = (wins / totalMatches) * 100;
    double lossPercentage = (losses / totalMatches) * 100;
    double drawPercentage = (draws / totalMatches) * 100;

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Details',style: TextStyle(fontSize: 16),)),
      backgroundColor: Colors.grey[200],
      body: userDetails == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align to the start (left)
          children: [
            // Row(
            //   crossAxisAlignment: CrossAxisAlignment.center,
            //   children: [
            //     // User avatar
            //     Container(
            //       width: 80,
            //       height: 80,
            //       decoration: BoxDecoration(
            //         image: DecorationImage(
            //           image: userDetails != null && userDetails!['avatar'] != null
            //               ? AssetImage(userDetails!['avatar']) // Use AssetImage for local assets
            //               : const AssetImage('assets/avatars/default.png'), // A default asset if the avatar URL is not found
            //           fit: BoxFit.cover,
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 10), // Spacing between avatar and name/location
            //     // User name, location, and statistics
            //     Expanded( // Using Expanded to fill the remaining space
            //       child: Column(
            //         crossAxisAlignment: CrossAxisAlignment.start,
            //         children: [
            //           // User name and location
            //           Text(
            //             userDetails!['name'],
            //             style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            //           ),
            //           Row(
            //             mainAxisSize: MainAxisSize.min,
            //             children: [
            //               const Icon(Icons.location_on, color: Colors.grey, size: 12),
            //               const SizedBox(width: 2),
            //               Text(
            //                 userDetails!['location'],
            //                 style: const TextStyle(fontSize: 12, color: Colors.grey),
            //               ),
            //             ],
            //           ),
            //
            //
            //       Positioned(
            //         top: 8.0,
            //         right: 8.0,
            //         child: IconButton(
            //           icon: Icon(Icons.chat_bubble_outline),
            //           color: Colors.green,
            //           onPressed: () {
            //             // Handle chat icon press action
            //           },
            //         ),
            //       ),
            //
            //
            //         ],
            //       ),
            //     ),
            //   ],
            // ),



            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // User avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: userDetails != null && userDetails!['avatar'] != null
                          ? AssetImage(userDetails!['avatar']) // Use AssetImage for local assets
                          : const AssetImage('assets/avatars/default.png'), // A default asset if the avatar URL is not found
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Spacing between avatar and name/location
                // User name and location
                Expanded( // Using Expanded to fill the remaining space
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userDetails!['name'],
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            userDetails!['location'],
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Chat icon button
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  color: Colors.blue,
                  onPressed: () {
                    // Handle chat icon press action
                  },
                ),
              ],
            ),



            const SizedBox(height: 10), // Spacing between user details and match history

            FutureBuilder<Map<String, dynamic>>(
              future: fetchMatchStatistics(widget.userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                var stats = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Games Played :',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${stats['totalMatches']}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

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


                    const SizedBox(height: 5),

                    // Container to create the horizontal bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Adds horizontal padding to the container
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

            const SizedBox(height: 10),
            Divider(
              color: Colors.grey[300], // Choose a darker shade for the divider
              thickness: 1.0, // Set the thickness of the divider
              endIndent: 0, // Optional: Adjust this for indentation from the end side
              indent: 0, // Optional: Adjust this for indentation from the start side
            ),
            // Separator line
            Text(
              'Match History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[800]), // Dark grey color
            ),
            FutureBuilder<List<MatchRecord>>(
              future: fetchUserMatches(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text("Error: ${snapshot.error}");
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No match history available');
                }
                return ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final match = snapshot.data![index];
                    return FutureBuilder<Map<String, dynamic>>(
                      future: getOpponentDetails(match.opponentUid),
                      builder: (context, opponentSnapshot) {
                        if (opponentSnapshot.connectionState == ConnectionState.waiting) {
                          return const Card(child: ListTile(title: Text('Loading...')));
                        }
                        if (!opponentSnapshot.hasData) {
                          return const Card(child: ListTile(title: Text('Opponent not found')));
                        }
                        var opponentData = opponentSnapshot.data!;
                        String betDisplay;
                        Color betColor;

                        switch (match.result) {
                          case 'win':
                            betDisplay = '+ ₹${match.bet.toStringAsFixed(2)}';
                            betColor = Colors.green;
                            break;
                          case 'lose':
                            betDisplay = '- ₹${match.bet.toStringAsFixed(2)}';
                            betColor = Colors.red;
                            break;
                          default: // For 'draw' or any other result
                            betDisplay = '₹0.00';
                            betColor = Colors.grey;
                            break;
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                          elevation: 4.0, // Adds a subtle shadow
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15.0), // Rounded corners
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                            leading: CircleAvatar(
                              backgroundImage: AssetImage(opponentData['avatar']),
                              radius: 20, // Adjust the size of the avatar
                            ),
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center, // Vertically center the column contents
                              children: [
                                Text(opponentData['name'], style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4.0),
                                Text(opponentData['location'], style: const TextStyle(fontSize: 10.0, color: Colors.grey)),
                                const SizedBox(height: 4.0),
                                Text(DateFormat('dd/MM/yyyy HH:mm').format(match.time), style: const TextStyle(fontSize: 8.0, color: Colors.grey)),
                              ],
                            ),
                            trailing: FittedBox(
                              fit: BoxFit.fill,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                    decoration: BoxDecoration(
                                      color: match.result == 'win' ? Colors.green : match.result == 'lose' ? Colors.red : Colors.grey,
                                      borderRadius: BorderRadius.circular(20.0),
                                    ),
                                    child: Text(match.result.toUpperCase(), style: const TextStyle(color: Colors.white)),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    match.result == 'win' ? '+ ₹${match.bet.toStringAsFixed(2)}' : match.result == 'lose' ? '- ₹${match.bet.toStringAsFixed(2)}' : '₹0.00',
                                    style: TextStyle(
                                        color: match.result == 'win' ? Colors.green : match.result == 'lose' ? Colors.red : Colors.grey,
                                        fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );

                      },
                    );
                  },
                );
              },
            ),

          ],
        ),
      ),
    );
  }
}
