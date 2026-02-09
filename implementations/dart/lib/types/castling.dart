/// Type-safe castling rights representation.

import 'piece.dart';

/// Represents castling rights for both sides.
class CastlingRights {
  final bool whiteKingside;
  final bool whiteQueenside;
  final bool blackKingside;
  final bool blackQueenside;
  
  const CastlingRights({
    required this.whiteKingside,
    required this.whiteQueenside,
    required this.blackKingside,
    required this.blackQueenside,
  });
  
  /// All castling rights available.
  static const all = CastlingRights(
    whiteKingside: true,
    whiteQueenside: true,
    blackKingside: true,
    blackQueenside: true,
  );
  
  /// No castling rights.
  static const none = CastlingRights(
    whiteKingside: false,
    whiteQueenside: false,
    blackKingside: false,
    blackQueenside: false,
  );
  
  /// Parse from FEN castling string (e.g., "KQkq").
  factory CastlingRights.fromFen(String fen) {
    if (fen == '-') return none;
    
    return CastlingRights(
      whiteKingside: fen.contains('K'),
      whiteQueenside: fen.contains('Q'),
      blackKingside: fen.contains('k'),
      blackQueenside: fen.contains('q'),
    );
  }
  
  /// Convert to FEN castling string.
  String toFen() {
    if (!whiteKingside && !whiteQueenside && !blackKingside && !blackQueenside) {
      return '-';
    }
    
    final buffer = StringBuffer();
    if (whiteKingside) buffer.write('K');
    if (whiteQueenside) buffer.write('Q');
    if (blackKingside) buffer.write('k');
    if (blackQueenside) buffer.write('q');
    return buffer.toString();
  }
  
  /// Check if kingside castling is available for a color.
  bool canCastleKingside(Color color) {
    return color is White ? whiteKingside : blackKingside;
  }
  
  /// Check if queenside castling is available for a color.
  bool canCastleQueenside(Color color) {
    return color is White ? whiteQueenside : blackQueenside;
  }
  
  /// Remove kingside castling rights for a color.
  CastlingRights removeKingside(Color color) {
    return color is White
        ? CastlingRights(
            whiteKingside: false,
            whiteQueenside: whiteQueenside,
            blackKingside: blackKingside,
            blackQueenside: blackQueenside,
          )
        : CastlingRights(
            whiteKingside: whiteKingside,
            whiteQueenside: whiteQueenside,
            blackKingside: false,
            blackQueenside: blackQueenside,
          );
  }
  
  /// Remove queenside castling rights for a color.
  CastlingRights removeQueenside(Color color) {
    return color is White
        ? CastlingRights(
            whiteKingside: whiteKingside,
            whiteQueenside: false,
            blackKingside: blackKingside,
            blackQueenside: blackQueenside,
          )
        : CastlingRights(
            whiteKingside: whiteKingside,
            whiteQueenside: whiteQueenside,
            blackKingside: blackKingside,
            blackQueenside: false,
          );
  }
  
  /// Remove all castling rights for a color.
  CastlingRights removeAll(Color color) {
    return color is White
        ? CastlingRights(
            whiteKingside: false,
            whiteQueenside: false,
            blackKingside: blackKingside,
            blackQueenside: blackQueenside,
          )
        : CastlingRights(
            whiteKingside: whiteKingside,
            whiteQueenside: whiteQueenside,
            blackKingside: false,
            blackQueenside: false,
          );
  }
  
  @override
  bool operator ==(Object other) {
    return other is CastlingRights &&
        whiteKingside == other.whiteKingside &&
        whiteQueenside == other.whiteQueenside &&
        blackKingside == other.blackKingside &&
        blackQueenside == other.blackQueenside;
  }
  
  @override
  int get hashCode => Object.hash(whiteKingside, whiteQueenside, blackKingside, blackQueenside);
  
  @override
  String toString() => toFen();
}
