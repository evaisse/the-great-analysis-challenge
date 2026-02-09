import 'package:chess_engine/chess_engine.dart';
import 'dart:math' as math;

const List<int> knightMobility = [-15, -5, 0, 5, 10, 15, 20, 22, 24];
const List<int> bishopMobility = [-20, -10, 0, 5, 10, 15, 18, 21, 24, 26, 28, 30, 32, 34];
const List<int> rookMobility = [-15, -8, 0, 3, 6, 9, 12, 14, 16, 18, 20, 22, 24, 26, 28];
const List<int> queenMobility = [
  -10, -5, 0, 2, 4, 6, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 22, 23, 23, 24, 24, 25, 25, 26, 26
];

int evaluate(Board board) {
  int score = 0;
  
  for (int square = 0; square < 64; square++) {
    final row = square ~/ 8;
    final col = square % 8;
    final piece = board.squares[row][col];
    
    if (piece != null) {
      int mobility;
      switch (piece.type) {
        case PieceType.knight:
          mobility = _count_knight_mobility(board, square, piece.color);
          break;
        case PieceType.bishop:
          mobility = _count_bishop_mobility(board, square, piece.color);
          break;
        case PieceType.rook:
          mobility = _count_rook_mobility(board, square, piece.color);
          break;
        case PieceType.queen:
          mobility = _count_queen_mobility(board, square, piece.color);
          break;
        default:
          continue;
      }
      
      final bonus = _get_mobility_bonus(piece.type, mobility);
      score += piece.color == PieceColor.white ? bonus : -bonus;
    }
  }
  
  return score;
}

int _count_knight_mobility(Board board, int square, PieceColor color) {
  const offsets = [
    (-2, -1), (-2, 1), (-1, -2), (-1, 2),
    (1, -2), (1, 2), (2, -1), (2, 1),
  ];
  
  final rank = square ~/ 8;
  final file = square % 8;
  int count = 0;
  
  for (final offset in offsets) {
    final newRank = rank + offset.$1;
    final newFile = file + offset.$2;
    
    if (newRank >= 0 && newRank < 8 && newFile >= 0 && newFile < 8) {
      final targetPiece = board.squares[newRank][newFile];
      if (targetPiece == null || targetPiece.color != color) {
        count++;
      }
    }
  }
  
  return count;
}

int _count_bishop_mobility(Board board, int square, PieceColor color) {
  return _count_sliding_mobility(board, square, color, const [
    (1, 1), (1, -1), (-1, 1), (-1, -1)
  ]);
}

int _count_rook_mobility(Board board, int square, PieceColor color) {
  return _count_sliding_mobility(board, square, color, const [
    (0, 1), (0, -1), (1, 0), (-1, 0)
  ]);
}

int _count_queen_mobility(Board board, int square, PieceColor color) {
  return _count_sliding_mobility(board, square, color, const [
    (0, 1), (0, -1), (1, 0), (-1, 0),
    (1, 1), (1, -1), (-1, 1), (-1, -1),
  ]);
}

int _count_sliding_mobility(Board board, int square, PieceColor color, List<(int, int)> directions) {
  final rank = square ~/ 8;
  final file = square % 8;
  int count = 0;
  
  for (final direction in directions) {
    int currentRank = rank + direction.$1;
    int currentFile = file + direction.$2;
    
    while (currentRank >= 0 && currentRank < 8 && currentFile >= 0 && currentFile < 8) {
      final targetPiece = board.squares[currentRank][currentFile];
      
      if (targetPiece != null) {
        if (targetPiece.color != color) {
          count++;
        }
        break;
      } else {
        count++;
      }
      
      currentRank += direction.$1;
      currentFile += direction.$2;
    }
  }
  
  return count;
}

int _get_mobility_bonus(PieceType pieceType, int mobility) {
  switch (pieceType) {
    case PieceType.knight:
      return knightMobility[math.min(mobility, 8)];
    case PieceType.bishop:
      return bishopMobility[math.min(mobility, 13)];
    case PieceType.rook:
      return rookMobility[math.min(mobility, 14)];
    case PieceType.queen:
      return queenMobility[math.min(mobility, 27)];
    default:
      return 0;
  }
}
