import 'package:chess_engine/chess_engine.dart';
import 'board.dart';

class Zobrist {
  static final Zobrist instance = Zobrist._();

  late List<List<int>> pieces;
  late int sideToMove;
  late List<int> castling;
  late List<int> enPassant;

  Zobrist._() {
    pieces = List.generate(12, (_) => List.filled(64, 0));
    castling = List.filled(4, 0);
    enPassant = List.filled(8, 0);

    int state = 0x123456789ABCDEF0;
    const mask64 = 0xFFFFFFFFFFFFFFFF;

    int next() {
      state ^= (state << 13) & mask64;
      state ^= (state >>> 7) & mask64;
      state ^= (state << 17) & mask64;
      return state & mask64;
    }

    for (int p = 0; p < 12; p++) {
      for (int s = 0; s < 64; s++) {
        pieces[p][s] = next();
      }
    }

    sideToMove = next();

    for (int i = 0; i < 4; i++) {
      castling[i] = next();
    }

    for (int i = 0; i < 8; i++) {
      enPassant[i] = next();
    }
  }

  int getPieceIndex(Piece piece) {
    int idx;
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
    int hash = 0;
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final piece = board.squares[row][col];
        if (piece != null) {
          final square = (7 - row) * 8 + col;
          hash ^= pieces[getPieceIndex(piece)][square];
        }
      }
    }

    if (board.turn == 'b') {
      hash ^= sideToMove;
    }

    final rights = board.castlingRights;
    if (rights.contains('K')) hash ^= castling[0];
    if (rights.contains('Q')) hash ^= castling[1];
    if (rights.contains('k')) hash ^= castling[2];
    if (rights.contains('q')) hash ^= castling[3];

    final ep = board.enPassantTarget;
    if (ep != null) {
      hash ^= enPassant[ep.col];
    }

    return hash;
  }
}

extension BoardRights on Board {
  String get castlingRights => get_castlingRights_internal();
  ({int row, int col})? get enPassantTarget => get_enPassantTarget_internal();
}
