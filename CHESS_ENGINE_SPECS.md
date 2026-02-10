# Chess Engine Implementation Specification v1.0

## Overview

This document defines the universal specification for implementing a command-line chess engine across multiple programming languages. All implementations must conform to these specifications to ensure consistency and comparability.

## 1. Interface Specification

### 1.1 Command Protocol

All implementations must support the following commands via stdin/stdout:

| Command | Format | Description | Example |
|---------|--------|-------------|---------|
| `move` | `move <from><to>[promotion]` | Execute a move | `move e2e4`, `move e7e8Q` |
| `undo` | `undo` | Undo the last move | `undo` |
| `new` | `new` | Start a new game | `new` |
| `ai` | `ai <depth>` | AI makes a move (depth 1-5) | `ai 3` |
| `fen` | `fen <string>` | Load position from FEN | `fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` |
| `export` | `export` | Export current position as FEN | `export` |
| `eval` | `eval` | Display position evaluation | `eval` |
| `perft` | `perft <depth>` | Performance test (move count) | `perft 4` |
| `help` | `help` | Display available commands | `help` |
| `quit` | `quit` | Exit the program | `quit` |

### 1.2 Output Format

#### Board Display
```
  a b c d e f g h
8 r n b q k b n r 8
7 p p p p p p p p 7
6 . . . . . . . . 6
5 . . . . . . . . 5
4 . . . . . . . . 4
3 . . . . . . . . 3
2 P P P P P P P P 2
1 R N B Q K B N R 1
  a b c d e f g h

White to move
```

#### Piece Representation
- White: `K` (King), `Q` (Queen), `R` (Rook), `B` (Bishop), `N` (Knight), `P` (Pawn)
- Black: `k` (King), `q` (Queen), `r` (Rook), `b` (Bishop), `n` (Knight), `p` (Pawn)
- Empty: `.`

#### Status Messages
```
# After valid move
OK: <move>

# After invalid move
ERROR: <reason>

# Game end
CHECKMATE: <color> wins
STALEMATE: Draw

# AI move
AI: <move> (depth=<n>, eval=<score>, time=<ms>)

# FEN export
FEN: <fen_string>
```

## 2. Chess Rules Implementation

### 2.1 Standard Moves

All piece types must move according to FIDE chess rules:
- **Pawn**: One square forward (two from starting position), capture diagonally
- **Knight**: L-shape (2+1 squares)
- **Bishop**: Diagonally any distance
- **Rook**: Horizontally/vertically any distance
- **Queen**: Combination of Rook and Bishop
- **King**: One square in any direction

### 2.2 Special Moves

#### Castling
- Kingside: King moves from e1 to g1 (white) or e8 to g8 (black)
- Queenside: King moves from e1 to c1 (white) or e8 to c8 (black)
- Conditions:
  1. Neither piece has moved
  2. No pieces between King and Rook
  3. King not in check
  4. King doesn't pass through or land on attacked square

#### En Passant
- Capture pawn that just moved two squares
- Must be executed immediately after opponent's two-square pawn move

#### Promotion
- Pawn reaching 8th rank (white) or 1st rank (black)
- Auto-promote to Queen unless specified
- Optional: Allow promotion choice with move suffix (Q/R/B/N)

### 2.3 Game End Conditions

- **Checkmate**: King in check with no legal moves
- **Stalemate**: No legal moves but King not in check
- **Draw by repetition**: (Optional) Same position 3 times
- **50-move rule**: (Optional) 50 moves without pawn move or capture

## 3. AI Specification

⚠️ **For complete, deterministic AI algorithm specification, see [AI_ALGORITHM_SPEC.md](./AI_ALGORITHM_SPEC.md)**

The AI specification has been moved to a dedicated document that provides:
- Exact minimax algorithm with alpha-beta pruning
- Precise evaluation function with piece-square tables
- Deterministic move ordering rules
- Test positions for verification
- Compliance requirements

### 3.1 Algorithm Requirements (Summary)

All implementations must use **Minimax with Alpha-Beta pruning** as defined in [AI_ALGORITHM_SPEC.md](./AI_ALGORITHM_SPEC.md).

Key points:
- Exact piece values and evaluation function
- Deterministic move ordering (score descending, algebraic notation ascending)
- Integer arithmetic (no floating-point evaluation)
- Piece-square tables for positional bonuses

### 3.2 Evaluation Function (Summary)

```
Material Values:
- Pawn = 100
- Knight = 320
- Bishop = 330
- Rook = 500
- Queen = 900
- King = 20000

Position Bonuses:
- Piece-square tables (see AI_ALGORITHM_SPEC.md for exact values)

Special Scores:
- Checkmate = ±100000
- Stalemate = 0
```

**Note**: The evaluation function must be implemented exactly as specified in AI_ALGORITHM_SPEC.md to ensure deterministic, reproducible behavior across all implementations.

