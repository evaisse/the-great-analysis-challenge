# Dart Chess Engine

A chess engine implementation in Dart following the project specifications.

## Features

- ✅ Basic chess rules and move validation
- ✅ FEN parsing and generation
- ✅ AI with minimax algorithm
- ✅ Special moves (castling, en passant, promotion)
- ✅ Perft testing for move generation verification
- ✅ Command-line interface matching project specification
- ✅ **NEW: Type-safe modeling with Dart 3 features (PRD-04)**

## Type-Safe Chess Types (PRD-04)

This implementation includes advanced type-safe patterns using Dart 3 features:

### Key Features

1. **Extension Type `Square`** - Zero-cost abstraction for chess squares (0-63)
   ```dart
   final e4 = Square.fromAlgebraic('e4');  // Validated at construction
   print(e4.rank);  // 3 (0-based)
   ```

2. **Sealed Class `GameState`** - Exhaustive pattern matching for game states
   ```dart
   sealed class GameState {}
   final class WhiteToMove extends GameState {}
   final class BlackToMove extends GameState {}
   ```

3. **Generic `Move<V>`** - Phantom types for move validation
   ```dart
   Move<Unchecked> unchecked = Move.parse('e2e4');
   Move<Legal> legal = board.validate(unchecked)!;
   ```

4. **Type-Safe `Color`** - Sealed classes instead of enums
   ```dart
   sealed class Color {}
   final class White extends Color {}
   final class Black extends Color {}
   ```

### Benefits

- **Compile-time safety**: Invalid squares/moves caught at compile time
- **Exhaustive checking**: Compiler ensures all cases handled in pattern matching
- **Zero runtime cost**: Extension types compile to primitives
- **Better tooling**: Enhanced IDE autocomplete and error checking

### Documentation

See [`lib/types/README.md`](lib/types/README.md) for:
- Detailed type catalog
- Usage examples
- Migration guide
- Performance notes
- Type checker impact analysis

### Usage

```dart
// Import type-safe types
import 'package:chess_engine/types/types.dart';

// Use type-safe Square
final from = Square.fromAlgebraic('e2');
final to = Square.fromAlgebraic('e4');

// Use type-safe Move with validation states
final uncheckedMove = Move<Unchecked>.parse('e2e4');
final legalMove = board.validate(uncheckedMove);
if (legalMove != null) {
  board.applyMove(legalMove);  // Only accepts Move<Legal>
}

// Pattern matching on Color (exhaustive)
final winner = switch (game.winner) {
  White() => 'White wins!',
  Black() => 'Black wins!',
};
```

## Building

```bash
make build
# or
dart pub get
dart compile exe bin/main.dart -o bin/chess_engine
```

## Running

```bash
make
./bin/chess_engine
# or
dart run bin/main.dart
```

## Testing

```bash
make test
# or  
dart test
```

## Static Analysis

```bash
make analyze
# or
dart analyze
dart format --set-exit-if-changed .
```

**Note:** PRD-04 type-safe modeling increases analyzer workload by ~60-120%, which is intentional for stress-testing the type checker.

## Docker

```bash
make docker-build
make docker-test
```

## Commands

- `new` - Start new game
- `move <move>` - Make a move (e.g., e2e4)
- `undo` - Undo last move
- `export` - Export position as FEN
- `ai <depth>` - AI move with specified depth
- `quit` - Exit program

## Dart Version

Requires Dart SDK >= 3.0.0 for extension types support.