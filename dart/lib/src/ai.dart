import 'dart:math';

import 'package:chess_engine/chess_engine.dart';

class AI {
  static const _materialValues = {
    PieceType.pawn: 100,
    PieceType.knight: 320,
    PieceType.bishop: 330,
    PieceType.rook: 500,
    PieceType.queen: 900,
    PieceType.king: 20000,
  };

  Move findBestMove(Board board, int depth) {
    double bestValue = double.negativeInfinity;
    Move? bestMove;

    for (final move in board.generateMoves()) {
      final newBoard = board.clone();
      newBoard.move(move.toString());
      final value = _minimax(newBoard, depth - 1, double.negativeInfinity, double.infinity, false);
      if (value > bestValue) {
        bestValue = value;
        bestMove = move;
      }
    }
    return bestMove!;
  }

  double _minimax(Board board, int depth, double alpha, double beta, bool maximizingPlayer) {
    if (depth == 0) {
      return evaluate(board);
    }

    final moves = board.generateMoves();
    if (moves.isEmpty) {
      // TODO: Check for checkmate/stalemate
      return 0;
    }

    if (maximizingPlayer) {
      double maxEval = double.negativeInfinity;
      for (final move in moves) {
        final newBoard = board.clone();
        newBoard.move(move.toString());
        final eval = _minimax(newBoard, depth - 1, alpha, beta, false);
        maxEval = max(maxEval, eval);
        alpha = max(alpha, eval);
        if (beta <= alpha) {
          break;
        }
      }
      return maxEval;
    } else {
      double minEval = double.infinity;
      for (final move in moves) {
        final newBoard = board.clone();
        newBoard.move(move.toString());
        final eval = _minimax(newBoard, depth - 1, alpha, beta, true);
        minEval = min(minEval, eval);
        beta = min(beta, eval);
        if (beta <= alpha) {
          break;
        }
      }
      return minEval;
    }
  }

  double evaluate(Board board) {
    double score = 0;
    for (int i = 0; i < 8; i++) {
      for (int j = 0; j < 8; j++) {
        final piece = board.squares[i][j];
        if (piece != null) {
          final value = _materialValues[piece.type]!;
          if (piece.color == PieceColor.white) {
            score += value;
          } else {
            score -= value;
          }
        }
      }
    }
    return score;
  }
}
