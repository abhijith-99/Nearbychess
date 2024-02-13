import 'dart:async'; // Import necessary for asynchronous programming features like Timer
import 'package:chess/chess.dart' as chess; // Import the chess package for chess game logic.
import 'package:cloud_firestore/cloud_firestore.dart'; // Firebase Firestore for cloud database interactions.
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth for authentication-related operations.
import 'package:firebase_database/firebase_database.dart'; // Firebase Realtime Database for real-time data storage and synchronization.
import 'package:flutter/material.dart'; // Import Flutter's material design library.
import 'package:mychessapp/pages/chess_ui.dart';
import 'package:mychessapp/pages/userhome.dart'; // Import your custom user home page.
import '../utils.dart';
import 'firebase_service.dart';
import 'message_scren.dart'; // Import utilities from the parent directory.

// statefulWidget is a flutter class
// creates the ChessBoard object
class ChessBoard extends StatefulWidget {
  // each game has its own chessboard
  final String gameId;
  final bool isSpectator;
  final String? opponentUID;


  // this is possibly the class constructor
  ChessBoard({Key? key, required this.gameId, this.isSpectator = false, required this.opponentUID}) : super(key: key);

  // current class is ChessBoard and stateClass is _ChessBoardState
  @override
  _ChessBoardState createState() => _ChessBoardState();
}

// creates state for the ChessBoard object
class _ChessBoardState extends State<ChessBoard>

{

  int lastMoveTimestamp = 0;

  bool isMessageAreaOpen = false;
  late String? opponentUId = widget.opponentUID;
  late FirebaseServices firebaseServices;
  bool isBoardFlipped =
  false; // Indicates if the chessboard is flipped. False means white pieces are at the bottom (default view).
  late chess.Chess
  game; // Instance of the chess game logic. Manages the state and rules of the chess game.
  late final StreamSubscription<DatabaseEvent>
  gameSubscription; // Subscription to Firebase database updates for real-time game changes.
  Timer? _timer; // Timer for managing the countdown of each player's time.
  int _whiteTimeRemaining = 600000; // Remaining time for the white player in seconds (initially set to 10 minutes).
  int _blackTimeRemaining = 600000; // Remaining time for the black player in seconds (initially set to 10 minutes).
  List<String> whiteCapturedPieces =
  []; // List of captured pieces by the white player.
  List<String> blackCapturedPieces =
  []; // List of captured pieces by the black player.
  String?
  lastMoveFrom; // The starting square of the last move made in the game.
  String? lastMoveTo; // The ending square of the last move made in the game.
  String?
  selectedSquare; // The currently selected square on the chessboard by the user.
  List<String> legalMovesForSelected =
  []; // List of legal moves for the piece on the selected square.
  String currentTurnUID =
      ''; // UID of the player whose turn is currently active.
  String currentUserUID =
      ''; // UID of the user playing the game (the app user).
  String player1UID = ''; // UID of player 1 (can be either black or white).
  String player2UID = ''; // UID of player 2 (opposite of player 1).
  String player1AvatarUrl =
      ''; // URL for player 1's avatar (default or user-set).
  String player2AvatarUrl =
      ''; // URL for player 2's avatar (default or user-set).
  String pgnNotation =
      ""; // String to store the game's moves in Portable Game Notation (PGN).
  String player1Name = ''; // Display name of player 1.
  String player2Name = ''; // Display name of player 2.
  bool _blackTimerActive =
  false; // Indicates if the timer for the black player is active.
  bool _whiteTimerActive =
  false; // Indicates if the timer for the white player is active.
  double betAmount = 0.0; // Amount of the bet placed on the game (if any).
  bool isGameEnded = false; // Flag to indicate if the game has ended.
  int moveNumber = 0;




  void showPromotionDialog(chess.Piece movedPiece, String toSquare, String fromSquare) {
    game.remove(fromSquare);

    print("inside the shown promotion");
    showDialog(
      context: context, // The context in which to show the dialog.
      barrierDismissible: false, // User must tap button for close.
      builder: (BuildContext context) {
        // This builder returns the widget that is to be shown in the dialog.
        return AlertDialog(
          title: const Text('Promote Pawn'),
          // Title of the dialog.
          content: const Text('Select piece to promote to:'),
          // Message shown in the dialog's content area.
          actions: <chess.PieceType>[
            // A list of piece types to choose from for promotion.
            chess.PieceType.QUEEN,
            chess.PieceType.ROOK,
            chess.PieceType.BISHOP,
            chess.PieceType.KNIGHT
          ]
              .map((type) => _promotionButton(type, movedPiece.color, toSquare, fromSquare))
              .toList(), // Convert the Iterable returned by map to a List.
        );
      },
    );
    game.remove(fromSquare);
  }

