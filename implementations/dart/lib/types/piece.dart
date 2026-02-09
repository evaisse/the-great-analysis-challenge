/// Type-safe piece representation using sealed classes and enums.

/// Piece color as sealed class for exhaustive pattern matching.
sealed class Color {
  const Color();
  
  Color get opposite;
  String get symbol;
  
  @override
  String toString() => symbol;
}

final class White extends Color {
  const White();
  
  @override
  Color get opposite => const Black();
  
  @override
  String get symbol => 'w';
  
  @override
  bool operator ==(Object other) => other is White;
  
  @override
  int get hashCode => 0;
}

final class Black extends Color {
  const Black();
  
  @override
  Color get opposite => const White();
  
  @override
  String get symbol => 'b';
  
  @override
  bool operator ==(Object other) => other is Black;
  
  @override
  int get hashCode => 1;
}

/// Singleton color instances.
const white = White();
const black = Black();

/// Parse color from string.
Color parseColor(String s) {
  return switch (s) {
    'w' => white,
    'b' => black,
    _ => throw ArgumentError('Invalid color: $s'),
  };
}

/// Piece type enum (still using enum for simplicity).
enum PieceType { 
  king, 
  queen, 
  rook, 
  bishop, 
  knight, 
  pawn;
  
  String get char {
    return switch (this) {
      PieceType.king => 'k',
      PieceType.queen => 'q',
      PieceType.rook => 'r',
      PieceType.bishop => 'b',
      PieceType.knight => 'n',
      PieceType.pawn => 'p',
    };
  }
  
  static PieceType fromChar(String c) {
    return switch (c.toLowerCase()) {
      'k' => PieceType.king,
      'q' => PieceType.queen,
      'r' => PieceType.rook,
      'b' => PieceType.bishop,
      'n' => PieceType.knight,
      'p' => PieceType.pawn,
      _ => throw ArgumentError('Invalid piece type: $c'),
    };
  }
}

/// Type-safe piece combining color and type.
class Piece {
  final PieceType type;
  final Color color;

  const Piece(this.type, this.color);

  factory Piece.fromChar(String char) {
    final color = char.toUpperCase() == char ? white : black;
    final type = PieceType.fromChar(char.toLowerCase());
    return Piece(type, color);
  }

  String toChar() {
    final char = type.char;
    return color is White ? char.toUpperCase() : char.toLowerCase();
  }
  
  bool get isWhite => color is White;
  bool get isBlack => color is Black;

  @override
  bool operator ==(Object other) {
    return other is Piece && type == other.type && color == other.color;
  }

  @override
  int get hashCode => Object.hash(type, color);

  @override
  String toString() => toChar();
}
