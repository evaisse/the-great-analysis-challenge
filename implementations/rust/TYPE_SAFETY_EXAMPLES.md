# Type Safety Examples - Rust PRD-04

This document demonstrates the type-safe patterns added in PRD-04.

## 1. Type-Safe Square - Compile-Time Bounds Checking

### Before (usize - no bounds checking)
```rust
let square: usize = 100;  // Compiles fine, but invalid square!
board.get_piece(square);  // Runtime panic or undefined behavior
```

### After (TypedSquare - bounds checked)
```rust
use crate::types::TypedSquare;

// Won't compile - out of bounds
let square = TypedSquare::try_from(100u8)?;  // Err("Square value must be 0-63")

// Compile-time constant
let e4 = TypedSquare::from_algebraic("e4")?;  // Ok(28)
assert_eq!(e4.rank(), 3);
assert_eq!(e4.file(), 4);
```

## 2. Phantom Types - Move Validation State

### Before (any move can be applied)
```rust
let mv = Move::new(12, 28, PieceType::Pawn);
board.make_move(&mv);  // No guarantee this move is legal!
```

### After (typed moves)
```rust
use crate::types::{TypedMove, Unchecked, Legal};

// User input - unchecked
let unchecked: TypedMove<Unchecked> = parse_user_input("e2e4");

// Validate before applying
let legal: TypedMove<Legal> = validate_move(board, unchecked)?;
board.make_move(legal);  // Type system guarantees this is legal

// This won't compile:
// board.make_move(unchecked);  // ERROR: expected TypedMove<Legal>, found TypedMove<Unchecked>
```

## 3. State Machine - Turn Tracking

### Before (manual turn tracking)
```rust
let mut board = Board::new();
board.make_move(&move1);  // White's move
board.make_move(&move2);  // Could be white again - no type check!
```

### After (type-level turn tracking)
```rust
use crate::types::{BoardState, WhiteToMove, BlackToMove};

let board: BoardState<WhiteToMove> = BoardState::new();

// Each move changes the type
let board: BoardState<BlackToMove> = board.transition_to_black();
let board: BoardState<WhiteToMove> = board.transition_to_white();

// This won't compile:
// let board2 = board.transition_to_white();  // ERROR: already White's turn!
```

## 4. Strongly Typed Enums

### Before (using chars/integers)
```rust
let piece_char = 'P';
let color = true;  // true = white, false = black?
```

### After (explicit types)
```rust
use crate::types::{Color, PieceType, Piece};

let color = Color::White;
let opposite = color.opposite();  // Black

let piece_type = PieceType::Pawn;
let value = piece_type.value();  // 100 centipawns

let piece = Piece::new(piece_type, color);
assert_eq!(piece.to_char(), 'P');  // Uppercase for White
```

## Compile-Time Error Examples

These examples show errors caught at compile time:

```rust
// Error: Square out of bounds
let sq = TypedSquare::try_from(64u8)?;  // Runtime: Err("Square value must be 0-63")

// Error: Wrong move type
fn apply_legal(mv: TypedMove<Legal>) { /* ... */ }
let unchecked = TypedMove::new_unchecked(from, to, piece);
apply_legal(unchecked);  // ERROR: type mismatch

// Error: Wrong turn
let white_board: BoardState<WhiteToMove> = BoardState::new();
white_board.transition_to_white();  // ERROR: impossible transition

// Error: Type confusion prevented
let color: Color = Color::White;
if color == true { }  // ERROR: cannot compare Color with bool
```

## Zero-Cost Abstractions

All type checks happen at compile time. The generated machine code is identical:

```rust
// This code:
let sq = TypedSquare::try_from(28u8).unwrap();
board.get_piece(sq);

// Compiles to the same assembly as:
board.get_piece(28);
```

Phantom types (like `PhantomData<Legal>`) are zero-sized and completely erased at runtime.

## Migration Path

The implementation maintains 100% backward compatibility:

```rust
// Old code still works
use crate::types::{Square, Move};  // Square = usize, Move = LegacyMove

let square: Square = 28;  // Still works
let mv = Move::new(12, 28, PieceType::Pawn);  // Still works

// New code can opt into type safety
use crate::types::{TypedSquare, TypedMove, Legal};

let square = TypedSquare::try_from(28u8)?;
let mv: TypedMove<Legal> = validate(...);
```

This allows gradual migration without breaking existing code.
