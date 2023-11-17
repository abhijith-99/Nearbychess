import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MatchRecord {
  final String opponentName;
  final String result; // Example fields, adjust according to your data structure

  MatchRecord({required this.opponentName, required this.result});

  // If you're fetching data from Firestore, you might want a factory constructor to create a MatchRecord from a DocumentSnapshot
  factory MatchRecord.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return MatchRecord(
      opponentName: data['opponentName'], // Adjust field names as per your Firestore structure
      result: data['result'],
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
        userDetails = doc.data() as Map<String, dynamic>?;
        String avatarUrl = userDetails?['avatar'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Details')),
      body: userDetails == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 100,
              backgroundImage: AssetImage(userDetails!['avatar']), // Assuming 'avatar' is a URL
              backgroundColor: Colors.transparent,
            ),
            SizedBox(height: 20),
            Text(
              userDetails!['name'],
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Match History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            // Placeholder for match history
            FutureBuilder<List<MatchRecord>>(
              future: fetchMatchHistory(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                }
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      MatchRecord match = snapshot.data![index];
                      return ListTile(
                        title: Text(match.opponentName),
                        subtitle: Text('Result: ${match.result}'),
                        // Additional match details here
                      );
                    },
                  );
                } else {
                  return Text('No match history available');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<MatchRecord>> fetchMatchHistory(String opponentId) async {
    List<MatchRecord> matches = [];
    // Add your Firestore query to fetch match history
    // Example:
    // var querySnapshot = await FirebaseFirestore.instance.collection('matches').where('opponentId', isEqualTo: opponentId).get();
    // for (var doc in querySnapshot.docs) {
    //   matches.add(MatchRecord.fromFirestore(doc));
    // }
    return matches;
  }



}
