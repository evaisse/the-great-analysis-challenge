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
    int bestValue = -1000000;
    Move? bestMove;

    final moves = board.generateMoves();
    if (moves.isEmpty) {
      throw Exception('ERROR: No legal moves available');
    }

    // Sort moves for better pruning (optional, but good practice)
    // For now, let's keep it simple and deterministic
    for (final move in moves) {
      final newBoard = board.clone();
      newBoard.move(move.toString());
      final value = _minimax(
        newBoard,
        depth - 1,
        -1000000,
        1000000,
        false,
      );
      if (value > bestValue) {
        bestValue = value;
        bestMove = move;
      }
    }
    return bestMove!;
  }

  int _minimax(
    Board board,
    int depth,
    int alpha,
    int beta,
    bool maximizingPlayer,
  ) {
    if (depth == 0) {
      return evaluate(board);
    }

    final moves = board.generateMoves();
    if (moves.isEmpty) {
      final playerColor = board.turn == 'w' ? PieceColor.white : PieceColor.black;
      if (board.isKingInCheck(playerColor)) {
        return maximizingPlayer ? -100000 : 100000;
      } else {
        return 0;
      }
    }

    if (maximizingPlayer) {
      int maxEval = -1000000;
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
      int minEval = 1000000;
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

  int evaluate(Board board) {
    int score = 0;
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
    // Return score from the perspective of the player whose turn it was at the START of search
    // Actually, evaluation is usually absolute (White positive, Black negative)
    return score;
  }
}