import 'piece.dart';
import 'board.dart';

class Zobrist {
  static final Zobrist instance = Zobrist._();

  final List<List<int>> pieces = List.generate(12, (_) => List.filled(64, 0));
  late final int sideToMove;
  final List<int> castling = List.filled(4, 0);
  final List<int> enPassant = List.filled(8, 0);

  Zobrist._() {
    int state = 0x123456789ABCDEF0;
    const mask64 = 0xFFFFFFFFFFFFFFFF;

    int nextRand() {
      state ^= (state << 13) & mask64;
      state ^= (state >> 7);
      state ^= (state << 17) & mask64;
      return state;
    }

    for (int p = 0; p < 12; p++) {
      for (int s = 0; s < 64; s++) {
        pieces[p][s] = nextRand();
      }
    }

    sideToMove = nextRand();

    for (int i = 0; i < 4; i++) {
      castling[i] = nextRand();
    }

    for (int i = 0; i < 8; i++) {
      enPassant[i] = nextRand();
    }
  }

  int getPieceIndex(Piece piece) {
    int idx = 0;
    switch (piece.type) {
      case PieceType.pawn: idx = 0; break;
      case PieceType.knight: idx = 1; break;
      case PieceType.bishop: idx = 2; break;
      case PieceType.rook: idx = 3; break;
      case PieceType.queen: idx = 4; break;
      case PieceType.king: idx = 5; break;
    }
    if (piece.color == PieceColor.black) {
      idx += 6;
    }
    return idx;
  }

  int computeHash(Board board) {
    int hashVal = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board.squares[row][col];
        if (piece != null) {
          final square = row * 8 + col;
          final idx = getPieceIndex(piece);
          hashVal ^= pieces[idx][square];
        }
      }
    }

    if (board.turn == 'b') {
      hashVal ^= sideToMove;
    }

    final rights = board.get_castlingRights_internal();
    if (rights.contains('K')) hashVal ^= castling[0];
    if (rights.contains('Q')) hashVal ^= castling[1];
    if (rights.contains('k')) hashVal ^= castling[2];
    if (rights.contains('q')) hashVal ^= castling[3];

    final epTarget = board.get_enPassantTarget_internal();
    if (epTarget != null) {
      hashVal ^= enPassant[epTarget.col];
    }

    return hashVal;
  }
}