  void promotePawn(String toSquare, chess.PieceType type, chess.Color color, String fromSquare) {
    print("promote pawn is called");

    if (game.get(fromSquare)?.type == chess.PieceType.PAWN) {
      game.remove(fromSquare);
    }

    if (color == chess.Color.WHITE) {
      // For white pawns, the from-square is one rank lower
      fromSquare = String.fromCharCode(toSquare.codeUnitAt(0)) +
          (int.parse(toSquare[1]) - 1).toString();
    } else {
      // For black pawns, the from-square is one rank higher
      fromSquare = String.fromCharCode(toSquare.codeUnitAt(0)) +
          (int.parse(toSquare[1]) + 1).toString();
    }

    game.put(chess.Piece(type, color), toSquare); // Place the promoted piece

    // Update the game turn
    game.turn = (game.turn == chess.Color.WHITE)
        ? chess.Color.BLACK
        : chess.Color.WHITE;

    // Update Firebase with the new game state
    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'currentBoardState': game.fen,
      'currentTurn': game.turn == chess.Color.WHITE ? player2UID : player1UID,
      'lastMoveTimestamp': ServerValue.timestamp,
    });
    print('Promotion: from $fromSquare to $toSquare, FEN: ${game.fen}');
    checkGameEndConditions();
    setState(() {});
  }


  void checkGameEndConditions() {
    String statusMessage = '';
    String result = '';
    if (game.in_checkmate) {
      // If checkmate, determine the winner
      result = game.turn == chess.Color.WHITE ? 'lose' : 'win';
      statusMessage = game.turn == chess.Color.WHITE ? "$player2Name wins by checkmate!" : "$player1Name wins by checkmate!";
    } else if (game.in_stalemate || game.in_threefold_repetition || game.insufficient_material) {
      // Handle draw conditions
      result = 'draw';
      statusMessage = 'The game is a draw!';
    }

    // If the game has ended, update the game status and match history
    if (result.isNotEmpty) {
      updateGameStatus(statusMessage); // Update the game status in Firebase
      updateMatchHistoryIfNeeded(
        userId1: player1UID,
        userId2: player2UID,
        result: result,
        bet: betAmount,
      );
    }
  }
  Widget _promotionButton(
      chess.PieceType type, chess.Color color, String toSquare, String fromSquare) {
    print("promotion button called");
    return TextButton(
      child: Image.asset(ChessBoardUI.getPieceAsset(type, color)),
      // // Displays the image of the promotion choice.
      onPressed: () {
        promotePawn(toSquare, type, color,fromSquare);
        Navigator.of(context).pop(); // Close the dialog
        setState(() {});
      },
    );
  }

