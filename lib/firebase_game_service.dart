import 'package:cloud_firestore/cloud_firestore.dart';


class FirebaseGameService {
  // Define the initial board state correctly
  // Example: Using FEN notation for the initial position, or you can use your format
  static final String initialBoardState = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

  static Future<String> createNewGame(String player1UID, String player2UID, String challengeId) async {
    DocumentReference gameRef = await FirebaseFirestore.instance.collection('games').add({
      'player1UID': player1UID,
      'player2UID': player2UID,
      'currentBoardState': initialBoardState, // Use the initial board state
      'currentTurn': player2UID, // Initially, player 1 starts
      'gameStatus': 'ongoing',
      'challengeId': challengeId, // Associate the game with the challenge
    });

    // Update the challenge request with the new game ID
    await FirebaseFirestore.instance.collection('challengeRequests').doc(challengeId).update({
      'gameId': gameRef.id,
    });

    return gameRef.id; // Returns the game ID
  }




// Other Firebase related functions can be added here
}
