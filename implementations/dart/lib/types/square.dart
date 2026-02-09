/// Type-safe Square representation using Dart 3 extension types.
/// Guarantees values are in range 0-63.

/// Extension type for a chess board square (0-63).
/// Uses Dart 3's extension types for zero-cost abstraction.
extension type const Square._(int value) {
  /// Creates a Square from a validated integer (0-63).
  Square(int v) : value = v {
    if (v < 0 || v >= 64) {
      throw ArgumentError('Square must be 0-63, got $v');
    }
  }

  /// Creates a Square from algebraic notation (e.g., "e4").
  factory Square.fromAlgebraic(String algebraic) {
    if (algebraic.length != 2) {
      throw ArgumentError('Invalid algebraic notation: $algebraic');
    }
    final file = algebraic.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(algebraic.substring(1)) - 1;
    if (file < 0 || file >= 8 || rank < 0 || rank >= 8) {
      throw ArgumentError('Invalid square: $algebraic');
    }
    return Square(rank * 8 + file);
  }

  /// Creates a Square from row/col coordinates (internal representation).
  factory Square.fromRowCol(int row, int col) {
    if (row < 0 || row >= 8 || col < 0 || col >= 8) {
      throw ArgumentError('Row/col must be 0-7, got ($row, $col)');
    }
    return Square(row * 8 + col);
  }

  /// Gets the rank (0-7, where 0 is rank 1, 7 is rank 8).
  int get rank => value ~/ 8;

  /// Gets the file (0-7, where 0 is 'a', 7 is 'h').
  int get file => value % 8;

  /// Gets the row in internal board representation (0 is rank 8, 7 is rank 1).
  int get row => 7 - rank;

  /// Gets the column in internal board representation.
  int get col => file;

  /// Converts to algebraic notation (e.g., "e4").
  String toAlgebraic() {
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + file);
    final rankNum = rank + 1;
    return '$fileChar$rankNum';
  }

  /// Checks if offset by (dr, dc) is valid, returns new Square if so.
  Square? offset(int dr, int dc) {
    final newRow = row + dr;
    final newCol = col + dc;
    if (newRow < 0 || newRow >= 8 || newCol < 0 || newCol >= 8) {
      return null;
    }
    return Square.fromRowCol(newRow, newCol);
  }

  /// Manhattan distance to another square.
  int distance(Square other) {
    return (row - other.row).abs() + (col - other.col).abs();
  }

  /// Chebyshev distance (king distance) to another square.
  int kingDistance(Square other) {
    return [(row - other.row).abs(), (col - other.col).abs()].reduce((a, b) => a > b ? a : b);
  }

  @override
  String toString() => toAlgebraic();
}

/// Type-safe rank (1-8).
extension type const Rank._(int value) {
  Rank(int v) : value = v {
    if (v < 1 || v > 8) {
      throw ArgumentError('Rank must be 1-8, got $v');
    }
  }

  /// Internal index (0-7).
  int get index => value - 1;

  @override
  String toString() => value.toString();
}

/// Type-safe file (a-h).
extension type const File._(int value) {
  File(int v) : value = v {
    if (v < 0 || v >= 8) {
      throw ArgumentError('File must be 0-7, got $v');
    }
  }

  factory File.fromChar(String c) {
    final code = c.codeUnitAt(0) - 'a'.codeUnitAt(0);
    return File(code);
  }

  String get char => String.fromCharCode('a'.codeUnitAt(0) + value);

  @override
  String toString() => char;
}
