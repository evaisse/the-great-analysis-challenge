import 'package:chess_engine/chess_engine.dart';

class Perft {
  final Board board;
  final MoveGenerator moveGenerator;

  Perft(this.board, this.moveGenerator);

  int perft(int depth) {
    if (depth == 0) {
      return 1;
    }

    int nodes = 0;
    final moves = board.generateMoves();
    for (final move in moves) {
      final newBoard = board.clone();
      newBoard.move(move.toString());
      nodes += _perftRecursive(newBoard, depth - 1);
    }
    return nodes;
  }

  int _perftRecursive(Board board, int depth) {
    if (depth == 0) {
      return 1;
    }

    int nodes = 0;
    final moves = board.generateMoves();
    for (final move in moves) {
      final newBoard = board.clone();
      newBoard.move(move.toString());
      nodes += _perftRecursive(newBoard, depth - 1);
    }
    return nodes;
  }
}
