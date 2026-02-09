# Type-Safe Chess Engine Types (PRD-04)

This directory contains type-safe chess engine types using advanced Dart 3 features:

## Overview

PRD-04 introduces compile-time type safety for chess concepts using:
- **Extension types** (Dart 3): Zero-cost abstractions
- **Sealed classes**: Exhaustive pattern matching
- **Generic constraints**: Type-level state transitions
- **Phantom types**: Move validation states

## Type Catalog

### 1. Square (`square.dart`)

Extension type for chess board squares (0-63) with built-in validation:

```dart
// Extension type - zero runtime cost
extension type Square._(int value) {
  Square(int v) : value = v {
    if (v < 0 || v >= 64) throw ArgumentError('Square must be 0-63');
  }
  
  factory Square.fromAlgebraic(String algebraic) // "e4" -> Square(28)
  factory Square.fromRowCol(int row, int col)    // (4, 4) -> Square(28)
  
  int get rank;  // 0-7 (algebraic ranks 1-8)
  int get file;  // 0-7 (algebraic files a-h)
  int get row;   // internal board row
  int get col;   // internal board col
  
  String toAlgebraic(); // Square(28) -> "e4"
  Square? offset(int dr, int dc);  // Returns null if out of bounds
}
```

**Benefits:**
- Cannot construct invalid squares (compile error or runtime check)
- Type-distinct from `int` - can't accidentally pass row/col as square
- Zero runtime overhead (extension types compile to underlying `int`)

### 2. Piece Types (`piece.dart`)

Sealed class hierarchy for piece colors with exhaustive checking:

```dart
sealed class Color {
  const Color();
  Color get opposite;
}

final class White extends Color { ... }
final class Black extends Color { ... }

// Singletons
const white = White();
const black = Black();

// Pattern matching is exhaustive (compiler error if missing case)
String getSymbol(Color color) {
  return switch (color) {
    White() => 'w',  // Must handle White
    Black() => 'b',  // Must handle Black
    // Compiler error if any case missing
  };
}
```

