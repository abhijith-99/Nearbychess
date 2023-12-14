import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/material.dart';
import 'package:mychessapp/pages/userhome.dart';

import '../utils.dart';

class ChessBoard extends StatefulWidget {
  final String gameId;

  ChessBoard({Key? key, required this.gameId}) : super(key: key);

  @override
  _ChessBoardState createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  bool isBoardFlipped = false;
  late chess.Chess game;
  late final StreamSubscription<DatabaseEvent> gameSubscription;
  Timer? _timer;
  int _whiteTimeRemaining = 600; // 10 minutes in seconds
  int _blackTimeRemaining = 600; // 10 minutes in seconds
  List<String> whiteCapturedPieces = [];
  List<String> blackCapturedPieces = [];
  String? lastMoveFrom;
  String? lastMoveTo;
  String? selectedSquare;
  List<String> legalMovesForSelected = [];
  String currentTurnUID = '';
  String currentUserUID = '';
  String player1UID = '';
  String player2UID = '';
  String player1AvatarUrl = ''; // Default or placeholder URL
  String player2AvatarUrl = ''; // Default or placeholder URL
  String pgnNotation = ""; // Variable to store PGN notation
  String player1Name = ''; // Add this
  String player2Name = ''; // Add this
  bool _blackTimerActive = false;
  bool _whiteTimerActive = false;
  double betAmount = 0.0; // Variable to store the bet amount
  bool isGameEnded = false;
  int moveNumber=0;

  String getPieceAsset(chess.PieceType type, chess.Color? color) {
    String assetPath;
    String pieceColor = color == chess.Color.WHITE ? 'white' : 'black';
    switch (type) {
      case chess.PieceType.PAWN:
        assetPath = 'assets/chess_pieces/$pieceColor/pawn.png';
        break;
      case chess.PieceType.KNIGHT:
        assetPath = 'assets/chess_pieces/$pieceColor/knight.png';
        break;
      case chess.PieceType.BISHOP:
        assetPath = 'assets/chess_pieces/$pieceColor/bishop.png';
        break;
      case chess.PieceType.ROOK:
        assetPath = 'assets/chess_pieces/$pieceColor/rook.png';
        break;
      case chess.PieceType.QUEEN:
        assetPath = 'assets/chess_pieces/$pieceColor/queen.png';
        break;
      case chess.PieceType.KING:
        assetPath = 'assets/chess_pieces/$pieceColor/king.png';
        break;
      default:
        assetPath = ''; // Return an empty string for any other cases (shouldn't occur)
    }
    return assetPath.isNotEmpty ? assetPath : 'assets/default.png';
  }

