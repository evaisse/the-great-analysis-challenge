import 'package:chess_engine/chess_engine.dart';

const List<int> passedPawnBonus = [0, 10, 20, 40, 60, 90, 120, 0];
const int doubledPawnPenalty = -20;
const int isolatedPawnPenalty = -15;
const int backwardPawnPenalty = -10;
const int connectedPawnBonus = 5;
const int pawnChainBonus = 10;

int evaluate(Board board) {
  int score = 0;
  
  score += _evaluate_color(board, PieceColor.white);
  score -= _evaluate_color(board, PieceColor.black);
  
  return score;
}

int _evaluate_color(Board board, PieceColor color) {
  int score = 0;
  final pawnFiles = List<int>.filled(8, 0);
  final pawnPositions = <(int, int, int)>[];
  
  for (int square = 0; square < 64; square++) {
    final row = square ~/ 8;
    final col = square % 8;
    final piece = board.squares[row][col];
    
    if (piece != null && piece.color == color && piece.type == PieceType.pawn) {
      final file = square % 8;
      final rank = square ~/ 8;
      pawnFiles[file]++;
      pawnPositions.add((square, rank, file));
    }
  }
  
  for (final pawn in pawnPositions) {
    final square = pawn.$1;
    final rank = pawn.$2;
    final file = pawn.$3;
    
    if (pawnFiles[file] > 1) {
      score += doubledPawnPenalty;
    }
    
    if (_is_isolated(file, pawnFiles)) {
      score += isolatedPawnPenalty;
    }
    
    if (_is_passed(board, square, rank, file, color)) {
      final bonusRank = color == PieceColor.white ? rank : 7 - rank;
      score += passedPawnBonus[bonusRank];
    }
    
    if (_is_connected(board, square, file, color)) {
      score += connectedPawnBonus;
    }
    
    if (_is_in_chain(board, square, rank, file, color)) {
      score += pawnChainBonus;
    }
    
    if (_is_backward(board, square, rank, file, color, pawnFiles)) {
      score += backwardPawnPenalty;
    }
  }
  
  return score;
}

bool _is_isolated(int file, List<int> pawnFiles) {
  final leftFile = file > 0 ? pawnFiles[file - 1] : 0;
  final rightFile = file < 7 ? pawnFiles[file + 1] : 0;
  return leftFile == 0 && rightFile == 0;
}

bool _is_passed(Board board, int square, int rank, int file, PieceColor color) {
  final startRank = color == PieceColor.white ? rank + 1 : 0;
  final endRank = color == PieceColor.white ? 8 : rank;
  
  for (int checkFile = (file - 1).clamp(0, 7); checkFile <= (file + 1).clamp(0, 7); checkFile++) {
    for (int currentRank = startRank; 
         color == PieceColor.white ? currentRank < endRank : currentRank < rank; 
         currentRank++) {
      final checkSquare = currentRank * 8 + checkFile;
      final row = checkSquare ~/ 8;
      final col = checkSquare % 8;
      final piece = board.squares[row][col];
      
      if (piece != null && piece.type == PieceType.pawn && piece.color != color) {
        return false;
      }
    }
  }
  
  return true;
}

bool _is_connected(Board board, int square, int file, PieceColor color) {
  final rank = square ~/ 8;
  
  for (final adjacentFile in [(file - 1).clamp(0, 7), (file + 1).clamp(0, 7)]) {
    if (adjacentFile != file) {
      final adjacentSquare = rank * 8 + adjacentFile;
      final row = adjacentSquare ~/ 8;
      final col = adjacentSquare % 8;
      final piece = board.squares[row][col];
      
      if (piece != null && piece.color == color && piece.type == PieceType.pawn) {
        return true;
      }
    }
  }
  
  return false;
}

bool _is_in_chain(Board board, int square, int rank, int file, PieceColor color) {
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

bool _is_backward(Board board, int square, int rank, int file, PieceColor color, List<int> pawnFiles) {
  final leftFile = (file - 1).clamp(0, 7);
  final rightFile = (file + 1).clamp(0, 7);
  
  for (final adjacentFile in [leftFile, rightFile]) {
    if (adjacentFile != file && pawnFiles[adjacentFile] > 0) {
      for (int checkSquare = 0; checkSquare < 64; checkSquare++) {
        final row = checkSquare ~/ 8;
        final col = checkSquare % 8;
        final piece = board.squares[row][col];
        
        if (piece != null && piece.color == color && piece.type == PieceType.pawn) {
          final checkFile = checkSquare % 8;
          final checkRank = checkSquare ~/ 8;
          
          if (checkFile == adjacentFile) {
            final isAhead = color == PieceColor.white
                ? checkRank > rank
                : checkRank < rank;
            
            if (isAhead) {
              return false;
            }
          }
        }
      }
    }
  }
  
  return false;
}
