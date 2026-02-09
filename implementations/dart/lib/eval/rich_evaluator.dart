import 'package:chess_engine/chess_engine.dart';
import 'tables.dart' as tables;
import 'tapered.dart' as tapered;
import 'mobility.dart' as mobility;
import 'pawn_structure.dart' as pawn_structure;
import 'king_safety.dart' as king_safety;
import 'positional.dart' as positional;

class RichEvaluator {
  RichEvaluator();

  int evaluate(Board board) {
    final phase = _compute_phase(board);
    
    final mgScore = _evaluate_phase(board, true);
    final egScore = _evaluate_phase(board, false);
    
    final taperedScore = tapered.interpolate(mgScore, egScore, phase);
    
    final mobilityScore = mobility.evaluate(board);
    final pawnScore = pawn_structure.evaluate(board);
    final kingScore = king_safety.evaluate(board);
    final positionalScore = positional.evaluate(board);
    
    return taperedScore + mobilityScore + pawnScore + kingScore + positionalScore;
  }

  int _compute_phase(Board board) {
    int phase = 0;
    for (int square = 0; square < 64; square++) {
      final row = square ~/ 8;
      final col = square % 8;
      final piece = board.squares[row][col];
      
      if (piece != null) {
        phase += switch (piece.type) {
          PieceType.knight => 1,
          PieceType.bishop => 1,
          PieceType.rook => 2,
          PieceType.queen => 4,
          _ => 0,
        };
      }
    }
    
    return phase < 24 ? phase : 24;
  }

  int _evaluate_phase(Board board, bool middlegame) {
    int score = 0;
    
    for (int square = 0; square < 64; square++) {
      final row = square ~/ 8;
      final col = square % 8;
      final piece = board.squares[row][col];
      
      if (piece != null) {
        final value = _piece_value(piece.type);
        final positionBonus = middlegame
            ? tables.get_middlegame_bonus(square, piece.type, piece.color)
            : tables.get_endgame_bonus(square, piece.type, piece.color);
        
        final totalValue = value + positionBonus;
        score += piece.color == PieceColor.white ? totalValue : -totalValue;
      }
    }
    
    return score;
  }

  int _piece_value(PieceType type) {
    return switch (type) {
      PieceType.pawn => 100,
      PieceType.knight => 320,
      PieceType.bishop => 330,
      PieceType.rook => 500,
      PieceType.queen => 900,
      PieceType.king => 20000,
    };
  }
}
