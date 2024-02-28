

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
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
            // CircularProgressIndicator(),
            CupertinoActivityIndicator(
              radius: 15, // The size of the activity indicator.
            ),

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
                backgroundImage: NetworkImage(userAvatar),
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
          return Container();
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
        .update({'status': 'cancelled'})
        .then((_) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Challenge request canceled")),
      );
    })
        .catchError((error) => print('Error deleting challenge request: $error'));
  }
}
