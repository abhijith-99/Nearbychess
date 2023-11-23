import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mychessapp/pages/userhome.dart';

class ChessBoard extends StatefulWidget {
  final String gameId;

  ChessBoard({Key? key, required this.gameId}) : super(key: key);

  @override
  _ChessBoardState createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  bool isBoardFlipped = false;
  late chess.Chess game;
  late final StreamSubscription<DocumentSnapshot> gameSubscription;
  Timer? _timer;
  int _whiteTimeRemaining = 600; // 10 minutes in seconds
  int _blackTimeRemaining = 600; // 10 minutes in seconds
  //final bool _isWhiteTurn = true; // Track turns. White goes first.
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
    return assetPath;
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

  void updateCapturedPiecesInFirestore() {
    FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'whiteCapturedPieces': whiteCapturedPieces,
      'blackCapturedPieces': blackCapturedPieces,
    });
  }

  void updateLastMoveInFirestore(String fromSquare, String toSquare) {
    FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
      'lastMoveFrom': fromSquare,
      'lastMoveTo': toSquare,
    });
  }

  void updatePGNNotationInFirestore(String pgnNotation) {
    FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
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
      int moveNumber = (game.history.length / 2).ceil() + 1;
      pgnNotation += '$moveNumber. ';
    }

    pgnNotation += '$move ';

    updatePGNNotationInFirestore(pgnNotation);
    setState(() {});
  }



  @override
  void initState() {
    super.initState();
    _startTimer();
    game = chess.Chess();
    currentUserUID = FirebaseAuth.instance.currentUser?.uid ?? '';

    gameSubscription = FirebaseFirestore.instance.collection('games').doc(widget.gameId).snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        var gameData = snapshot.data() as Map<String, dynamic>;
        var newFen = gameData['currentBoardState'];
        currentTurnUID = gameData['currentTurn'];
        player1UID = gameData['player1UID'];
        player2UID = gameData['player2UID'];
        bool isCurrentUserBlack = currentUserUID == player1UID;
        var newPgnNotation = gameData['pgnNotation'] ?? "";

        // Fetch player1's name
        var player1Doc = await FirebaseFirestore.instance.collection('users').doc(player1UID).get();
        var player1Data = player1Doc.data();
        player1Name = player1Data?['name'] ?? ''; // Set player1Name here
        player1AvatarUrl = player1Data?['avatar'] ?? ''; // Existing code

        // Fetch player2's name
        var player2Doc = await FirebaseFirestore.instance.collection('users').doc(player2UID).get();
        var player2Data = player2Doc.data();
        player2Name = player2Data?['name'] ?? ''; // Set player2Name here
        player2AvatarUrl = player2Data?['avatar'] ?? ''; // Existing code

        if (gameData['gameStatus'] != null && gameData['gameStatus'] != 'ongoin') {
          _showGameOverDialog(gameData['gameStatus']);
        }

        // Update the board state based on new FEN
        setState(() {
          print('game state before loading: $newFen ');

          game.load(newFen); // Assuming 'game' is your chess library instance
          print('game state after loading: $newFen ');
          isBoardFlipped = isCurrentUserBlack;
          whiteCapturedPieces = List<String>.from(gameData['whiteCapturedPieces'] ?? []);
          blackCapturedPieces = List<String>.from(gameData['blackCapturedPieces'] ?? []);
          this.player1AvatarUrl = player1AvatarUrl;
          this.player2AvatarUrl = player2AvatarUrl;
          lastMoveFrom = gameData['lastMoveFrom'];
          lastMoveTo = gameData['lastMoveTo'];
          pgnNotation = newPgnNotation;
        });
      }
    });

  }

  void _showGameOverDialog(String statusMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.brown.shade300, // A color reminiscent of a chessboard
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.black, width: 2), // Black border to mimic chessboard lines
        ),
        title: Row(
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
    FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
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
    String winner = color == chess.Color.WHITE ? "Black" : "White";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Time Out'),
        content: Text('$winner wins by timeout!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const UserHomePage(), // Replace HomeScreen with the actual home screen widget
                ),
              );
            },
            child: const Text('Home'),
          ),
        ],
      ),
    );
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


  Widget _buildPlayerArea(List<String> capturedPieces, bool isTop, String playerName) {
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
                      style: TextStyle(
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
              Icon(
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffacacaf),
      appBar: AppBar(
        title: const Text('NearbyChess'),
        centerTitle: true,
        backgroundColor: Color(0xFF3c3d3e),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0), // Set the height as required
          child: Container(
            color: Color(0xFF595a5c), // Background color for the strip
            width: double.infinity, // Ensures the container takes full width
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  pgnNotation,
                  style: TextStyle(
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

            SizedBox(height: 20),

            Container(
              height: MediaQuery.of(context).size.width,
              //child: Center(
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
                      bool isLastMoveSquare = squareName == lastMoveFrom || squareName == lastMoveTo;
                      if (isLastMoveSquare) {
                        squareColor = Colors.blueGrey.withOpacity(0.5); // Adjust the color and opacity as needed
                      }



                      return GestureDetector(
                        onTap: () {
                          print('Game fen before touch: ${game.fen}');

                          if (currentUserUID != currentTurnUID) {
                            print("Not your turn");
                            return;
                          }

                          setState(() {
                            //if (game.get(squareName)?.color == game.turn) {
                            if (piece != null && piece.color == game.turn) {
                              // Select the piece at the tapped square
                              selectedSquare = squareName;
                              var moves = game.generate_moves();
                              legalMovesForSelected = moves
                                  .where((move) => move.fromAlgebraic == selectedSquare)
                                  .map((move) => move.toAlgebraic)
                                  .toList();
                              print('Piece selected at $selectedSquare. Legal moves: $legalMovesForSelected');

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
                              }

                              lastMoveFrom = selectedSquare;
                              lastMoveTo = squareName;



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
                                  updateCapturedPiecesInFirestore();
                                } else {
                                  blackCapturedPieces.add(capturedPiece);
                                  updateCapturedPiecesInFirestore();
                                }
                              }


                              // Check for check or checkmate
                              if (game.in_checkmate ||
                                  game.in_stalemate ||
                                  game.in_threefold_repetition ||
                                  game.insufficient_material) {
                                String status;
                                if (game.in_checkmate) {
                                  status = game.turn == chess.Color.WHITE
                                      ? 'Black wins by checkmate!'
                                      : 'White wins by checkmate!';
                                  updateGameStatus(status);
                                } else if (game.in_stalemate) {
                                  status = 'Draw by stalemate!';
                                  updateGameStatus(status);
                                } else if (game.in_threefold_repetition) {
                                  status = 'Draw by threefold repetition!';
                                  updateGameStatus(status);
                                } else if (game.insufficient_material) {
                                  status =
                                  'Draw due to insufficient material!';
                                  updateGameStatus(status);
                                } else {
                                  status = 'Unexpected game status';
                                  updateGameStatus(status);
                                }

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
                            //}
                          });
                          print('Updated game state after move: ${game.fen}');
                          // Update the game state in Firebase
                          FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
                            'currentBoardState': game.fen,
                            'currentTurn': game.turn == chess.Color.WHITE ? player2UID : player1UID,  // Assuming player1UID and player2UID are available
                          });
                          print('DB game state after move: ${game.fen}');
                          updateLastMoveInFirestore(lastMoveFrom!, lastMoveTo!);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: squareColor,
                            border: border,
                          ),
                          child: Stack(
                            children: [
                              Align(
                                alignment: Alignment.center,
                                child: displayPiece(piece),
                              ),

                              // Add a circle for legal moves
                              if (isLegalMove)
                                Align(
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 10, // Adjust the size of the circle
                                    height: 10, // Adjust the size of the circle
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5), // Adjust the color and opacity as needed
                                      shape: BoxShape.circle,
                                    ),
                                  ),
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
              //),
            ),

            SizedBox(height: 20),

            Container(
              height: 50,
              child: isBoardFlipped ? _buildPlayerArea(blackCapturedPieces, true,player1Name) : _buildPlayerArea(whiteCapturedPieces, false,player2Name),
            )
          ],
        ),
      ),
    );
  }

}