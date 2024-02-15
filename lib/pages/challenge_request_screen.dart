import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_game_service.dart';
import '../utils.dart';
import 'ChessBoard.dart';

// Convert this to a StatefulWidget
class ChallengeRequestScreen extends StatefulWidget {
  final String challengerName;
  final String challengerUID; // UID of the challenger
  final String opponentUID; // UID of the opponent (current user)
  final String betAmount; // The bet amount for the game
  final String challengeId; // The challenge request ID
  final String challengerImageUrl; // Image URL for the challenger
  final String localTimerValue; // Timer value for the game

  const ChallengeRequestScreen({
    super.key,
    required this.challengerName,
    required this.challengerUID,
    required this.opponentUID,
    required this.betAmount,
    required this.localTimerValue,
    required this.challengeId,
    required this.challengerImageUrl,
  });

  @override
  _ChallengeRequestScreenState createState() => _ChallengeRequestScreenState();
}

class _ChallengeRequestScreenState extends State<ChallengeRequestScreen> {
  late StreamSubscription<DocumentSnapshot> challengeRequestSubscription;

  @override
  void initState() {
    super.initState();
    challengeRequestSubscription = FirebaseFirestore.instance
        .collection('challengeRequests')
        .doc(widget.challengeId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || snapshot.data()?['status'] == 'cancelled') {
        Navigator.of(context).pop();
        challengeRequestSubscription.cancel();
      }
    });
  }

  @override
  void dispose() {
    challengeRequestSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('Received Timer Value: ${widget.localTimerValue}');
    double screenWidth = MediaQuery.of(context).size.width;
    double dialogWidthFraction = 0.35; // 85% of the screen width
    double dialogWidth = screenWidth * dialogWidthFraction;

    // Define the dialog padding
    double dialogPadding = (screenWidth - dialogWidth) / 2;
    return Dialog(
      // ... rest of the dialog UI code ...
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0)
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: dialogPadding),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, // To make the dialog compact
          children: [
            const Text(
              'Challenge Received',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              backgroundImage:
              NetworkImage(widget.challengerImageUrl), // Use NetworkImage
              radius: 40,
            ),
            const SizedBox(height: 10),
            Text(widget.challengerName, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text(
              'Wants to play for ${widget.betAmount} in ${widget.localTimerValue} minutes',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600, // Added weight for the bet amount
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: MediaQuery.of(context).size.width *
                  0.7, // Adjust the width as needed
              child: ElevatedButton(
                onPressed: () async {
                  // Accept the challenge
                  String newGameId = await FirebaseGameService.createNewGame(
                      widget.challengerUID, widget.opponentUID, widget.challengeId, widget.betAmount, widget.localTimerValue);

                  // Update the challenge request in Firestore
                  await FirebaseFirestore.instance
                      .collection('challengeRequests')
                      .doc(widget.challengeId)
                      .update({
                    'status': 'accepted',
                    'gameId': newGameId, // The ID of the newly created game
                  });

                  // Update 'inGame' status and 'gameId' for both users
                  CollectionReference users =
                  FirebaseFirestore.instance.collection('users');
                  await users
                      .doc(widget.challengerUID)
                      .update({'inGame': true, 'currentGameId': newGameId});
                  await users
                      .doc(widget.opponentUID)
                      .update({'inGame': true, 'currentGameId': newGameId});

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChessBoard(gameId: newGameId, opponentUID: widget.opponentUID,),

                    ),
                  ).then((_) {
                    // User has left the Chessboard, update the inGame status
                    updateInGameState(false);
                  });
                  print("Navigating to ChessBoard with opponent UID from challenge request: ${widget.opponentUID}");

                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        18), // Rounded corners for the button
                  ),
                ),
                child: const Text(
                  'Accept Bet',
                  style: TextStyle(color: Colors.white), // Text color set to white
                ),
              ),
            ),
            const SizedBox(height: 10), // Space between buttons
            SizedBox(
              width: MediaQuery.of(context).size.width *
                  0.7, // Adjust the width as needed
              child: ElevatedButton(
                onPressed: () {
                  // Reject the challenge
                  Navigator.pop(context,
                      false); // Pass false to indicate the challenge is rejected
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // Background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                        18), // Rounded corners for the button
                  ),
                ),
                child: const Text(
                  'Decline',
                  style: TextStyle(color: Colors.white), // Text color set to white
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}







