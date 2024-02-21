import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;

String player1AvatarUrl = ''; // URL for player 1's avatar
String player2AvatarUrl = '';

class ChessBoardUI {
  static String getPieceAsset(chess.PieceType type, chess.Color? color) {
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
        assetPath = ''; // Return an empty string for any other cases
    }
    return assetPath.isNotEmpty ? assetPath : 'assets/default_avatar.png';
  }

  static Widget displayPiece(chess.Piece? piece) {
    if (piece != null) {
      return Image.asset(getPieceAsset(piece.type, piece.color));
    }
    return Container();
  }


  static Widget buildPlayerArea(
      Widget capturedPiecesWidget, // This now directly accepts a widget
      bool isTop,
      String playerName,
      String playerAvatarUrl,
      bool timerActive,
      int timeRemaining,
      ) {
    // Use NetworkImage for playerAvatarUrl and provide error handling
    ImageProvider imageProvider;
    try {
      imageProvider = NetworkImage(playerAvatarUrl);
    } catch (e) {
      // Fallback to a default asset image in case of error
      imageProvider = const AssetImage('assets/avatar/avatar-default.png');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Container(
        color: Colors.transparent,
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: BoxFit.cover,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(5)),
                border: Border.all(color: Colors.black, width: 1.0),
              ),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      playerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Here we directly use the capturedPiecesWidget
                  capturedPiecesWidget,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: _buildTimer(timerActive, _formatTime(timeRemaining)),
            ),
          ],
        ),
      ),
    );
  }



  static String _formatTime(int totalMilliseconds) {
    int totalSeconds = totalMilliseconds ~/ 1000; // Convert milliseconds to seconds
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  static Widget _buildTimer(bool isActive, String time) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      width: 70,
      height: 35,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey.withOpacity(0.7),
        border: Border.all(
          color: isActive ? Colors.black : Colors.grey.withOpacity(0.7),
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
}
