import 'package:chess_engine/chess_engine.dart';

class Game {
  late List<Board> history;

  Game() {
    init();
  }

  void init() {
    history = [
      Board.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
    ];
  }

  Board get board => history.last;

  void printBoard() {
    print(board.toString());
  }

  void move(String moveStr) {
    final move = resolveMove(moveStr);

    final newBoard = board.clone();
    newBoard.move(move.toString());
    history.add(newBoard);
  }

  Move resolveMove(String moveStr) {
    final legalMoves = board.generateMoves();
    final normalized = moveStr.toLowerCase();
    for (final move in legalMoves) {
      final notation = move.toString();
      if (notation == normalized) {
        return move;
      }
      if (normalized.length == 4 &&
          move.promotion == PieceType.queen &&
          notation == '${normalized}q') {
        return move;
      }
    }
    throw Exception('ERROR: Illegal move');
  }

  void undo() {
    if (history.length > 1) {
      history.removeLast();
    }
  }

  void loadFen(String fen) {
    history = [Board.fromFen(fen)];
  }

  void export() {
    print('FEN: ${board.toFen()}');
  }

  void perft(int depth) {
    final count = board.perft(depth);
    print('Perft $depth: $count');
  }

  GameState getGameState() {
    final legalMoves = board.generateMoves();
    if (legalMoves.isNotEmpty) {
      return GameState.inProgress;
    }

    final playerColor = board.turn == 'w' ? PieceColor.white : PieceColor.black;
    if (board.isKingInCheck(playerColor)) {
      return playerColor == PieceColor.white
          ? GameState.checkmateBlackWins
          : GameState.checkmateWhiteWins;
    } else {
      return GameState.stalemate;
    }
  }
}
