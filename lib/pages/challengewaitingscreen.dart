// import 'dart:async';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
//
// class ChallengeWaitingScreen extends StatelessWidget {
//   final String currentUserName;
//   final String opponentName;
//   final String challengeRequestId;
//   final String currentUserId;
//   final String opponentId;
//
//   const ChallengeWaitingScreen({
//     super.key,
//     required this.currentUserName,
//     required this.opponentName,
//     required this.challengeRequestId,
//     required this.currentUserId,
//     required this.opponentId,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: PreferredSize(
//           preferredSize: const Size.fromHeight(60.0),
//           child: AppBar(
//             backgroundColor: Colors.transparent,
//             elevation: 0,
//             title: const Center(
//               child: Text(
//                 'Waiting for Response',
//                 style: TextStyle(
//                   fontFamily: 'Poppins',
//                   fontSize: 20.0,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         body: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: <Widget>[
//             // ... existing FutureBuilder code for current user and opponent ...
//              FutureBuilder<DocumentSnapshot>(
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
//                     const SizedBox(height: 10),
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
//                 return const CircularProgressIndicator();
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
//                 return const CircularProgressIndicator();
//               }
//             },
//           ),
//
//             Padding(
//               padding: const EdgeInsets.all(20),
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.red,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(15.0),
//                   ),
//                 ),
//                 child: const Text('Cancel Challenge'),
//                 onPressed: () => _cancelChallenge(context),
//               ),
//             ),
//           ],
//         ),
//       );
//   }
//
//   void _cancelChallenge(BuildContext context) {
//     FirebaseFirestore.instance
//         .collection('challengeRequests')
//         .doc(challengeRequestId) // Use the challengeRequestId for deletion
//          .update({'status': 'canceled'})
//         // .delete()
//         .then((_) {
//           Navigator.pop(context);
//           print("Challenge request canceled");
//         })
//         // ignore: invalid_return_type_for_catch_error
//         .catchError((error) => print('Error deleting challenge request: $error'));
//   }
// }
//
//
//
//



import 'dart:async';

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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          'Waiting for Response',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 25.0,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Spacer(),
            _buildUserAvatar(currentUserId, currentUserName),
            SizedBox(height: 30),
            const CircularProgressIndicator(),
            SizedBox(height: 30),
            _buildUserAvatar(opponentId, opponentName),
            Spacer(),
            _buildCancelButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String userId, String userName) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          var userAvatar = userData['avatar'];

          return Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: AssetImage(userAvatar),
              ),
              SizedBox(height: 10),
              Text(
                userName,
                style: TextStyle(
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
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
        ),
        child: Text(
          'Cancel Challenge',
          style: TextStyle(fontSize: 18,
          color: Colors.white),
        ),
        onPressed: () => _cancelChallenge(context),
      ),
    );
  }

  void _cancelChallenge(BuildContext context) {
    FirebaseFirestore.instance
        .collection('challengeRequests')
        .doc(challengeRequestId)
        .update({'status': 'canceled'})
        .then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Challenge request canceled")),
      );
    })
        .catchError((error) => print('Error deleting challenge request: $error'));
  }
}
