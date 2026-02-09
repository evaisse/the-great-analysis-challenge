import 'package:chess_engine/chess_engine.dart';

const int bishopPairBonus = 30;
const int rookOpenFileBonus = 25;
const int rookSemiOpenFileBonus = 15;
const int rookSeventhRankBonus = 20;
const int knightOutpostBonus = 20;

int evaluate(Board board) {
  int score = 0;
  
  score += _evaluate_color(board, PieceColor.white);
  score -= _evaluate_color(board, PieceColor.black);
  
  return score;
}

int _evaluate_color(Board board, PieceColor color) {
  int score = 0;
  
  if (_has_bishop_pair(board, color)) {
    score += bishopPairBonus;
  }
  
  for (int square = 0; square < 64; square++) {
    final row = square ~/ 8;
    final col = square % 8;
    final piece = board.squares[row][col];
    
    if (piece != null && piece.color == color) {
      switch (piece.type) {
        case PieceType.rook:
          score += _evaluate_rook(board, square, color);
          break;
        case PieceType.knight:
          score += _evaluate_knight(board, square, color);
          break;
        default:
          break;
      }
    }
  }
  
  return score;
}

bool _has_bishop_pair(Board board, PieceColor color) {
  int bishopCount = 0;
  
  for (int square = 0; square < 64; square++) {
    final row = square ~/ 8;
    final col = square % 8;
    final piece = board.squares[row][col];
    
    if (piece != null && piece.color == color && piece.type == PieceType.bishop) {
      bishopCount++;
    }
  }
  
  return bishopCount >= 2;
}

int _evaluate_rook(Board board, int square, PieceColor color) {
  final file = square % 8;
  final rank = square ~/ 8;
  int bonus = 0;
  
  final pawns = _count_pawns_on_file(board, file, color);
  final ownPawns = pawns.$1;
  final enemyPawns = pawns.$2;
  
  if (ownPawns == 0 && enemyPawns == 0) {
    bonus += rookOpenFileBonus;
  } else if (ownPawns == 0) {
    bonus += rookSemiOpenFileBonus;
  }
  
  final seventhRank = color == PieceColor.white ? 6 : 1;
  if (rank == seventhRank) {
    bonus += rookSeventhRankBonus;
  }
  
  return bonus;
}

int _evaluate_knight(Board board, int square, PieceColor color) {
  if (_is_outpost(board, square, color)) {
    return knightOutpostBonus;
  } else {
    return 0;
  }
}

bool _is_outpost(Board board, int square, PieceColor color) {
  final file = square % 8;
  final rank = square ~/ 8;
  
  final protectedByPawn = _is_protected_by_pawn(board, square, color);
  if (!protectedByPawn) {
    return false;
  }
  
  final cannotBeAttacked = !_can_be_attacked_by_enemy_pawn(board, square, file, rank, color);
  
  return protectedByPawn && cannotBeAttacked;
}

bool _is_protected_by_pawn(Board board, int square, PieceColor color) {
  final file = square % 8;
  final rank = square ~/ 8;
  
  final behindRank = color == PieceColor.white
      ? (rank - 1).clamp(0, 7)
      : (rank + 1).clamp(0, 7);
  
  for (final adjacentFile in [(file - 1).clamp(0, 7), (file + 1).clamp(0, 7)]) {
    if (adjacentFile != file) {
      final checkSquare = behindRank * 8 + adjacentFile;
      final row = checkSquare ~/ 8;
      final col = checkSquare % 8;
      final piece = board.squares[row][col];
      
      if (piece != null && piece.color == color && piece.type == PieceType.pawn) {
        return true;
      }
    }
  }
  
  return false;
}

bool _can_be_attacked_by_enemy_pawn(Board board, int square, int file, int rank, PieceColor color) {
  final aheadRanks = color == PieceColor.white
      ? List<int>.generate(8 - rank - 1, (i) => rank + 1 + i)
      : List<int>.generate(rank, (i) => i);
  
  for (final checkRank in aheadRanks) {
    for (final adjacentFile in [(file - 1).clamp(0, 7), (file + 1).clamp(0, 7)]) {
      if (adjacentFile != file) {
        final checkSquare = checkRank * 8 + adjacentFile;
        final row = checkSquare ~/ 8;
        final col = checkSquare % 8;
        final piece = board.squares[row][col];
        
        if (piece != null && piece.color != color && piece.type == PieceType.pawn) {
          return true;
        }
      }
    }
  }
  
  return false;
}

(int, int) _count_pawns_on_file(Board board, int file, PieceColor color) {
  int ownPawns = 0;
  int enemyPawns = 0;
  
  for (int rank = 0; rank < 8; rank++) {
    final square = rank * 8 + file;
    final row = square ~/ 8;
    final col = square % 8;
    final piece = board.squares[row][col];
    
    if (piece != null && piece.type == PieceType.pawn) {
      if (piece.color == color) {
        ownPawns++;
      } else {
        enemyPawns++;
      }
    }
  }
  
  return (ownPawns, enemyPawns);
}
