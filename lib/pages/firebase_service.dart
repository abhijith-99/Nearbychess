import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// FirebaseServices: A class to encapsulate all Firebase-related operations for a chess game.
class FirebaseServices {
  final String gameId; // Unique identifier for each game.
  FirebaseServices(this.gameId);
  double betAmount = 0.0; // Variable to store the bet amount.


  // Fetches the bet amount for the current game from Firebase Realtime Database.
  Future<double> fetchBetAmount() async {
    try {
      // Reference to the specific game in the database.
      DatabaseReference ref = FirebaseDatabase.instance.ref('games/$gameId');
      var snapshot = await ref.get(); // Get the snapshot of the data.
      if (snapshot.exists) {
        var gameData = snapshot.value as Map<dynamic, dynamic>;
        // Extract bet amount as a string, defaulting to '0' if not found.
        String betAmountString = gameData['betAmount']?.toString() ?? '0';
        // Parse the string to a double and return it.
        return double.tryParse(betAmountString.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0.0;
      }
    } catch (e) {
      print('Error fetching bet amount: $e'); // Log any errors encountered.
      return 0.0;
    }
    return 0.0;
  }


  // Updates the match history for both players in Firestore.
  Future<void> updateMatchHistory({
    required String userId1, // UID of the first player.
    required String userId2, // UID of the second player.
    required String result, // Result of the match ('win', 'lose', or 'draw').
    required double bet, // Bet amount for the match.
  }) async {
    bet = bet; // Assign the bet amount to the local variable.
    print("betamount from updatematch history $bet");
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    // Generate a new document ID for the match.
    String matchId = FirebaseFirestore.instance
        .collection('matches')
        .doc()
        .id;

    // Create a match record for user1.
    Map<String, dynamic> matchForUser1 = {
      'opponentUid': userId2,
      'result': result,
      'time': Timestamp.fromDate(DateTime.now()), // Current time as timestamp.
      'bet': bet, // Bet amount for the match.
    };
    // Save the match record for user1.
    await users.doc(userId1).collection('matches').doc(matchId).set(matchForUser1);

    // Create and save the match record for user2 (inverse result of user1's).
    Map<String, dynamic> matchForUser2 = {
      'opponentUid': userId1,
      'result': result == 'win' ? 'loss' : (result == 'loss' ? 'win' : 'draw'),
      'time': matchForUser1['time'],
      'bet': bet,
    };
    await users.doc(userId2).collection('matches').doc(matchId).set(matchForUser2);
  }

  // Updates the chess coins balance of a user in Firestore based on the game outcome.
  Future<void> updateChessCoinsBalance(
      String userId, double betAmount, bool didWin) async {
    print("inside updatechesscoins");
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) {
        throw Exception("User does not exist!");
      }

      var userData = snapshot.data() as Map<String, dynamic>;
      int currentBalance = userData['chessCoins'] ?? 0;

      // Calculate the new balance based on the game result.
      int updatedBalance = didWin
          ? (currentBalance + betAmount).round()
          : (currentBalance - betAmount).round();

      // Update the user's balance in Firestore.
      transaction.update(userRef, {'chessCoins': updatedBalance});
    }).catchError((error) {
      print("Error updating balance: $error");
    });
  }

  // Updates the list of captured pieces for both players in the Realtime Database.
  void updateCapturedPiecesInRealTimeDatabase(
      List<String> capturedPiecesWhite, List<String> capturedPiecesBlack) {
    FirebaseDatabase.instance.ref('games/$gameId').update({
      'capturedPiecesBlack': capturedPiecesBlack,
      'capturedPiecesWhite': capturedPiecesWhite,
    }).catchError((error) {
      print("Error updating captured pieces: $error");
    });
  }



  // Updates the last move made in the game in the Realtime Database.
  void updateLastMoveInRealTimeDatabase(String fromSquare, String toSquare) {
    FirebaseDatabase.instance.ref('games/$gameId').update({
      'lastMoveFrom': fromSquare,
      'lastMoveTo': toSquare,
    });
  }

  // Updates the game's Portable Game Notation (PGN) in the Realtime Database.
  void updatePGNNotationInRealTimeDatabase(String pgnNotation) {
    FirebaseDatabase.instance.ref('games/$gameId').update({
      'pgnNotation': pgnNotation,
    });
  }





  // void updateUserWins(String userId) {
  //   print("inside update win");
  //   final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
  //
  //   userRef.get().then((DocumentSnapshot documentSnapshot) {
  //     if (documentSnapshot.exists && documentSnapshot.data() is Map) {
  //       Map<String, dynamic> userData = documentSnapshot.data() as Map<String, dynamic>;
  //       int currentWins = userData['wins'] ?? 0;
  //       userRef.update({'wins': currentWins + 1});
  //     }
  //   });
  // }



}

