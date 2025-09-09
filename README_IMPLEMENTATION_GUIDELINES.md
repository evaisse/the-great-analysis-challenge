# Chess Engine Implementation Guidelines

## Quick Start

This document provides essential guidelines for implementing a chess engine according to the project specifications. Each implementation must be a **command-line interface (CLI)** chess engine that follows a consistent protocol across all languages.

## Core Requirements

### 1. Project Structure

Each language implementation should follow this structure:
```
<language>/
├── Dockerfile           # Docker container definition
├── chess.meta          # Metadata file (JSON)
├── <main_file>         # Entry point (chess.py, chess.rb, etc.)
├── src/ or lib/        # Source code modules
└── README.md           # Language-specific documentation
```

### 2. Essential Commands

Every implementation **MUST** support these commands:

| Command | Format | Example |
|---------|--------|---------|
| `new` | Start new game | `new` |
| `move` | Execute move | `move e2e4` |
| `undo` | Undo last move | `undo` |
| `export` | Export FEN | `export` |
| `ai` | AI move (depth 1-5) | `ai 3` |
| `quit` | Exit program | `quit` |

### 3. Board Display Format

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

**Piece notation:**
- Uppercase = White (K, Q, R, B, N, P)
- Lowercase = Black (k, q, r, b, n, p)
- Dot (.) = Empty square

### 4. Required Components

Each implementation must include:

1. **Board Representation** - 8x8 array or equivalent
2. **Move Generator** - Generate all legal moves
3. **Move Validator** - Check move legality
4. **FEN Parser** - Import/export positions
5. **AI Engine** - Minimax with alpha-beta pruning
6. **Command Parser** - Process user input
7. **Display Renderer** - ASCII board output

### 5. AI Implementation

#### Minimax Algorithm (Required)
```
Material values:
- Pawn = 100
- Knight = 320
- Bishop = 330
- Rook = 500
- Queen = 900
- King = 20000

Position bonuses:
- Center control: +10
- Pawn advancement: +5 per rank
```

#### Performance Targets
- Depth 1: < 100ms
- Depth 3: < 2s
- Depth 5: < 10s

### 6. Special Moves

Must implement:
- **Castling** (O-O, O-O-O)
- **En Passant** capture
- **Pawn Promotion** (auto-Queen or specified piece)

### 7. Error Handling

Required error messages:
```
ERROR: Invalid move format
ERROR: Illegal move
ERROR: No piece at source square
ERROR: Wrong color piece
ERROR: King would be in check
```

### 8. Metadata File (chess.meta)

```json
{
  "language": "python",
  "version": "3.11",
  "author": "Your Name",
  "build": "python3 -m py_compile chess.py",
  "run": "python3 chess.py",
  "features": ["perft", "fen", "ai", "castling", "en_passant", "promotion"],
  "max_ai_depth": 5,
  "estimated_perft4_ms": 1000
}
```

## Testing Requirements

### 1. Basic Test Sequence
```bash
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | <your_program>
```

Expected FEN output should contain: `4p3/4P3`

### 2. Perft Test
```
new
perft 4
```
Expected: 197281 positions

### 3. Docker Testing

All implementations must be testable via Docker:
```bash
make test-<language>
```

## Language-Specific Guidelines

### Compiled Languages (C, C++, Rust, Go, etc.)
- Compile in Dockerfile
- Executable as final output
- Optimize for performance

### Interpreted Languages (Python, Ruby, JavaScript, etc.)
- Direct script execution
- Clear module organization
- Focus on readability

### Functional Languages (Haskell, Elm, etc.)
- Immutable state representation
- Pure functions where possible
- Demonstrate functional paradigms

## Common Pitfalls to Avoid

1. **Board coordinate confusion** - a1 is bottom-left for White
2. **FEN parsing errors** - Test with provided positions
3. **Castling validation** - Check ALL conditions
4. **En passant timing** - Only valid immediately after pawn double-move
5. **Input/output buffering** - Flush output after each response

## Validation Checklist

Before submitting, ensure your implementation:

- [ ] Runs in Docker container
- [ ] Implements all required commands
- [ ] Displays board correctly
- [ ] Handles errors gracefully
- [ ] Passes basic move sequence test
- [ ] Includes chess.meta file
- [ ] AI makes legal moves at all depths
- [ ] Perft(4) returns 197281

## Quick Test Commands

```bash
# Build Docker image
docker build -t chess-<language> -f <language>/Dockerfile <language>

# Test basic moves
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<language>

# Test AI
echo -e "new\nai 3\nquit" | docker run -i chess-<language>

# Use Makefile
make test-<language>
```

## Need Help?

- Review `CHESS_ENGINE_SPECS.md` for complete specification
- Check existing implementations in other languages
- Test outputs should match expected formats exactly
- All tests run inside Docker containers for consistency