  Future<double> fetchBetAmount(String gameId) async {
    try {

      // Fetch the game document from Firebase Realtime Database
      DatabaseReference ref = FirebaseDatabase.instance.ref('games/$gameId');
      var snapshot = await ref.get();

      if (snapshot.exists) {
        var gameData = snapshot.value as Map<dynamic, dynamic>;
        String betAmountString = gameData['betAmount']?.toString() ?? '0';


        // Extract the numeric part of the betAmountString
        var betAmount = double.tryParse(betAmountString.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        return betAmount;
      }
    } catch (e) {
      print('Error fetching bet amount: $e');
      return 0.0; // Return default value in case of error
    }
    return 0.0; // Return default value if document does not exist

  }


  Future<void> updateMatchHistory({
    required String userId1,
    required String userId2,
    required String result, // 'win', 'lose', or 'draw'
    required double bet,
  }) async {

    bet = betAmount;

    // Reference to the Firestore collection
    CollectionReference users = FirebaseFirestore.instance.collection('users');
    String matchId = FirebaseFirestore.instance.collection('matches').doc().id; // Generate a new document ID for the match

    // Create a match record for user1
    Map<String, dynamic> matchForUser1 = {
      'opponentUid': userId2,
      'result': result,
      'time': Timestamp.fromDate(DateTime.now()), // Current time as timestamp
      'bet': bet,
    };

    // For user1, if they won, result is 'win', if they lost, result is 'lose', otherwise 'draw'
    await users.doc(userId1).collection('matches').doc(matchId).set(matchForUser1);

    // Create a match record for user2, which will be the inverse of user1's result
    Map<String, dynamic> matchForUser2 = {
      'opponentUid': userId1,
      'result': result == 'win' ? 'lose' : (result == 'lose' ? 'win' : 'draw'), // Inverse the result for the opponent
      'time': matchForUser1['time'],
      'bet': bet,
    };

    // For user2, if user1 won, result is 'lose', if user1 lost, result is 'win', otherwise 'draw'
    await users.doc(userId2).collection('matches').doc(matchId).set(matchForUser2);
  }


  // Widget to display a chess piece
  Widget displayPiece(chess.Piece? piece) {
    if (piece != null) {
      return Image.asset(getPieceAsset(piece.type, piece.color));
    }
    return Container(); // Return an empty container if no piece is present
  }

  String _getRowLabel(int index) {
    // Label the rows from 1 to 8 starting from the bottom
    return '${1 + index}';
  }

  String _getColumnLabel(int index) {
    return String.fromCharCode(97 + index); // ASCII 'a' starts at 97
  }

  void updateCapturedPiecesInRealTimeDatabase() {
    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'whiteCapturedPieces': whiteCapturedPieces,
      'blackCapturedPieces': blackCapturedPieces,
    });
  }


  void updateLastMoveInRealTimeDatabase(String fromSquare, String toSquare) {
    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'lastMoveFrom': fromSquare,
      'lastMoveTo': toSquare,
    });
  }


  void updatePGNNotationInRealTimeDatabase(String pgnNotation) {
    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'pgnNotation': pgnNotation,
    });
  }



  void updatePGNNotation(chess.PieceType pieceType, String from, String to, bool isCapture) {

    // final piece = game.get(from);
    String pieceNotation = '';


    // Check for castling
    if (pieceType == chess.PieceType.KING && (from == 'e1' && (to == 'g1' || to == 'c1') || from == 'e8' && (to == 'g8' || to == 'c8'))) {
      pgnNotation += (to == 'g1' || to == 'g8') ? 'O-O ' : 'O-O-O ';
      return;
    }

    print(pieceNotation);
    // Determine the piece type and set its notation
    switch (pieceType) {
      case chess.PieceType.KNIGHT:
        pieceNotation = 'N';
        break;
      case chess.PieceType.BISHOP:
        pieceNotation = 'B';
        break;
      case chess.PieceType.ROOK:
        pieceNotation = 'R';
        break;
      case chess.PieceType.QUEEN:
        pieceNotation = 'Q';
        break;
      case chess.PieceType.KING:
        pieceNotation = 'K';
        break;
      default:
        pieceNotation = ''; // Pawn moves do not use a piece notation
        break;
    }

    // Format the move string
    String move = pieceNotation + (isCapture ? 'x' : '') + to;

    // Append '+' for check and '#' for checkmate
    if (game.in_checkmate) {  // Changed to property
      move += '#';
    } else if (game.in_check) {  // Changed to property
      move += '+';
    }


    // Append move number for white's move
    if (game.turn == chess.Color.BLACK) { // Check if the next turn is black's
      moveNumber = moveNumber + 1;
      pgnNotation += '$moveNumber. ';
    }

    pgnNotation += '$move ';

    updatePGNNotationInRealTimeDatabase(pgnNotation);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    isGameEnded = false;
    game = chess.Chess();
    currentUserUID = FirebaseAuth.instance.currentUser?.uid ?? '';
    var gameData;
    fetchInitialTimerValue();

    fetchBetAmount(widget.gameId).then((value) {
      setState(() {
        betAmount = value;
      });
    });

    gameSubscription = FirebaseDatabase.instance
        .ref('games/${widget.gameId}')
        .onValue
        .listen((event) async {
      final data = event.snapshot.value;
      if (data is Map) {
        // Convert to Map<String, dynamic> with more flexibility
        gameData = data.map((key, value) => MapEntry(key.toString(), value));

      }

      var newFen = gameData['currentBoardState'];
      currentTurnUID = gameData['currentTurn'];
      player1UID = gameData['player1UID'] ?? '';
      player2UID = gameData['player2UID'] ?? '';
      bool isCurrentUserBlack = currentUserUID == player1UID;
      var newPgnNotation = gameData['pgnNotation'] ?? "";

      if (gameData['gameStatus'] != null && gameData['gameStatus'] != 'ongoing') {
        _showGameOverDialog(gameData['gameStatus']);
      }

      if (data is Map && data['drawOffer'] != null && data['drawOffer'] != currentUserUID) {
        // A draw has been offered by the opponent
        _showDrawOfferDialog();
      }

      setState(() {
        game.load(newFen);
        isBoardFlipped = isCurrentUserBlack;
        whiteCapturedPieces = List<String>.from(gameData['whiteCapturedPieces'] ?? []);
        blackCapturedPieces = List<String>.from(gameData['blackCapturedPieces'] ?? []);
        pgnNotation = newPgnNotation;

        // Reset selectedSquare if it's now the current user's turn
        if (currentTurnUID == currentUserUID) {
          selectedSquare = null;
        }

      });
    });

  }


  void _showDrawOfferDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade300, // A color reminiscent of a chessboard
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black, width: 2), // Black border to mimic chessboard lines
        ),
        title: const Text('Draw Offered', style: TextStyle(color: Colors.white)),
        content: const Text('Your opponent has offered a draw. Do you agree to a draw?', style: TextStyle(color: Colors.white)),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black,
              backgroundColor: Colors.white,
            ),
            onPressed: () {
              // The opponent has agreed to a draw
              _updateGameStatus('draw');
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Accept Draw'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.white,
              backgroundColor: Colors.black,
            ),
            onPressed: () {
              // The opponent has declined the draw
              DatabaseReference gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');
              gameRef.update({'drawOffer': null}); // Clear the draw offer
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Decline Draw'),
          ),
        ],
      ),
    );
  }


  void updateMatchHistoryIfNeeded({
    required String userId1,
    required String userId2,
    required String result,
    required double bet,
  }) {
    if (!isGameEnded) {
      isGameEnded = true; // Set the flag to indicate the game has ended

      // Determine the winner and loser based on the result
      String winnerUID = (result == 'win') ? userId1 : userId2;
      String loserUID = (winnerUID == userId1) ? userId2 : userId1;

      updateMatchHistory(
        userId1: userId1,
        userId2: userId2,
        result: result,
        bet: bet,
      );
      if (result != 'draw') {
        updateChessCoinsBalance(winnerUID, bet, true); // Winner
        updateChessCoinsBalance(loserUID, bet, false); // Loser
      }
    }
  }

  Future<void> updateChessCoinsBalance(String userId, double betAmount, bool didWin) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception("User does not exist!");
      }

      // Cast the data to Map<String, dynamic> before accessing its properties
      var userData = snapshot.data() as Map<String, dynamic>;
      int currentBalance = userData['chessCoins'] ?? 0;

      // Compute the updated balance
      int updatedBalance = didWin ? (currentBalance + betAmount).round() : (currentBalance - betAmount).round();

      transaction.update(userRef, {'chessCoins': updatedBalance});
    }).catchError((error) {
      print("Error updating balance: $error");
      // Handle the error appropriately
    });
  }



  void _updateGameStatus(String newStatus) {
      DatabaseReference gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');
      gameRef.update({
        'gameStatus': newStatus,
        'drawOffer': null, // Clear any existing draw offers
      });
      if (newStatus == 'draw') {
        updateMatchHistoryIfNeeded(userId1: player1UID, userId2: player2UID, result: newStatus, bet: 0.0,);
      }
    }

  void fetchInitialTimerValue() async {
    DatabaseReference timerRef = FirebaseDatabase.instance.ref('games/${widget.gameId}/localTimerValue'); // Updated path
    DatabaseEvent timerEvent = await timerRef.once();
    if (timerEvent.snapshot.exists) {
      String timerValue = timerEvent.snapshot.value.toString();
      try {
        int initialTimer = int.parse(timerValue);
        setState(() {
          _whiteTimeRemaining = initialTimer * 60; // Convert to seconds
          _blackTimeRemaining = initialTimer * 60; // Convert to seconds
        });
      } catch (e) {
        print('Error parsing timer value: $e');
      }
    }
  }


  void _showGameOverDialog(String statusMessage) {
    _timer?.cancel();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade300, // A color reminiscent of a chessboard
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black, width: 2), // Black border to mimic chessboard lines
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white), // Chess-related icon
            SizedBox(width: 8),
            Text(
              'Game Over',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Center(
                child: Text(
                  statusMessage,
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                primary: Colors.white,
              ),
              onPressed: () {

                updateInGameState(false);

                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const UserHomePage(),
                  ),
                );
              },
              child: const Text('Return to Home'),
            ),
          ),
        ],
      ),
    );
  }

  void updateGameStatus(String statusMessage) {

    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'gameStatus': statusMessage,
    });
  }



  void _startTimer() {
    const oneSec = Duration(seconds: 1);
    _timer = Timer.periodic(oneSec, (timer) {
      setState(() {
        if (game.turn == chess.Color.WHITE) {
          if (_whiteTimeRemaining > 0) {
            _whiteTimeRemaining--;
          } else {
            timer.cancel();
            _handleTimeout(chess.Color.WHITE);
          }
          _whiteTimerActive = true;
          _blackTimerActive = false;
        } else {
          if (_blackTimeRemaining > 0) {
            _blackTimeRemaining--;
          } else {
            timer.cancel();
            _handleTimeout(chess.Color.BLACK);
          }
          _blackTimerActive = true;
          _whiteTimerActive = false;
        }
      });
    });
  }


  void _handleTimeout(chess.Color color) {
    // Logic for handling timer timeout
    String statusMessage;

    String winnerUID, loserUID;

    // Update status message based on which player's timer ran out
    if (color == chess.Color.WHITE) {
      // If white's time runs out, black wins
      winnerUID = player1UID; // player1 is black
      loserUID = player2UID; // player2 is white
      statusMessage = "$player1Name wins by timeout!";
    } else {
      // If black's time runs out, white wins
      winnerUID = player2UID; // player2 is white
      loserUID = player1UID; // player1 is black
      statusMessage = "$player2Name wins by timeout!";
    }

    updateMatchHistoryIfNeeded(
      userId1: winnerUID,
      userId2: loserUID,
      result: 'win', // The winner's perspective
      bet: betAmount, // Replace with actual bet amount if applicable
    );

    // Update the game status in Firebase
    updateGameStatus(statusMessage);
  }




  void _switchTimer() {
    // Switch the timer to the other player
    _timer?.cancel(); // Cancel the previous timer
    _startTimer(); // Start a new timer for the next player
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
    gameSubscription.cancel();
  }

  Future<void> fetchPlayerDetails() async {

    var player1Doc = await FirebaseFirestore.instance.collection('users').doc(player1UID).get();
    if (player1Doc.exists) {
      var player1Data = player1Doc.data();
      setState(() {
        player1Name = player1Data?['name'] ?? 'Unknown';
        player1AvatarUrl = player1Data?['avatar'] ?? 'assets/default_avatar.png';
      });
    }

    // Fetch details for player2
    var player2Doc = await FirebaseFirestore.instance.collection('users').doc(player2UID).get();
    if (player2Doc.exists) {
      var player2Data = player2Doc.data();
      setState(() {
        player2Name = player2Data?['name'] ?? 'Unknown';
        player2AvatarUrl = player2Data?['avatar'] ?? 'assets/default_avatar.png';
      });
    }
  }




  Widget _buildPlayerArea(List<String> capturedPieces, bool isTop, String playerName) {
    fetchPlayerDetails();
    fetchBetAmount(widget.gameId).then((value) {
      setState(() {
        betAmount = value;
      });
    });
    String avatarUrl = isTop ? player1AvatarUrl : player2AvatarUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Container(
        color: Colors.transparent,
        height: 50, // Adjust the height as needed
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Avatar container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(avatarUrl),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.all(Radius.circular(5)),
                border: Border.all(color: Colors.black, width: 1.0),
              ),
            ),
            SizedBox(width: 8),
            // Column for player name and captured pieces
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Player name text
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      playerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        fontSize: 14, // Adjust font size as needed
                      ),
                    ),
                  ),
                  // Captured pieces ListView.builder
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: capturedPieces.length,
                      itemBuilder: (context, index) {
                        double imageSize = 20; // Adjust the image size as needed
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.0),
                          child: Image.asset(
                            capturedPieces[index],
                            fit: BoxFit.contain,
                            height: imageSize,
                            width: imageSize,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Timer display

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: _buildTimer(isTop ? _blackTimerActive : _whiteTimerActive,
                  isTop ? _formatTime(_blackTimeRemaining) : _formatTime(_whiteTimeRemaining)),
            ),


          ],
        ),
      ),
    );

  }

  Widget _buildTimer(bool isActive, String time) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: 70,
      height: 35,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey.withOpacity(0.7),
        border: Border.all(
          color: isActive ? Colors.black : (isActive ? Colors.black : Colors.grey.withOpacity(0.7)),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isActive)
              const Icon(
                Icons.play_arrow,
                size: 20,
                color: Colors.black,
              ),
            Text(
              time,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isActive ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }


  String _formatTime(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _onBackPressed() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade300, // A color reminiscent of a chessboard
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black, width: 2), // Black border to mimic chessboard lines
        ),
        title: const Text('Confirm', style: TextStyle(color: Colors.white)),
        content: const Text('Choose an option:', style: TextStyle(color: Colors.white)),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black,
              backgroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(false), // Continue the game
            child: const Text('Continue Game'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.white,
              backgroundColor: Colors.black,
            ),
            onPressed: _handleUserResignation, // Resign the game
            child: const Text('Resign'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black,
              backgroundColor: Colors.white,
            ),
            onPressed: _handleOfferDraw, // Offer a draw
            child: const Text('Offer Draw'),
          ),
        ],
      ),
    ) ?? false; // If dialog is dismissed, return false
  }


  void _handleOfferDraw() {
    DatabaseReference gameRef = FirebaseDatabase.instance.ref('games/${widget.gameId}');
    gameRef.update({
      'drawOffer': currentUserUID,
    });

    // Close the dialog
    Navigator.of(context).pop(false);
  }


  void _handleUserResignation() {
    String statusMessage;
    String result;

    // Determine who is the winner based on who is resigning
    if (currentUserUID == player1UID) {
      // If Player 1 resigns, Player 2 wins
      statusMessage = "$player2Name wins by resignation!";
      result = 'win';
      updateMatchHistoryIfNeeded(userId1: player2UID, userId2: player1UID, result: result, bet: betAmount,);
      updateGameStatus(statusMessage);
    } else {
      // If Player 2 resigns, Player 1 wins
      statusMessage = "$player1Name wins by resignation!";
      result = 'win';
      updateMatchHistoryIfNeeded(userId1: player1UID, userId2: player2UID, result: result, bet: betAmount,);
      updateGameStatus(statusMessage);
    }
  }



  @override
  Widget build(BuildContext context) {

  // Get the size of the screen
  Size screenSize = MediaQuery.of(context).size;
  double boardSize = screenSize.width < screenSize.height ? screenSize.width : screenSize.height;
  boardSize = boardSize < 600 ? boardSize : 600; // Limit the size to 600 if it's larger
  if (screenSize.height < screenSize.width) {
    boardSize = screenSize.height * 0.6; // or some other factor that fits
  }

return WillPopScope(
        onWillPop: _onBackPressed,
        child: Scaffold(
      backgroundColor: const Color(0xffacacaf),
      appBar: AppBar(
        title: const Text('NearbyChess'),
        centerTitle: true,
        backgroundColor: Color(0xFF3c3d3e),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0), // Set the height as required
          child: Container(
            color: const Color(0xFF595a5c), // Background color for the strip
            width: double.infinity, // Ensures the container takes full width
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  pgnNotation,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFc4c4c5),
                      fontWeight:FontWeight.bold
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

          body: Center(
            child:Column(
              mainAxisSize: MainAxisSize.min,
              //mainAxisAlignment: MainAxisAlignment.center, // Align items to the center
              children: [

                Container(
                  height: 50,
                  child: isBoardFlipped?
                  _buildPlayerArea(whiteCapturedPieces, false, player2Name):
                  _buildPlayerArea(blackCapturedPieces, true, player1Name),
                ),

                const SizedBox(height: 20),

                Container(
                  height: boardSize, // Use boardSize instead of MediaQuery.of(context).size.width
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      child: GridView.builder(
                        gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8,),
                        itemCount: 64,
                        itemBuilder: (context, index) {
                          int rank, file;
                          if (isBoardFlipped) {
                            file = 7 - (index % 8); // Flip file
                            rank = index ~/ 8;      // Flip rank
                          } else {
                            file = index % 8;
                            rank = 7 - (index ~/ 8);
                          }
                          //final int file = index % 8;
                          //final int rank = 7 - index ~/ 8;
                          final squareName = '${String.fromCharCode(97 + file)}${rank + 1}';
                          final piece = game.get(squareName);

                          Color colorA = const Color(0xFFCCDEFC);
                          Color colorB = const Color(0xFF8BA1B9);

                          // Determine the color of the square
                          var squareColor = (file + rank) % 2 == 0 ? colorA : colorB;

                          // Determine the color for the label (opposite of the square)
                          Color labelColor = squareColor == colorA ? colorB : colorA;

                          // Declare a border variable
                          Border? border;

                          // Define a variable to check if the square is a legal move
                          bool isLegalMove = legalMovesForSelected.contains(squareName);

                          // Check if the square is the starting or ending position of the last move
                          //bool isLastMoveSquare = squareName == lastMoveFrom || squareName == lastMoveTo;
                          // if (isLastMoveSquare) {
                          //   squareColor = Colors.blueGrey.withOpacity(0.0); // Adjust the color and opacity as needed
                          // }
                          return GestureDetector(
                            onTap: () {

                              if (currentUserUID != currentTurnUID) {
                                print("Not your turn");
                                return;
                              }

                              setState(() {


                                if (piece != null && piece.color == game.turn) {
                                  // Select the piece at the tapped square
                                  selectedSquare = squareName;
                                  var moves = game.generate_moves();
                                  legalMovesForSelected = moves
                                      .where((move) => move.fromAlgebraic == selectedSquare)
                                      .map((move) => move.toAlgebraic)
                                      .toList();

                                  // If no legal moves, deselect the piece
                                  if (legalMovesForSelected.isEmpty) {
                                    selectedSquare = null;
                                  }
                                }
                                // If no square is selected and there is a piece on the current square
                                else if (selectedSquare != null &&
                                    legalMovesForSelected.contains(squareName)) {
                                  final String fromSquare = selectedSquare!;  // 'from' square is the currently selected square
                                  final String toSquare = squareName;         // 'to' square is the square being moved to
                                  final chess.Piece? pieceBeforeMove = game.get(toSquare);

                                  // Check if the move is a capture
                                  bool isCapture = pieceBeforeMove != null && pieceBeforeMove.color != game.turn;
                                  // Execute the move

                                  final chess.Piece? piece = game.get(fromSquare);

                                  if (piece != null) { // Execute the move
                                    game.move({
                                      "from": selectedSquare!,
                                      "to": squareName
                                    });
                                    // Call updatePGNNotation with the piece type
                                    updatePGNNotation(piece.type, fromSquare, toSquare, isCapture);
                                    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
                                      'currentBoardState': game.fen,
                                      'currentTurn': game.turn == chess.Color.WHITE ? player2UID : player1UID,
                                    });
                                    selectedSquare = null;

                                  }
                                  

                                  lastMoveFrom = selectedSquare;
                                  lastMoveTo = squareName;
                                  selectedSquare = null;



                                  // After move, check if the move was a capture
                                  if (pieceBeforeMove != null &&
                                      pieceBeforeMove.color != game
                                          .get(selectedSquare!)
                                          ?.color) {
                                    final capturedPiece = getPieceAsset(
                                        pieceBeforeMove.type,
                                        pieceBeforeMove.color);
                                    if (game.turn == chess.Color.BLACK) {
                                      whiteCapturedPieces.add(capturedPiece);
                                      updateCapturedPiecesInRealTimeDatabase();
                                    } else {
                                      blackCapturedPieces.add(capturedPiece);
                                      updateCapturedPiecesInRealTimeDatabase();
                                    }
                                  }
                                  // Check for check or checkmate
                                  if (game.in_checkmate ||
                                      game.in_stalemate ||
                                      game.in_threefold_repetition ||
                                      game.insufficient_material) {

                                    String status;
                                    String result;

                                    if (game.in_checkmate) {

                                      result = game.turn == chess.Color.WHITE ? 'lose' : 'win';

                                      status = game.turn == chess.Color.WHITE
                                          ? 'Black wins by checkmate!'
                                          : 'White wins by checkmate!';
                                      updateGameStatus(status);
                                    } else if (game.in_stalemate) {
                                      status = 'Draw by stalemate!';
                                      result = 'draw'; // For draw conditions
                                      updateGameStatus(status);
                                    } else if (game.in_threefold_repetition) {
                                      status = 'Draw by threefold repetition!';
                                      result = 'draw'; // For draw conditions
                                      updateGameStatus(status);
                                    } else if (game.insufficient_material) {
                                      status =
                                      'Draw due to insufficient material!';
                                      result = 'draw'; // For draw conditions
                                      updateGameStatus(status);
                                    } else {
                                      status = 'Unexpected game status';
                                      result = 'draw'; // For draw conditions
                                      updateGameStatus(status);
                                    }

                                    String winnerUID = result == 'win' ? currentUserUID : (result == 'lose' ? (currentUserUID == player1UID ? player2UID : player1UID) : "");
                                    String loserUID = result == 'lose' ? currentUserUID : (result == 'win' ? (currentUserUID == player1UID ? player2UID : player1UID) : "");

                                    if (result != 'draw') {
                                      updateMatchHistoryIfNeeded(
                                        userId1: winnerUID,
                                        userId2: loserUID,
                                        result: result,
                                        bet: betAmount, // Replace with actual bet amount if applicable
                                      );
                                    }

                                    else {
                                      _switchTimer(); // Switch the timer for the next player
                                    }

                                    selectedSquare = null;
                                    legalMovesForSelected = [];
                                  } else
                                  if (selectedSquare == null && piece != null) {
                                    selectedSquare = squareName;
                                    var moves = game.generate_moves();
                                    legalMovesForSelected = moves
                                        .where((move) =>
                                    move.fromAlgebraic == selectedSquare)
                                        .map((move) => move.toAlgebraic)
                                        .toList();
                                  }
                                }
                              });

                              updateLastMoveInRealTimeDatabase(lastMoveFrom!, lastMoveTo!);

                            },
                            child: Container(
                              decoration: BoxDecoration(
                                //color: squareColor,
                                color: selectedSquare == squareName ? Colors.blue : squareColor,
                                border: border,
                              ),
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: displayPiece(piece),
                                  ),


                                  // Add row labels
                                  if (file == 0)
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Text(_getRowLabel(rank),
                                          style: TextStyle(color: labelColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Add column labels
                                  if (rank == 0)
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Text(_getColumnLabel(file), style: TextStyle(color: labelColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                Container(
                  height: 50,
                  child: isBoardFlipped ? _buildPlayerArea(blackCapturedPieces, true,player1Name) : _buildPlayerArea(whiteCapturedPieces, false,player2Name),
                )
              ],
            ),
          ),

    ),

    );
  }
}

