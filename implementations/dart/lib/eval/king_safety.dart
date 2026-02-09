import 'package:chess_engine/chess_engine.dart';

const int pawnShieldBonus = 20;
const int openFilePenalty = -30;
const int semiOpenFilePenalty = -15;
const int attackerWeight = 10;

int evaluate(Board board) {
  int score = 0;
  
  score += _evaluate_king_safety(board, PieceColor.white);
  score -= _evaluate_king_safety(board, PieceColor.black);
  
  return score;
}

int _evaluate_king_safety(Board board, PieceColor color) {
  final kingSquare = _find_king(board, color);
  if (kingSquare == null) {
    return 0;
  }
  
  int score = 0;
  
  score += _evaluate_pawn_shield(board, kingSquare, color);
  score += _evaluate_open_files(board, kingSquare, color);
  score -= _evaluate_attackers(board, kingSquare, color);
  
  return score;
}

int? _find_king(Board board, PieceColor color) {
  for (int square = 0; square < 64; square++) {
    final row = square ~/ 8;
    final col = square % 8;
    final piece = board.squares[row][col];
    
    if (piece != null && piece.color == color && piece.type == PieceType.king) {
      return square;
    }
  }
  return null;
}

int _evaluate_pawn_shield(Board board, int kingSquare, PieceColor color) {
  final kingFile = kingSquare % 8;
  final kingRank = kingSquare ~/ 8;
  int shieldCount = 0;
  
  final shieldRanks = color == PieceColor.white
      ? [kingRank + 1, kingRank + 2]
      : [(kingRank - 1).clamp(0, 7), (kingRank - 2).clamp(0, 7)];
  
  for (int file = (kingFile - 1).clamp(0, 7); file <= (kingFile + 1).clamp(0, 7); file++) {
    for (final rank in shieldRanks) {
      if (rank < 8) {
        final square = rank * 8 + file;
        final row = square ~/ 8;
        final col = square % 8;
        final piece = board.squares[row][col];
        
        if (piece != null && piece.color == color && piece.type == PieceType.pawn) {
          shieldCount++;
        }
      }
    }
  }
  
  return shieldCount * pawnShieldBonus;
}

int _evaluate_open_files(Board board, int kingSquare, PieceColor color) {
  final kingFile = kingSquare % 8;
  int penalty = 0;
  
  for (int file = (kingFile - 1).clamp(0, 7); file <= (kingFile + 1).clamp(0, 7); file++) {
    final pawns = _count_pawns_on_file(board, file, color);
    final ownPawns = pawns.$1;
    final enemyPawns = pawns.$2;
    
    if (ownPawns == 0 && enemyPawns == 0) {
      penalty += openFilePenalty;
    } else if (ownPawns == 0) {
      penalty += semiOpenFilePenalty;
    }
  }
  
  return penalty;
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

int _evaluate_attackers(Board board, int kingSquare, PieceColor color) {
  final kingFile = kingSquare % 8;
  final kingRank = kingSquare ~/ 8;
  int attackerCount = 0;
  
  const adjacentSquares = [
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1),           (0, 1),
    (1, -1),  (1, 0),  (1, 1),
  ];
  
  for (final offset in adjacentSquares) {
    final newRank = kingRank + offset.$1;
    final newFile = kingFile + offset.$2;
    
    if (newRank >= 0 && newRank < 8 && newFile >= 0 && newFile < 8) {
      final targetSquare = newRank * 8 + newFile;
      if (_is_attacked_by_enemy(board, targetSquare, color)) {
        attackerCount++;
      }
    }
  }
  
  return attackerCount * attackerWeight;
}

bool _is_attacked_by_enemy(Board board, int square, PieceColor color) {
  for (int attackerSquare = 0; attackerSquare < 64; attackerSquare++) {
    final row = attackerSquare ~/ 8;
    final col = attackerSquare % 8;
    final piece = board.squares[row][col];
    
    if (piece != null && piece.color != color) {
      if (_can_attack(board, attackerSquare, square, piece.type, piece.color)) {
        return true;
      }
    }
  }
  return false;
}

bool _can_attack(Board board, int from, int to, PieceType pieceType, PieceColor color) {
  final fromRank = from ~/ 8;
  final fromFile = from % 8;
  final toRank = to ~/ 8;
  final toFile = to % 8;
  final rankDiff = (toRank - fromRank).abs();
  final fileDiff = (toFile - fromFile).abs();
  
  switch (pieceType) {
    case PieceType.pawn:
      final forward = color == PieceColor.white ? 1 : -1;
      return toRank - fromRank == forward && fileDiff == 1;
    case PieceType.knight:
      return (rankDiff == 2 && fileDiff == 1) || (rankDiff == 1 && fileDiff == 2);
    case PieceType.king:
      return rankDiff <= 1 && fileDiff <= 1;
    default:
      return false;
  }
}
