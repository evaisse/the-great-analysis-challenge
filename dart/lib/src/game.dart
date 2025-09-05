import 'package:collection/collection.dart';
import 'package:chess_engine/chess_engine.dart';

class Game {
  late List<Board> history;

  Game() {
    init();
  }

  void init() {
    history = [Board.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')];
  }

  Board get board => history.last;

  void printBoard() {
    print(board.toString());
  }

  void move(String moveStr) {
    final legalMoves = board.generateMoves();
    final move = legalMoves.firstWhereOrNull((m) => m.toString() == moveStr);

    if (move == null) {
      throw Exception('ERROR: Illegal move');
    }

    final newBoard = board.clone();
    newBoard.move(move.toString());
    history.add(newBoard);
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
      return playerColor == PieceColor.white ? GameState.checkmateBlackWins : GameState.checkmateWhiteWins;
    } else {
      return GameState.stalemate;
    }
  }