// Description: Generates the label for a row on the chessboard.
  String _getRowLabel(int index) {
    return '${1 + index}'; // Convert the zero-based index to a one-based row number.
  }

  // Description: Generates the label for a column on the chessboard.
  String _getColumnLabel(int index) {
    // Convert the zero-based index to ASCII character (a to h).
    return String.fromCharCode(97 + index); // ASCII 'a' starts at 97
  }

  void updatePGNNotation(
      chess.PieceType pieceType, String from, String to, bool isCapture) {
    // final piece = game.get(from);
    String pieceNotation = ''; // Initialize piece notation.

    // Check for castling
    if (pieceType == chess.PieceType.KING &&
        (from == 'e1' && (to == 'g1' || to == 'c1') ||
            from == 'e8' && (to == 'g8' || to == 'c8'))) {
      pgnNotation += (to == 'g1' || to == 'g8')
          ? 'O-O '
          : 'O-O-O '; // Append the appropriate castling notation.
      return;
    }
    // This block of code is responsible for generating the notation of a chess move
    print(pieceNotation);
    // Determine the piece type and set its notation
    switch (pieceType) {
      case chess.PieceType.KNIGHT:
        pieceNotation = 'N'; // Knight is represented as 'N' in PGN.
        break;
      case chess.PieceType.BISHOP:
        pieceNotation = 'B'; // Bishop.
        break;
      case chess.PieceType.ROOK:
        pieceNotation = 'R'; // Rook.
        break;
      case chess.PieceType.QUEEN:
        pieceNotation = 'Q'; // Queen
        break;
      case chess.PieceType.KING:
        pieceNotation = 'K'; // King.
        break;
      default:
        pieceNotation = ''; // Pawn moves do not use a piece notation
        break;
    }

    String move = pieceNotation +
        (isCapture ? 'x' : '') +
        to; // Construct the move notation, adding 'x' in case of a capture.

    // Append special notations for check ('+') and checkmate ('#').
    if (game.in_checkmate) {
      move += '#'; // Checkmate.
    } else if (game.in_check) {
      move += '+'; // Check.
    }

    // Prefix the move number for white's move.
    if (game.turn == chess.Color.BLACK) {
      moveNumber = moveNumber + 1; // Increment move number when it's black's turn (after white's move)
      pgnNotation += '$moveNumber. ';
    }

    if (moveNumber == 1 && game.turn == chess.Color.BLACK) {
      FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
        'initialMovesCompleted': true,
      });// After white's move, it's black's turn
    }

    pgnNotation += '$move '; // Append the move to the game's PGN notation.
    firebaseServices.updatePGNNotationInRealTimeDatabase(pgnNotation); // Update the PGN notation in the Firebase Realtime Database.
    setState(() {}); // Trigger UI update.
  }





  void updateTimerInFirebase(String gameId, String playerUID, int remainingTime) {
    final gameRef = FirebaseDatabase.instance.ref('games/$gameId');
    final fieldToUpdate = playerUID == player1UID ? 'whiteTimeRemaining' : 'blackTimeRemaining';
    gameRef.update({fieldToUpdate: remainingTime});
  }


  void listenForTimerUpdates(String gameId) {
    final gameRef = FirebaseDatabase.instance.ref('games/$gameId');

    gameRef.child('whiteTimeRemaining').onValue.listen((event) {
      final whiteTime = event.snapshot.value as int?;
      if (whiteTime != null) {
        setState(() {
          _whiteTimeRemaining = whiteTime;
        });
      }
    });

    gameRef.child('blackTimeRemaining').onValue.listen((event) {
      final blackTime = event.snapshot.value as int?;
      if (blackTime != null) {
        setState(() {
          _blackTimeRemaining = blackTime;
        });
      }
    });
  }

  @override // initState method: Runs when the ChessBoard widget is created
  void initState() {
    super.initState();
    print('Opponent UID from the init: ${widget.opponentUID}');

    firebaseServices = FirebaseServices(widget.gameId);

    // if (widget.isSpectator) {
    //   // Spectators only listen for timer updates, not start the timer themselves
    //   listenForTimerUpdates(widget.gameId);
    // } else {
    //   // Players listen for the game to start before starting their timer
    //   FirebaseDatabase.instance.ref('games/${widget.gameId}/initialMovesCompleted').onValue.listen((event) {
    //     final gameStarted = event.snapshot.value as bool? ?? false;
    //     if (gameStarted) {
    //       // Ensure the timer is not already running to prevent restarting it
    //       if (_timer == null) {
    //         _startTimer();
    //
    //       }
    //     }
    //   });
    // }




    fetchAndSetTimerValue().then((_) {
      // Existing listener for game start
      if (widget.isSpectator) {
        listenForTimerUpdates(widget.gameId);
      } else {
        FirebaseDatabase.instance.ref('games/${widget.gameId}/initialMovesCompleted').onValue.listen((event) {
          final gameStarted = event.snapshot.value as bool? ?? false;
          if (gameStarted) {
            if (_timer == null) {
              _startTimer();
            }
          }
        });
      }
    });


    isGameEnded = false;
    game = chess.Chess(); // Initialize the chess game logic.
    currentUserUID = FirebaseAuth.instance.currentUser?.uid ?? '';
    var gameData; // Variable to store game data fetched from Firebase.
    listenForTimerUpdates(widget.gameId);

    // Fetch the bet amount for the current game and update the state with the fetched value.
    firebaseServices.fetchBetAmount().then((value) {
      setState(() {
        betAmount = value; // Update the bet amount in the state.
      });
      print("betAmount is sss$betAmount");
    });
    // Set up a subscription to listen for real-time updates from Firebase for the current game.
    gameSubscription = FirebaseDatabase.instance
        .ref('games/${widget.gameId}')
        .onValue
        .listen((event) async {
      final data = event.snapshot.value; // Extract the data from the event snapshot.
      if (data is Map) {
        gameData = data.map((key, value) => MapEntry(key.toString(),
            value)); // Convert the data to a more flexible Map<String, dynamic> format.
      }

      var newFen = gameData[
      'currentBoardState']; // Extract the current board state in Forsyth-Edwards Notation (FEN) from the game data.
      // Update the current turn and player UIDs from the game data.
      currentTurnUID = gameData['currentTurn'];

      player1UID = gameData['player1UID'] ?? '';
      player2UID = gameData['player2UID'] ?? '';
      fetchPlayerDetails();

      bool isCurrentUserBlack = currentUserUID ==
          player1UID; // Determine if the current user is playing as black.
      var newPgnNotation = gameData['pgnNotation'] ?? ""; // Update the Portable Game Notation (PGN) from the game data.

      // Show game over dialog if the game status indicates the game has ended.
      if (gameData['gameStatus'] != null &&
          gameData['gameStatus'] != 'ongoing') {
        _showGameOverDialog(gameData['gameStatus']);
      }

      // Show a draw offer dialog if a draw has been offered by the opponent.
      if (data is Map &&
          data['drawOffer'] != null &&
          data['drawOffer'] != currentUserUID) {
        _showDrawOfferDialog();
      }

      // Update the state with the latest data from Firebase
      setState(() {
        game.load(
            newFen); // Load the new board state into the chess game logic.
        isBoardFlipped =
            isCurrentUserBlack; // Flip the board if the current user is playing as black.
        // Update the lists of captured pieces for both players.
        whiteCapturedPieces =
        List<String>.from(gameData['whiteCapturedPieces'] ?? []);
        blackCapturedPieces =
        List<String>.from(gameData['blackCapturedPieces'] ?? []);

        pgnNotation = newPgnNotation; // Update the PGN notation for the game.

        // Reset selectedSquare if it's now the current user's turn
        if (currentTurnUID == currentUserUID) {
          selectedSquare = null;
        }
      });
    });

  }



  Future<void> fetchAndSetTimerValue() async {
    final timerValueSnapshot = await FirebaseDatabase.instance.ref('games/${widget.gameId}/localTimerValue').get();
    final String localTimerValueString = timerValueSnapshot.value as String;

    // Assuming localTimerValue is in minutes; convert to milliseconds
    final int localTimerValue = int.tryParse(localTimerValueString) ?? 30;

    print("localimerdddddd$localTimerValue");

    final timerValueInMilliseconds = (localTimerValue) * 60 * 1000;

    setState(() {
      _whiteTimeRemaining = timerValueInMilliseconds;
      _blackTimeRemaining = timerValueInMilliseconds;
    });

    print("witetimeremaind$_whiteTimeRemaining");

    print("bltimeremaind$_blackTimeRemaining");
    print("dfdsatimervalieinmillief$timerValueInMilliseconds");
  }

  Future<void> fetchPlayerDetails() async {
    // Fetch Player 1's document from Firestore.
    var player1Doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(player1UID)
        .get();

    // Check if Player 1's document exists.
    if (player1Doc.exists) {
      // Extract data from Player 1's document.
      var player1Data = player1Doc.data();
      // Update the state with Player 1's name and avatar URL.
      print("player1 datasss $player1Data");
      setState(() {
        player1Name = player1Data?['name'] ??
            'Unknown'; // Set name, default to 'Unknown' if not found.
        player1AvatarUrl = player1Data?['avatar'] ?? 'assets/avatar/avatar-default.png'; // Set avatar URL, default to a placeholder image.
      });
    }

    // Fetch Player 2's details in a similar manner.
    var player2Doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(player2UID)
        .get();
    if (player2Doc.exists) {
      var player2Data = player2Doc.data();
      print("player2 datasss $player2Data");
      setState(() {
        player2Name = player2Data?['name'] ?? 'Unknown';
        player2AvatarUrl = player2Data?['avatar'] ?? 'assets/avatar/avatar-default.png';
      });
    }
  }


