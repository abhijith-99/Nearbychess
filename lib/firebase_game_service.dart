import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseGameService {
  static const String initialBoardState =
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  static Future<String> createNewGame(String player1UID, String player2UID,
      String challengeId, String betAmount, int localTimerValue) async {
    DatabaseReference gameRef =
        FirebaseDatabase.instance.ref().child('games').push();

    await gameRef.set({
      'player1UID': player1UID,
      'player2UID': player2UID,
      'currentBoardState': initialBoardState,
      'currentTurn': player2UID, // or player2UID depending on your game logic
      'gameStatus': 'ongoing',
      'challengeId': challengeId,
      'betAmount': betAmount,
      localTimerValue: localTimerValue,
    });

    // If you still need to update Firestore with the Realtime Database key
    await FirebaseFirestore.instance
        .collection('challengeRequests')
        .doc(challengeId)
        .update({
      'gameId': gameRef.key, // Use the Realtime Database key
    });

    return gameRef.key ?? ''; // Return the key of the new game entry
  }

// Other Firebase related functions...
}
