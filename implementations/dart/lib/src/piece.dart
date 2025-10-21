enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

class Piece {
  final PieceType type;
  final PieceColor color;

  Piece(this.type, this.color);

  factory Piece.fromChar(String char) {
    final color = char.toUpperCase() == char ? PieceColor.white : PieceColor.black;
    final type = charToType(char.toLowerCase());
    return Piece(type, color);
  }

  String toChar() {
    final char = _typeToChar(type);
    return color == PieceColor.white ? char.toUpperCase() : char.toLowerCase();
  }

  static PieceType charToType(String char) {
    switch (char) {
      case 'k':
        return PieceType.king;
      case 'q':
        return PieceType.queen;
      case 'r':
        return PieceType.rook;
      case 'b':
        return PieceType.bishop;
      case 'n':
        return PieceType.knight;
      case 'p':
        return PieceType.pawn;
      default:
        throw ArgumentError('Invalid piece character: $char');
    }
  }

  static String _typeToChar(PieceType type) {
    switch (type) {
      case PieceType.king:
        return 'k';
      case PieceType.queen:
        return 'q';
      case PieceType.rook:
        return 'r';
      case PieceType.bishop:
        return 'b';
      case PieceType.knight:
        return 'n';
      case PieceType.pawn:
        return 'p';
    }
  }
}
