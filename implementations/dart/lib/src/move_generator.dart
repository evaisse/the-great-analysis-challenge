import 'package:chess_engine/chess_engine.dart';

class MoveGenerator {
  final Board board;

  MoveGenerator(this.board);

  List<Move> generateLegalMoves() {
    return board.generateMoves();
  }

  bool isCheckmate() {
    final playerColor = board.turn == 'w' ? PieceColor.white : PieceColor.black;
    return board.isKingInCheck(playerColor) && board.generateMoves().isEmpty;
  }

  bool isStalemate() {
    final playerColor = board.turn == 'w' ? PieceColor.white : PieceColor.black;
    return !board.isKingInCheck(playerColor) && board.generateMoves().isEmpty;
  }
}
