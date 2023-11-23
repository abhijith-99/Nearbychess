// // challengewaitingscreen.dart

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';

// class ChallengeWaitingScreen extends StatelessWidget {
//   final String currentUserName;
//   final String opponentName;
//   final String challengeRequestId;
//   final String currentUserId;
//   final String opponentId;

//   const ChallengeWaitingScreen({
//     super.key,
//     required this.currentUserName,
//     required this.opponentName,
//     required this.challengeRequestId,
//     required this.currentUserId,
//     required this.opponentId,
//   });


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: PreferredSize(
//         preferredSize: Size.fromHeight(60.0),
//         child: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           title: const Center(
//             child: Text(
//               'Waiting for Response',
//               style: TextStyle(
//                 fontFamily: 'Poppins',
//                 fontSize: 20.0,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//           ),
//         ),
//       ),
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: <Widget>[
//           FutureBuilder<DocumentSnapshot>(
//             future: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(currentUserId)
//                 .get(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.done &&
//                   snapshot.hasData) {
//                 var currentUserData =
//                     snapshot.data!.data() as Map<String, dynamic>;
//                 var currentUserAvatar = currentUserData['avatar'];
//                 return Column(
//                   children: [
//                     CircleAvatar(
//                       radius: 40,
//                       backgroundImage: AssetImage(currentUserAvatar),
//                     ),
//                     SizedBox(height: 10),
//                     Text(
//                       currentUserName,
//                       style: const TextStyle(
//                         fontFamily: 'Poppins',
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 );
//               } else {
//                 return CircularProgressIndicator();
//               }
//             },
//           ),
//           const Center(
//             child: CircularProgressIndicator(),
//           ),
//           FutureBuilder<DocumentSnapshot>(
//             future: FirebaseFirestore.instance
//                 .collection('users')
//                 .doc(opponentId)
//                 .get(),
//             builder: (context, snapshot) {
//               if (snapshot.connectionState == ConnectionState.done &&
//                   snapshot.hasData) {
//                 var opponentUserData =
//                     snapshot.data!.data() as Map<String, dynamic>;
//                 var opponentUserAvatar = opponentUserData['avatar'];
//                 return Column(
//                   children: [
//                     CircleAvatar(
//                       radius: 40,
//                       backgroundImage: AssetImage(opponentUserAvatar),
//                     ),
//                     const SizedBox(height: 10),
//                     Text(
//                       opponentName,
//                       style: const TextStyle(
//                         fontFamily: 'Poppins',
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 );
//               } else {
//                 return CircularProgressIndicator();
//               }
//             },
//           ),
//           Padding(
//             padding: EdgeInsets.all(20),
//             child: ElevatedButton(
//               style: ElevatedButton.styleFrom(
//                 primary: Colors.red, // Set background color to red
//                 shape: RoundedRectangleBorder(
//                   borderRadius:
//                       BorderRadius.circular(15.0), // Set button border radius
//                 ),
//               ),
//               child: Text('Cancel Challenge'),
//               onPressed: () => _cancelChallenge(context),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _cancelChallenge(BuildContext context) {
//     FirebaseFirestore.instance
//         .collection('challengeRequests')
//         .doc(
//             currentUserId) // Update with appropriate document ID for canceling challenge
//         .delete()
//         .then((_) {
//       Navigator.pop(context);
//       print("canceled req");
//     }).catchError((error) => print('Error deleting challenge request: $error'));
//   }
// }















import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChallengeWaitingScreen extends StatelessWidget {
  final String currentUserName;
  final String opponentName;
  final String challengeRequestId;
  final String currentUserId;
  final String opponentId;

  const ChallengeWaitingScreen({
    super.key,
    required this.currentUserName,
    required this.opponentName,
    required this.challengeRequestId,
    required this.currentUserId,
    required this.opponentId,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _cancelChallenge(context);
        return true; // Allow the pop action to occur
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(60.0),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Center(
              child: Text(
                'Waiting for Response',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // ... existing FutureBuilder code for current user and opponent ...
             FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                var currentUserData =
                    snapshot.data!.data() as Map<String, dynamic>;
                var currentUserAvatar = currentUserData['avatar'];
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage(currentUserAvatar),
                    ),
                    SizedBox(height: 10),
                    Text(
                      currentUserName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              } else {
                return CircularProgressIndicator();
              }
            },
          ),
          const Center(
            child: CircularProgressIndicator(),
          ),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(opponentId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasData) {
                var opponentUserData =
                    snapshot.data!.data() as Map<String, dynamic>;
                var opponentUserAvatar = opponentUserData['avatar'];
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage(opponentUserAvatar),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      opponentName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              } else {
                return CircularProgressIndicator();
              }
            },
          ),

            Padding(
              padding: EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                ),
                child: Text('Cancel Challenge'),
                onPressed: () => _cancelChallenge(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelChallenge(BuildContext context) {
    FirebaseFirestore.instance
        .collection('challengeRequests')
        .doc(challengeRequestId) // Use the challengeRequestId for deletion
         .update({'status': 'canceled'}) 
        // .delete()
        .then((_) {
          Navigator.pop(context);
          print("Challenge request canceled");
        })
        .catchError((error) => print('Error deleting challenge request: $error'));
  }
}
























// void listenToMyChallenge(String challengeId) {
//   FirebaseFirestore.instance
//       .collection('challengeRequests')
//       .doc(challengeId)
//       .snapshots()
//       .listen((challengeSnapshot) {
//     if (challengeSnapshot.exists) {
//       var challengeData = challengeSnapshot.data() as Map<String, dynamic>;
//       String status = challengeData['status'];
//       if (status == 'accepted') {
//         // Challenge accepted, navigate to the ChessBoard
//         String gameId = challengeData['gameId'];
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => ChessBoard(gameId: gameId),
//           ),
//         ).then((_) {
//           // User has left the Chessboard, update the inGame status
//           updateInGameState(false);
//         });
//       } else if (status == 'canceled') {
//         // Challenge canceled, navigate to the WaitScreen or handle it as needed
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => ChallengeWaitingScreen(
//               currentUserName: currentUserName,
//               opponentName: opponentName,
//               challengeRequestId: challengeDocRef.id,
//               currentUserId: currentUserId,
//               opponentId: opponentId,
//             ),
//           ),
//         );
//       }
//     }
//   });
// }