### 3.3 Performance Requirements

| Depth | Maximum Time | Move Quality |
|-------|--------------|--------------|
| 1 | 100ms | Legal move |
| 2 | 500ms | Captures obvious pieces |
| 3 | 2s | Basic tactics |
| 4 | 5s | Intermediate tactics |
| 5 | 10s | Advanced tactics |

## 4. FEN Support

### 4.1 FEN Format

Implementations must support standard FEN notation:
```
<pieces> <turn> <castling> <en_passant> <halfmove> <fullmove>
```

Example:
```
rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
```

### 4.2 Required FEN Positions for Testing

```
# Starting position
rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1

# Midgame position
r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4

# Endgame position
8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1

# Castling test
r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1

# En passant test
rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3

# Promotion test
8/P7/8/8/8/8/8/8 w - - 0 1
```

## 5. Testing Protocol

### 5.1 Automated Test Cases

Each implementation must pass these test sequences:

#### Test 1: Basic Movement
```
Input:
new
move e2e4
move e7e5
move g1f3
move b8c6
export

Expected FEN contains: "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R"
```

#### Test 2: Castling
```
Input:
fen r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1
move e1g1
export

Expected: King on g1, Rook on f1
```

#### Test 3: En Passant
```
Input:
fen rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3
move e5f6
export

Expected: White pawn on f6, black f-pawn removed
```

#### Test 4: Checkmate Detection
```
Input:
new
move f2f3
move e7e5
move g2g4
move d8h4

Expected Output: "CHECKMATE: Black wins"
```

#### Test 5: AI Move Generation
```
Input:
new
ai 3

Expected: Legal move executed, output includes depth and evaluation
```

#### Test 6: Perft Accuracy
```
Input:
new
perft 4

Expected: 197281 (number of positions after 4 plies from start)
```

### 5.2 Performance Benchmarks

| Operation | Maximum Time |
|-----------|--------------|
| Move validation | 10ms |
| Board display | 50ms |
| FEN parsing | 10ms |
| Perft(4) | 1000ms |
| AI depth 3 | 2000ms |
| AI depth 5 | 10000ms |

## 6. Error Handling

### 6.1 Required Error Messages

```
ERROR: Invalid move format
ERROR: Illegal move
ERROR: No piece at source square
ERROR: Wrong color piece
ERROR: King would be in check
ERROR: Invalid FEN string
ERROR: Invalid command
ERROR: AI depth must be 1-5
```

### 6.2 Recovery

- Invalid commands should not crash the program
- Invalid moves should not modify game state
- Program should continue accepting commands after errors

## 7. Implementation Guidelines

### 7.1 Required Components

1. **Board Representation**: 8x8 array or equivalent
2. **Move Generator**: Produces all legal moves
3. **Move Validator**: Checks move legality
4. **Game State Manager**: Tracks position, castling rights, etc.
5. **FEN Parser/Serializer**: Import/export positions
6. **AI Engine**: Minimax with alpha-beta
7. **Command Parser**: Process user input
8. **Display Renderer**: ASCII board output

### 7.2 Language-Specific Considerations

Implementations may showcase language features:
- **C/C++**: Bitboards, manual memory management
- **Python**: Clear OOP design, list comprehensions
- **Rust**: Memory safety, pattern matching
- **Go**: Goroutines for parallel search
- **JavaScript**: Async/await for UI responsiveness
- **Haskell**: Pure functions, immutable state
- **Java**: Design patterns, interfaces

## 8. Test Harness Integration

### 8.1 Execution Interface

All implementations must be executable via:
```bash
<language_runner> <program_file>
```

Examples:
- Python: `python3 chess.py`
- C: `./chess`
- Java: `java Chess`
- JavaScript: `node chess.js`

### 8.2 Standard I/O Protocol

- Read commands from stdin
- Write output to stdout
- Error messages to stderr (optional)
- No buffering issues (flush after output)

### 8.3 Test Metadata

Each implementation must include metadata labels in its `Dockerfile`:
```dockerfile
LABEL org.chess.language="python"
LABEL org.chess.version="3.11"
LABEL org.chess.author="Developer Name"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
```

Optional command labels (if different from standard `make` targets):
```dockerfile
LABEL org.chess.build="custom build command"
LABEL org.chess.test="custom test command"
LABEL org.chess.analyze="custom analyze command"
LABEL org.chess.run="custom run command" # Automatically inferred from CMD if missing
```

## 9. Validation Criteria

An implementation is considered compliant if it:
1. Implements all required commands
2. Passes all automated test cases
3. Meets performance benchmarks
4. Produces correct Perft values
5. Handles errors gracefully
6. Maintains consistent output format

## 10. Version History

- v1.0 (2024): Initial specification

---

*This specification ensures consistent behavior across all language implementations while allowing each to demonstrate its unique strengths and paradigms.*