**Benefits:**
- Exhaustive pattern matching enforced by compiler
- Type-safe color operations (can't mix up white/black)
- Clear semantic distinction from boolean flags

### 3. Game State (`board_state.dart`)

Sealed classes encoding whose turn it is at the type level:

```dart
sealed class GameState {
  Color get activeColor;
  GameState get nextState;
}

final class WhiteToMove extends GameState { ... }
final class BlackToMove extends GameState { ... }

// Type-level state transitions (future feature)
class Board<S extends GameState> {
  S get state;
  
  // Type changes after move
  Board<BlackToMove> makeMove(Move move) // when S = WhiteToMove
  Board<WhiteToMove> makeMove(Move move) // when S = BlackToMove
}
```

**Benefits:**
- Game state encoded in types, not just runtime values
- Can enforce turn alternation at compile time (future enhancement)
- Pattern matching ensures all states handled

### 4. Move Validation (`move.dart`)

Phantom types for move validation using sealed classes:

```dart
sealed class MoveValidation {}
final class Legal extends MoveValidation {}
final class Unchecked extends MoveValidation {}

class Move<V extends MoveValidation> {
  final Square from;
  final Square to;
  final PieceType? promotion;
  
  // Parse from input - returns Unchecked
  factory Move.parse(String moveStr) -> Move<Unchecked>
  
  // Promote after validation
  Move<Legal> promoteToLegal();
}

// Board API
class Board {
  // Only accepts legal moves
  void applyMove(Move<Legal> move) { ... }
  
  // Validates and returns legal or null
  Move<Legal>? validate(Move<Unchecked> move) { ... }
}
```

**Benefits:**
- Cannot apply unvalidated moves (compile error)
- Validation state tracked through type system
- Clear API contracts

### 5. Castling Rights (`castling.dart`)

Type-safe castling rights representation:

```dart
class CastlingRights {
  final bool whiteKingside;
  final bool whiteQueenside;
  final bool blackKingside;
  final bool blackQueenside;
  
  static const all = CastlingRights(
    whiteKingside: true,
    whiteQueenside: true,
    blackKingside: true,
    blackQueenside: true,
  );
  
  factory CastlingRights.fromFen(String fen);
  String toFen();
  
  bool canCastleKingside(Color color);
  CastlingRights removeKingside(Color color);
}
```

**Benefits:**
- Immutable value type
- Type-safe color-based queries
- FEN interoperability

## Usage Examples

### Basic Square Operations

```dart
import 'package:chess_engine/types/types.dart';

// Create squares
final e4 = Square.fromAlgebraic('e4');  // Validated at construction
final e2 = Square.fromRowCol(6, 4);     // Also validated

// Type safety
int invalidSquare = e4;  // Compile error! Can't assign Square to int
int value = e4.value;     // OK - explicit access to underlying value

// Algebraic conversion
print(e4.toAlgebraic());  // "e4"
print(e4.rank);           // 3 (0-based, rank 4)
print(e4.file);           // 4 (0-based, file e)

// Safe offset
final e5 = e4.offset(-1, 0);  // Returns Square? (can be null if OOB)
if (e5 != null) {
  print('One rank up: ${e5.toAlgebraic()}');
}
```

### Type-Safe Colors

```dart
import 'package:chess_engine/types/types.dart';

void announceWinner(Color winner) {
  // Exhaustive switch expression
  final message = switch (winner) {
    White() => 'White wins!',
    Black() => 'Black wins!',
    // Compiler enforces all cases handled
  };
  print(message);
}

// Singleton usage
Color current = white;
Color next = current.opposite;  // black
```

### Move Validation Flow

```dart
import 'package:chess_engine/types/types.dart';

// Parse user input
final userInput = 'e2e4';
final uncheckedMove = Move<Unchecked>.parse(userInput);

// Validate move
final legalMove = board.validate(uncheckedMove);

if (legalMove != null) {
  // Type is Move<Legal> here
  board.applyMove(legalMove);  // OK
} else {
  print('Illegal move!');
}

// This would be a compile error:
// board.applyMove(uncheckedMove);  // Error: expected Move<Legal>, got Move<Unchecked>
```

## Type Safety Benefits

### 1. Compile-Time Validation

```dart
// These all cause compile errors or runtime checks at construction:
final bad1 = Square(64);           // Error: out of range
final bad2 = Square(-1);           // Error: out of range
final bad3 = Square.fromAlgebraic('z9');  // Error: invalid square

// vs. old code:
int square = 64;  // Silently accepted, bug later
```

### 2. Exhaustive Pattern Matching

```dart
String colorName(Color c) {
  return switch (c) {
    White() => 'White',
    Black() => 'Black',
    // If we add a new color, this becomes a compile error
  };
}
```

### 3. API Contracts

```dart
// Old API - no guarantees:
void makeMove(int from, int to);  // from/to could be invalid!

// New API - type-safe:
void makeMove(Square from, Square to);  // Guaranteed valid squares
```

### 4. Zero Runtime Cost

Extension types have **zero runtime overhead**:

```dart
extension type Square._(int value) { ... }

// Compiles to:
// Square e4 = 28;  // Just an int at runtime!
// No wrapper class, no memory overhead
```

## Migration Guide

The type-safe types are **additive** - existing code continues to work:

```dart
// Old code still works:
import 'package:chess_engine/chess_engine.dart';
final board = Board.empty();
board.move('e2e4');

// New code can use type-safe API:
import 'package:chess_engine/types/types.dart';
final square = Square.fromAlgebraic('e4');
final move = Move<Unchecked>.parse('e2e4');
```

To migrate:
1. Import `package:chess_engine/types/types.dart`
2. Replace `int` squares with `Square` type
3. Use `Move<Legal>` / `Move<Unchecked>` for validation
4. Replace `String` colors with `Color` sealed class
5. Use `CastlingRights` instead of string flags

## Performance Notes

- **Extension types**: Zero overhead (compile to underlying primitive)
- **Sealed classes**: Same as regular classes, small memory cost
- **Generic types**: Monomorphized at compile time (like Rust)
- **Pattern matching**: Optimized to jump tables by compiler

**Net result:** Minimal to zero runtime cost, pure compile-time benefit.

## Dart Analyzer Impact

Type-safe modeling significantly increases analyzer workload:

### Before PRD-04
```
$ time dart analyze
Analyzing...
No issues found!
real    0m2.341s
```

### After PRD-04 (Expected)
```
$ time dart analyze
Analyzing...
No issues found!
real    0m3.8s - 0m5.2s  (60-120% increase)
```

The increase comes from:
- Extension type validation
- Sealed class exhaustiveness checking
- Generic type constraint verification
- Cross-module type flow analysis

This is **intentional** - we're stressing the type checker, which is the goal of PRD-04.

## Future Enhancements

Possible future type-level features:

### 1. State Transitions in Board

```dart
class Board<S extends GameState> {
  // Type changes based on state
  Board<BlackToMove> makeMove(Move<Legal> move) where S == WhiteToMove;
  Board<WhiteToMove> makeMove(Move<Legal> move) where S == BlackToMove;
}

// Usage
Board<WhiteToMove> b1 = Board.initial();
Board<BlackToMove> b2 = b1.makeMove(move1);  // Type changes
Board<WhiteToMove> b3 = b2.makeMove(move2);  // Type changes back
```

### 2. Template Literal Squares

```dart
// Algebraic notation as types (TypeScript-style)
extension type AlgebraicSquare._(String value) 
    where value matches /^[a-h][1-8]$/;

final e4 = AlgebraicSquare('e4');  // OK
final invalid = AlgebraicSquare('z9');  // Compile error
```

### 3. Type-Level Board State

```dart
// Encode board state in types (advanced)
class Board<S extends GameState, K extends KingPosition> { ... }
```

## Testing

Type-safe types are tested via:

1. **Unit tests**: Verify construction, validation, conversions
2. **Type tests**: Ensure compile errors where expected
3. **Integration tests**: All existing tests pass unchanged
4. **Property tests**: Invariants hold (e.g., `Square` always 0-63)

## References

- Dart 3 Extension Types: https://dart.dev/language/extension-types
- Sealed Classes: https://dart.dev/language/class-modifiers#sealed
- Pattern Matching: https://dart.dev/language/patterns
- PRD-04 Specification: `docs/prd/04-type-safe-modeling.md`
