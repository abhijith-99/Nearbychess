import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_game_service.dart';
import '../utils.dart';
import 'ChessBoard.dart';

class ChallengeRequestScreen extends StatelessWidget {
  final String challengerName;
  final String challengerUID; // UID of the challenger
  final String opponentUID; // UID of the opponent (current user)
  final String betAmount; // The bet amount for the game
  final String challengeId; // The challenge request ID

  const ChallengeRequestScreen({super.key,
    required this.challengerName,
    required this.challengerUID,
    required this.opponentUID,
    required this.betAmount,
    required this.challengeId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), // Makes dialog rounded
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const CircleAvatar(
              // Placeholder for now
              backgroundImage: AssetImage('assets/battle.png'),
              radius: 40,
            ),
            const SizedBox(height: 10),
            Text(challengerName, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Text(
              'Wants to play for $betAmount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600, // Added weight for the bet amount
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7, // Adjust the width as needed
              child: ElevatedButton(
                onPressed: () async {
                  // Accept the challenge
                  String newGameId = await FirebaseGameService.createNewGame(
                      challengerUID, opponentUID, challengeId);

                  // Update the challenge request in Firestore
                  await FirebaseFirestore.instance.collection('challengeRequests').doc(challengeId).update({
                    'status': 'accepted',
                    'gameId': newGameId, // The ID of the newly created game
                  });

                  // Update 'inGame' status and 'gameId' for both users
                  CollectionReference users = FirebaseFirestore.instance.collection('users');
                  await users.doc(challengerUID).update({'inGame': true, 'currentGameId': newGameId});
                  await users.doc(opponentUID).update({'inGame': true, 'currentGameId': newGameId});

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChessBoard(gameId: newGameId),
                    ),
                  ).then((_) {
                    // User has left the Chessboard, update the inGame status
                    updateInGameState(false);
                  });
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.green, // Background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18), // Rounded corners for the button
                  ),
                ),
                child: const Text('Accept Bet'),
              ),
            ),
            const SizedBox(height: 10), // Space between buttons
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.7, // Adjust the width as needed
              child: ElevatedButton(
                onPressed: () {
                  // Reject the challenge
                  Navigator.pop(context, false); // Pass false to indicate the challenge is rejected
                },
                style: ElevatedButton.styleFrom(
                  primary: Colors.red, // Background color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18), // Rounded corners for the button
                  ),
                ),
                child: const Text('Decline'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