// Description: Displays a dialog when a draw offer has been made by the opponent.
  void _showDrawOfferDialog() {
    // Show a dialog window on the screen.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Set the background color and shape of the dialog.
        backgroundColor: Colors.brown.shade300,
        // Chessboard-like color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(
              color: Colors.black, width: 2), // Mimicking chessboard lines
        ),
        // Dialog title.
        title:
        const Text('Draw Offered', style: TextStyle(color: Colors.white)),
        // Dialog content.
        content: const Text(
            'Your opponent has offered a draw. Do you agree to a draw?',
            style: TextStyle(color: Colors.white)),
        // Dialog actions (buttons).
        actions: <Widget>[
          // Button to accept the draw offer.
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black, // Text color
              backgroundColor: Colors.white, // Button background color
            ),
            onPressed: () {
              // Handle the acceptance of the draw.
              _updateGameStatus('draw');
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Accept Draw'),
          ),
          // Button to decline the draw offer.
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.white, // Text color
              backgroundColor: Colors.black, // Button background color
            ),
            onPressed: () {
              // Handle the decline of the draw.
              DatabaseReference gameRef =
              FirebaseDatabase.instance.ref('games/${widget.gameId}');
              gameRef.update(
                  {'drawOffer': null}); // Clear the draw offer in the database
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Decline Draw'),
          ),
        ],
      ),
    );
  }

// Description: Updates the match history and chess coins balance, if the game has not already been marked as ended.
  void updateMatchHistoryIfNeeded({
    required String userId1, //   - userId1: UID of the first player.
    required String userId2, //   - userId2: UID of the second player.
    required String result, //   se', or 'draw').
    required double bet, //   - bet: The bet amount for the match.
  })
  {
    if (!isGameEnded) {
      isGameEnded = true; // Mark the game as ended to prevent

      // Determine the winner and loser based on the match result.
      String winnerUID = (result == 'win') ? userId1 : userId2;
      String loserUID = (winnerUID == userId1) ? userId2 : userId1;

      // Update the match history in the database.
      firebaseServices.updateMatchHistory(
        userId1: userId1,
        userId2: userId2,
        result: result,
        bet: bet,
      );

      // Update the chess coins balance for both players, except in case of a draw.
      if (result != 'draw') {
        firebaseServices.updateChessCoinsBalance(
            winnerUID, bet, true); // Update balance for the winner.
        firebaseServices.updateChessCoinsBalance(
            loserUID, bet, false); // Update balance for the loser.
      }
    }
  }

