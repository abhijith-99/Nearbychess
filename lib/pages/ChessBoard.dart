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
      'whiteCapturedPieces': whiteCapturedPieces, // Assuming this is a List<String>
      'blackCapturedPieces': blackCapturedPieces, // Assuming this is a List<String>
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

    pgnNotation += move + ' ';

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

        // Fetch player1's avatar
        var player1Doc = await FirebaseFirestore.instance.collection('users').doc(player1UID).get();
        var player1Data = player1Doc.data();
        String player1AvatarUrl = player1Data?['avatar'] ?? ''; // Default or placeholder URL if not found

        // Fetch player2's avatar
        var player2Doc = await FirebaseFirestore.instance.collection('users').doc(player2UID).get();
        var player2Data = player2Doc.data();
        String player2AvatarUrl = player2Data?['avatar'] ?? ''; // Default or placeholder URL if not found

        // Update the board state based on new FEN
        setState(() {
          game.load(newFen); // Assuming 'game' is your chess library instance
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
        } else {
          if (_blackTimeRemaining > 0) {
            _blackTimeRemaining--;
          } else {
            timer.cancel();
            _handleTimeout(chess.Color.BLACK);
          }
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
              setState(() {
                game.reset();
                whiteCapturedPieces.clear();
                blackCapturedPieces.clear();
                _whiteTimeRemaining = 600; // Reset the timer
                _blackTimeRemaining = 600; // Reset the timer
                _startTimer(); // Restart the timer for the new game
              });
            },
            child: const Text('Restart'),
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


  Widget _buildPlayerArea(List<String> capturedPieces, bool isTop) {
    String avatarUrl = isTop ? player1AvatarUrl : player2AvatarUrl;
    return Container(
      color: Colors.grey[200], // Just for visibility, adjust the color as needed
      height: 50, // Adjust the height as needed
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Timer and captured pieces area
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: capturedPieces.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Image.asset(
                    capturedPieces[index],
                    fit: BoxFit.cover,
                    height: 50, // Half the square size, adjust as needed
                  ),
                );
              },
            ),
          ),
          // Timer display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Text(
              isTop ? _formatTime(_blackTimeRemaining) : _formatTime(_whiteTimeRemaining),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, // Adjust font size as needed
              ),
            ),
          ),
          // Placeholder for circle, replace with actual circle widget if needed
          Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(2),
            child: CircleAvatar(
              backgroundImage: AssetImage(avatarUrl), // Assuming avatarUrl is a valid network image URL
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
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
      appBar: AppBar(
        title: const Text(
          'Au-Ki Chess',
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0), // Set the height
          child: Container(
            color: Colors.grey[200], // Choose an appropriate color
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(pgnNotation, style: TextStyle(fontSize: 16)), // Display PGN notation
              ),
            ),
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Align items to the center
        children: [

          // _buildPlayerArea(blackCapturedPieces, true),
          isBoardFlipped ? _buildPlayerArea(whiteCapturedPieces, false) : _buildPlayerArea(blackCapturedPieces, true),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8,),
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

                      Color colorA = const Color(0xFFA09B9B);
                      Color colorB = const Color(0xFFEFE8E8);

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
                        squareColor = Colors.lightBlue.withOpacity(0.3); // Adjust the color and opacity as needed
                      }



                      return GestureDetector(
                        onTap: () {

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
                                } else if (game.in_stalemate) {
                                  status = 'Draw by stalemate!';
                                } else if (game.in_threefold_repetition) {
                                  status = 'Draw by threefold repetition!';
                                } else if (game.insufficient_material) {
                                  status =
                                  'Draw due to insufficient material!';
                                } else {
                                  status = 'Unexpected game status';
                                }

                                // Show dialog for checkmate or draw
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Game Over'),
                                    content: Text(status),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          setState(() {
                                            game.reset();
                                            whiteCapturedPieces.clear();
                                            blackCapturedPieces.clear();
                                          });
                                        },
                                        child: const Text('Restart'),
                                      ),
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
                          print('Updated game state: ${game.fen}');
                          String currentFen = game.fen;  // Generate FEN string of the current state

                          // Update the game state in Firebase
                          FirebaseFirestore.instance.collection('games').doc(widget.gameId).update({
                            'currentBoardState': currentFen,
                            'currentTurn': game.turn == chess.Color.WHITE ? player2UID : player1UID,  // Assuming player1UID and player2UID are available
                          });

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
                    //itemCount: 64,
                  ),
                ),
              ),
            ),
          ),
          // _buildPlayerArea(whiteCapturedPieces, false), // Bottom area for white player
          isBoardFlipped ? _buildPlayerArea(blackCapturedPieces, true) : _buildPlayerArea(whiteCapturedPieces, false),
        ],
      ),
    );
  }

}