//   - newStatus: The new status of the game (e.g., 'draw', 'win', 'lose').
  void _updateGameStatus(String newStatus) {
    // Reference to the game's data in the Firebase Realtime Database.
    DatabaseReference gameRef =
    FirebaseDatabase.instance.ref('games/${widget.gameId}');

    // Update the game status and clear any existing draw offers in the database.
    gameRef.update({
      'gameStatus': newStatus,
      'drawOffer': null, // Clearing the draw offer field.
    });
    // Special handling in case the new status is 'draw'.
    if (newStatus == 'draw') {
      // Update the match history to record the draw result.
      updateMatchHistoryIfNeeded(
        userId1: player1UID,
        userId2: player2UID,
        result: newStatus,
        bet: 0.0, // No bet amount is involved in a draw.
      );
    }
  }


  void _showGameOverDialog(String statusMessage) {
    // Cancel the game timer as the game is over.
    _timer?.cancel();

    // Display a dialog with the game over information.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        // Set the appearance of the dialog.
        backgroundColor: Colors.brown.shade300,
        // Chessboard-like color.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(
              color: Colors.black, width: 2), // Chessboard-like border.
        ),
        // Dialog title with an icon and text.
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            // Icon representing game over.
            SizedBox(width: 8),
            Text(
              'Game Over',
              style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        // Dialog content displaying the status message.
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Center(
                child: Text(
                  statusMessage,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
        // Action button to return to the home screen.
        actions: <Widget>[
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                primary: Colors.white,
              ),
              onPressed: () {
                // Handle the press action.
                updateInGameState(false);
                Navigator.of(context).pop(); // Close the dialog.
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

//   - statusMessage: A string representing the new game status to be updated in the database.
  void updateGameStatus(String statusMessage) {
    // Reference the game in the Firebase Realtime Database and update its status.
    FirebaseDatabase.instance.ref('games/${widget.gameId}').update({
      'gameStatus': statusMessage,
      // Update the game status field with the new status message.
    });
  }


// Description: Starts a countdown timer for each player's turn in the game.
  void _startTimer() {
    // Define the duration for each timer tick (1 second).
    const oneSec = Duration(milliseconds: 1000);
    // Create a periodic timer that executes every second.
    _timer = Timer.periodic(oneSec, (timer) {
      setState(() {
        // Check whose turn it is and update the respective timer.
        if (game.turn == chess.Color.WHITE) {
          // Decrement the white player's timer if it's greater than 0.
          if (_whiteTimeRemaining > 0) {
            _whiteTimeRemaining-= 1000;
          } else {
            // Handle the timeout scenario for the white player.
            timer.cancel();
            _handleTimeout(chess.Color.WHITE);
          }
          // Indicate that the white timer is active and the black timer is not.
          _whiteTimerActive = true;
          _blackTimerActive = false;
        } else {
          // Similar handling for the black player's timer.
          if (_blackTimeRemaining > 0) {
            _blackTimeRemaining-= 1000;
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
    _timer?.cancel(); // Cancel the previous timer
    _startTimer();
  }

  @override
  void dispose() {
    // Cancel the game timer to prevent any callbacks after the widget is disposed.
    _timer?.cancel();

    // Call the dispose method of the superclass.onWhitePlayerMove
    super.dispose();

    // Cancel the subscription to the game updates in Firebase.
    gameSubscription.cancel();
  }


// Method to handle the back press action in the app.
  Future<bool> _onBackPressed() async {
    // Show a confirmation dialog when the back button is pressed.
    if (widget.isSpectator) {
      Navigator.of(context).pop(); // Pop the current page off the stack.
      return true; // Indicate that the back button press has been handled.
    }
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade300,
        // Chessboard-themed background color.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15), // Rounded shape.
          side: BorderSide(color: Colors.black, width: 2), // Black border.
        ),
        title: const Text('Confirm', style: TextStyle(color: Colors.white)),
        // Dialog title.
        content: const Text('Choose an option:',
            style: TextStyle(color: Colors.white)),
        // Dialog content.
        actions: <Widget>[
          // Button to continue the game.
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black, // Text color.
              backgroundColor: Colors.white, // Button color.
            ),
            onPressed: () => Navigator.of(context).pop(false),
            // Close dialog and continue game.
            child: const Text('Continue Game'),
          ),
          // Button to resign from the game.
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.white, // Text color.
              backgroundColor: Colors.black, // Button color.
            ),
            onPressed: _handleUserResignation, // Handle game resignation.
            child: const Text('Resign'),
          ),
          // Button to offer a draw.
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black, // Text color.
              backgroundColor: Colors.white, // Button color.
            ),
            onPressed: _handleOfferDraw, // Handle offering a draw.
            child: const Text('Offer Draw'),
          ),
        ],
      ),
    ) ??
        false; // Return false if the dialog is dismissed (e.g., by tapping outside it).
  }

// Method to handle the action of offering a draw in the game.
  void _handleOfferDraw() {
    // Reference to the current game in Firebase Realtime Database.
    DatabaseReference gameRef =
    FirebaseDatabase.instance.ref('games/${widget.gameId}');

    // Update the game's data in Firebase to indicate that the current user has offered a draw.
    gameRef.update({
      'drawOffer': currentUserUID,
      // Set the draw offer to the current user's UID.
    });

    // Close the currently open dialog after the draw offer is made.
    Navigator.of(context).pop(false);
  }

  void _toggleMessageArea() {
    setState(() {
      isMessageAreaOpen = !isMessageAreaOpen; // Toggle the message area state
    });
  }


// Method to handle the action when a user decides to resign from the game.
  void _handleUserResignation() {
    String statusMessage; // Variable to store the status message of the game.
    String result; // Variable to store the result

    // Determine the winner based on who is resigning.
    if (currentUserUID == player1UID) {
      // Case when Player 1 resigns, implying Player 2 wins.
      statusMessage = "$player2Name wins by resignation!";
      result = 'win';
      // Update the match history to reflect Player 2's win and Player 1's loss.
      updateMatchHistoryIfNeeded(
        userId1: player2UID,
        userId2: player1UID,
        result: result,
        bet: betAmount,
      );
      print("betamount from chess$betAmount");
      // Update the game status in the database with the resignation message.
      updateGameStatus(statusMessage);
    } else {
      // Case when Player 2 resigns, implying Player 1 wins.
      statusMessage = "$player1Name wins by resignation!";
      result = 'win';
      // Similar update for match history and game status as above.
      updateMatchHistoryIfNeeded(
        userId1: player1UID,
        userId2: player2UID,
        result: result,
        bet: betAmount,
      );
      updateGameStatus(statusMessage);
    }
  }

  @override
  Widget build(BuildContext context) {

    String actualOpponentUID = (currentUserUID == player1UID) ? player2UID : player1UID;

    // Determine the screen size to adjust the chessboard size accordingly.
    Size screenSize = MediaQuery.of(context).size;
    // Calculate the board size based on the screen dimensions, limiting it to a maximum of 600.
    double boardSize = screenSize.width < screenSize.height
        ? screenSize.width
        : screenSize.height;
    boardSize = boardSize < 600 ? boardSize : 600; // Cap the board size at 600.
    // Adjust the board size for landscape mode if necessary.
    if (screenSize.height < screenSize.width) {
      boardSize = screenSize.height * 0.6; // Adjust based on height in landscape mode.
    }

    // Main scaffold widget of the app.
    return WillPopScope(
      onWillPop: _onBackPressed, // Handle back button press.
      child: Scaffold(
        backgroundColor: const Color(0xffacacaf),
        // Background color of the app.
        appBar: AppBar(
          title: const Text('NearbyChess'),
          // Title of the app.
          centerTitle: true,
          // Center the title.
          backgroundColor: Color(0xFF3c3d3e),
          actions: [
            if(!widget.isSpectator)
              IconButton(
                icon: Icon(Icons.message, color: Colors.blue),
                onPressed: _toggleMessageArea, // Use the updated function
              ),

            IconButton(
              icon: Icon(Icons.exit_to_app, color: Colors.red),
              onPressed: _onBackPressed,
              iconSize: 30.0, // Increase the icon size
            ),
          ],

          // AppBar background color.
          automaticallyImplyLeading: false,
          // No back button.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(30.0),
            // Height of the bottom area of the AppBar.
            child: Container(
              color: const Color(0xFF595a5c),
              // Background color for the bottom strip of the AppBar.
              width: double.infinity,
              // Full width.
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    pgnNotation, // Display the PGN notation of the game.
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFFc4c4c5),
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Row(
          children: [
            Expanded(
              flex: isMessageAreaOpen ? 3 : 4,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display the player area for the top player.
                    Container(
                      height: 50,
                      child: isBoardFlipped
                          ? ChessBoardUI.buildPlayerArea(
                          whiteCapturedPieces,
                          false,
                          player2Name,
                          player2AvatarUrl,
                          _whiteTimerActive,
                          _whiteTimeRemaining)
                          : ChessBoardUI.buildPlayerArea(
                          blackCapturedPieces,
                          true,
                          player1Name,
                          player1AvatarUrl,
                          _blackTimerActive,
                          _blackTimeRemaining),
                    ),
                    const SizedBox(height: 20), // Spacer.
                    // Chessboard container.
                    Container(
                      height: boardSize, // Use calculated board size.
                      child: AspectRatio(
                        aspectRatio: 1,
                        // Maintain a 1:1 aspect ratio for the chessboard.
                        child: Container(
                          child: GridView.builder(
                            gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8, // 8 squares per row.
                            ),
                            itemCount: 64, // Total squares on the chessboard.
                            itemBuilder: (context, index) {
                              // ... Existing chessboard square code ...
                              int rank, file;
                              if (isBoardFlipped) {
                                // Flip calculation if the board is flipped.
                                file = 7 - (index % 8);
                                rank = index ~/ 8;
                              } else {
                                // Standard calculation for rank and file.
                                file = index % 8;
                                rank = 7 - (index ~/ 8);
                              }
                              // Create the square name (e.g., 'a1', 'b2', etc.).
                              final squareName =
                                  '${String.fromCharCode(97 + file)}${rank + 1}';
                              // Get the piece on the current square.
                              final piece = game.get(squareName);

                              // Set colors for the chessboard squares.
                              Color colorA =
                              const Color(0xFFCCDEFC); // Light square color.
                              Color colorB =
                              const Color(0xFF8BA1B9); // Dark square color.

                              // Determine the color of each square.
                              var squareColor =
                              (file + rank) % 2 == 0 ? colorA : colorB;

                              // Determine the label color (opposite of the square color).
                              Color labelColor =
                              squareColor == colorA ? colorB : colorA;

                              // Define a border variable (not currently used).
                              Border? border;

                              // Check if the current square is a legal move.
                              bool isLegalMove =
                              legalMovesForSelected.contains(squareName);

                              // GestureDetector to handle taps on each square.
                              return GestureDetector(
                                onTap: () {
                                  print("in tap");
                                  // Check if it's the current user's turn to make a move.
                                  if (currentUserUID != currentTurnUID) {
                                    print("Not your turn");
                                    return; // Exit the function if it's not the current user's turn.
                                  }
                                  if (widget.isSpectator) {
                                    print("Spectators cannot interact with the game.");
                                    return;
                                  }
                                  setState(() {
                                    // Check if there is a piece on the tapped square and if it's the turn of that piece's color.
                                    if (piece != null && piece.color == game.turn) {
                                      // Select the piece at the tapped square.
                                      selectedSquare = squareName; // Mark this square as selected.
                                      print("in setstate if");
                                      print("selected square $selectedSquare");
                                      // Generate all possible moves for the current game state.
                                      var moves = game.generate_moves();

                                      // Filter the moves to find only those that start from the selected square.
                                      legalMovesForSelected = moves
                                          .where((move) =>
                                      move.fromAlgebraic == selectedSquare)
                                          .map((move) => move.toAlgebraic)
                                          .toList();
                                      print("legalmovess $legalMovesForSelected");

                                      // Deselect the piece if there are no legal moves from the selected square.
                                      if (legalMovesForSelected.isEmpty) {
                                        selectedSquare = null;
                                      }
                                    }
                                    // Handle the scenario where the user is moving a piece to a new square.
                                    else if (selectedSquare != null &&
                                        legalMovesForSelected.contains(squareName)) {
                                      print("in setstate elseif");
                                      print(selectedSquare);
                                      // Identify the square from which the piece is being moved.
                                      String fromSquare = selectedSquare!;
                                      // Identify the square to which the piece is being moved.
                                      String toSquare = squareName;
                                      // Check if there is a piece on the destination square.
                                      chess.Piece? pieceBeforeMove = game.get(toSquare);

                                      // Check if the move is a capture.
                                      bool isCapture = pieceBeforeMove != null &&
                                          pieceBeforeMove.color != game.turn;

                                      // Get the piece from the starting square.
                                      final chess.Piece? piece = game.get(fromSquare);

                                      // Execute the move if a piece is present.
                                      if (piece != null) {
                                        print(
                                            "Attempting to move from $fromSquare to $toSquare");
                                        // Execute the move in the game logic.
                                        game.move({
                                          "from": selectedSquare!,
                                          "to": squareName
                                        });

                                        // Update the PGN notation for the move.
                                        updatePGNNotation(piece.type, fromSquare,
                                            toSquare, isCapture);


                                        // Update Firebase with the new game state and last move
                                        final currentPlayerUID = game.turn == chess.Color.WHITE ? player1UID : player2UID;
                                        final remainingTime = game.turn == chess.Color.WHITE ? _whiteTimeRemaining : _blackTimeRemaining;

                                        // Update the game state in Firebase.
                                        FirebaseDatabase.instance
                                            .ref('games/${widget.gameId}')
                                            .update({
                                          'currentBoardState': game.fen,
                                          'currentTurn': game.turn == chess.Color.WHITE ? player2UID : player1UID,
                                        });
                                        updateTimerInFirebase(widget.gameId, currentPlayerUID, remainingTime);


                                      }
                                      if (pieceBeforeMove != null) {
                                        final capturedPiece = ChessBoardUI.getPieceAsset(pieceBeforeMove.type, pieceBeforeMove.color);
                                        // Update the capturer's captured pieces list based on the color of the captured piece.
                                        if (pieceBeforeMove.color == chess.Color.BLACK) {
                                          // If the captured piece is black, add to white's captured pieces list.
                                          whiteCapturedPieces.add(capturedPiece);
                                        } else {
                                          // If the captured piece is white, add to black's captured pieces list.
                                          blackCapturedPieces.add(capturedPiece);
                                        }
                                        firebaseServices.updateCapturedPiecesInRealTimeDatabase(whiteCapturedPieces, blackCapturedPieces);
                                      }

                                      // Check for special game conditions like checkmate, stalemate, etc.
                                      if (game.in_checkmate ||
                                          game.in_stalemate ||
                                          game.in_threefold_repetition ||
                                          game.insufficient_material) {
                                        String status;
                                        String result;

                                        // Determine the game's status and result based on the current condition.
                                        if (game.in_checkmate) {
                                          // Assign result based on who is in checkmate.
                                          result = game.turn == chess.Color.WHITE
                                              ? 'lose'
                                              : 'win';
                                          // Assign status message for checkmate.
                                          status = game.turn == chess.Color.WHITE
                                              ? 'Black wins by checkmate!'
                                              : 'White wins by checkmate!';
                                          updateGameStatus(
                                              status); // Update the game status.
                                        } else if (game.in_stalemate) {
                                          status = 'Draw by stalemate!';
                                          result =
                                          'draw'; // Set result to draw for stalemate.
                                          updateGameStatus(
                                              status); // Update the game status.
                                        } else if (game.in_threefold_repetition) {
                                          status = 'Draw by threefold repetition!';
                                          result =
                                          'draw'; // Set result to draw for threefold repetition.
                                          updateGameStatus(
                                              status); // Update the game status.
                                        } else if (game.insufficient_material) {
                                          status =
                                          'Draw due to insufficient material!';
                                          result =
                                          'draw'; // Set result to draw for insufficient material.
                                          updateGameStatus(
                                              status); // Update the game status.
                                        } else {
                                          status = 'Unexpected game status';
                                          result =
                                          'draw'; // Default to draw for any unexpected status.
                                          updateGameStatus(
                                              status); // Update the game status.
                                        }

                                        // Determine the winner and loser UIDs based on the result.
                                        String winnerUID = result == 'win'
                                            ? currentUserUID
                                            : (result == 'lose'
                                            ? (currentUserUID == player1UID
                                            ? player2UID
                                            : player1UID)
                                            : "");
                                        String loserUID = result == 'lose'
                                            ? currentUserUID
                                            : (result == 'win'
                                            ? (currentUserUID == player1UID
                                            ? player2UID
                                            : player1UID)
                                            : "");

                                        // Update match history if the result is not a draw.
                                        if (result != 'draw') {
                                          updateMatchHistoryIfNeeded(
                                            userId1: winnerUID,
                                            userId2: loserUID,
                                            result: result,
                                            bet: betAmount, // Use the actual bet amount if applicable.
                                          );
                                        } else {
                                          _switchTimer(); // Switch the timer to the next player if it's a draw.
                                        }
                                        // Reset selected square and legal moves after handling the special condition.
                                        selectedSquare = null;
                                        legalMovesForSelected = [];
                                      } else if (selectedSquare == null &&
                                          piece != null) {
                                        // If no piece is currently selected and there is a piece on the square, select it.
                                        selectedSquare = squareName;
                                        // Generate all possible moves for the selected piece.
                                        var moves = game.generate_moves();
                                        legalMovesForSelected = moves
                                            .where((move) =>
                                        move.fromAlgebraic == selectedSquare)
                                            .map((move) => move.toAlgebraic)
                                            .toList();
                                      }

                                      final chess.Piece? movedPiece = game.get(toSquare);
                                      print("Moved piece: $movedPiece");
                                      String rank;

                                      // Check for promotion condition.
                                      if (toSquare.length == 3) {
                                        // If the square notation has an extra character at the beginning.
                                        rank =
                                        toSquare[2]; // Extracts '8' from 'xh8'.
                                      } else {
                                        // Standard square notation.
                                        rank = toSquare[1]; // Extracts '8' from 'h8'.
                                      }
                                      print("squareName is $squareName");

                                      if (selectedSquare != null && legalMovesForSelected.contains(squareName)) {
                                        String fromSquare = selectedSquare!;
                                        String toSquare = squareName;

                                        // Check if the move is a pawn reaching the 8th or 1st rank (promotion)
                                        bool isPawnPromotion = game.get(fromSquare)?.type == chess.PieceType.PAWN &&
                                            (toSquare.endsWith('8') || toSquare.endsWith('1'));
                                        if (isPawnPromotion) {
                                          // Perform the move
                                          game.move({
                                            "from": fromSquare,
                                            "to": toSquare,
                                            "promotion": 'q' // Assuming queen promotion for simplicity
                                          });

                                          showPromotionDialog(game.get(toSquare)!, toSquare, fromSquare);
                                        }
                                        // Reset selected square and legal moves
                                        selectedSquare = null;
                                        legalMovesForSelected = [];
                                      }

                                    }
                                  });
                                  // Update the last move in Firebase after the move is made.
                                  firebaseServices.updateLastMoveInRealTimeDatabase(
                                      lastMoveFrom!, lastMoveTo!);
                                },
                                child: Container(
                                  // Styling for each chessboard square.
                                  decoration: BoxDecoration(
                                    color: selectedSquare == squareName
                                        ? Colors
                                        .blue // Highlight color for the selected square.
                                        : squareColor,
                                    // Regular color for non-selected squares.
                                    border: border, // Border for the square (if any).
                                  ),
                                  child: Stack(
                                    children: [
                                      // Align the chess piece in the center of the square.
                                      Align(
                                        alignment: Alignment.center,
                                        child: ChessBoardUI.displayPiece(
                                            piece), // Display the chess piece.
                                      ),
                                      // Add row labels on the left side of the board.
                                      if (file == 0)
                                        Align(
                                          alignment: Alignment.topLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Text(
                                              _getRowLabel(rank),
                                              style: TextStyle(
                                                color: labelColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      // Add column labels on the bottom of the board.
                                      if (rank == 0)
                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Text(
                                              _getColumnLabel(file),
                                              style: TextStyle(
                                                color: labelColor,
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
                    const SizedBox(height: 20), // Spacer.
                    // Display the player area for the bottom player.
                    Container(
                      height: 50,
                      child: isBoardFlipped
                          ? ChessBoardUI.buildPlayerArea(
                        blackCapturedPieces,
                        true,
                        player1Name,
                        player1AvatarUrl,
                        _blackTimerActive,
                        _blackTimeRemaining,
                      )
                          : ChessBoardUI.buildPlayerArea(
                        whiteCapturedPieces,
                        false,
                        player2Name,
                        player2AvatarUrl,
                        _whiteTimerActive,
                        _whiteTimeRemaining,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (isMessageAreaOpen)
              Expanded(
                  flex: 1,
                  child :Container(
                    color: Colors.white, // Set background color as needed
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end, // Align children to the start of the cross axis
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end, // Align children to the start of the main axis
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.black),
                              onPressed: () {
                                setState(() {
                                  isMessageAreaOpen = false;
                                });
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: MessageScreen(
                            opponentUId: actualOpponentUID,
                            fromChessBoard: true,
                          ),
                        ),
                      ],
                    ),
                  )
              ),
          ],
        ),
      ),
    );
  }
}

