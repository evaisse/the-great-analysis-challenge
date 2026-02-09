# Chess Engine - Imba Implementation

A complete chess engine implementation in [Imba](https://imba.io/), a programming language that compiles to JavaScript with a focus on web development and performance.

## About Imba

Imba is a programming language for building web applications with:
- Ruby-like syntax with significant whitespace
- Compiles to optimized JavaScript
- Fast performance for web applications
- Full access to Node.js and npm ecosystem
- Modern language features with concise syntax

## Features

This implementation includes:

- ✅ **Full Chess Rules**: All standard chess moves
- ✅ **Special Moves**: Castling, en passant, pawn promotion
- ✅ **FEN Support**: Import/export positions using Forsyth-Edwards Notation
- ✅ **AI Engine**: Minimax algorithm with alpha-beta pruning (depths 1-5)
- ✅ **Move Validation**: Complete legal move generation
- ✅ **Game State**: Check, checkmate, and stalemate detection
- ✅ **Perft Testing**: Performance testing for move generation
- ✅ **Command-Line Interface**: Interactive chess gameplay

## Requirements

- Node.js 20+ (for running)
- npm (for package management)
- Docker (for containerized testing)

## Installation

### Local Development

```bash
# Install dependencies
npm install

# Build the project
npm run build

# Run the chess engine
npm start
```

### Docker

```bash
# Build Docker image
make docker-build

# Run in Docker
docker run -it chess-imba

# Test in Docker
make docker-test
```

## Usage

### Interactive Mode

```bash
node dist/chess.js
```

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `new` | Start a new game | `new` |
| `move <move>` | Make a move | `move e2e4` |
| `undo` | Undo last move | `undo` |
| `display` | Show the board | `display` |
| `export` | Export as FEN | `export` |
| `fen <string>` | Load FEN position | `fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` |
| `ai <depth>` | AI makes a move | `ai 3` |
| `eval` | Evaluate position | `eval` |
| `perft <depth>` | Performance test | `perft 4` |
| `help` | Show help | `help` |
| `quit` | Exit program | `quit` |

### Example Session

```bash
$ node dist/chess.js
Chess Engine in Imba
Type 'help' for available commands

> new
New game started
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

> move e2e4
OK: e2e4
  a b c d e f g h
8 r n b q k b n r 8
7 p p p p p p p p 7
6 . . . . . . . . 6
5 . . . . . . . . 5
4 . . . . P . . . 4
3 . . . . . . . . 3
2 P P P P . P P P 2
1 R N B Q K B N R 1
  a b c d e f g h

Black to move

> ai 3
AI thinking at depth 3...
AI: e7e5 (depth=3, eval=-30, time=150ms)
  a b c d e f g h
8 r n b q k b n r 8
7 p p p p . p p p 7
6 . . . . . . . . 6
5 . . . . p . . . 5
4 . . . . P . . . 4
3 . . . . . . . . 3
2 P P P P . P P P 2
1 R N B Q K B N R 1
  a b c d e f g h

White to move

> export
FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2
```

## Implementation Details

### Board Representation

- 8x8 array of pieces
- Uppercase letters for White pieces (K, Q, R, B, N, P)
- Lowercase letters for Black pieces (k, q, r, b, n, p)
- Dot (.) for empty squares

### AI Algorithm

The AI uses Minimax with alpha-beta pruning:

- **Material Evaluation**: Standard piece values (P=100, N=320, B=330, R=500, Q=900, K=20000)
- **Positional Bonuses**: Center control (+10 points)
- **Search Depths**: 1-5 ply supported
- **Pruning**: Alpha-beta cutoffs for efficiency

### Special Rules

- **Castling**: Kingside (e1g1/e8g8) and Queenside (e1c1/e8c8)
- **En Passant**: Captured immediately after opponent's double pawn move
- **Promotion**: Pawns auto-promote to Queen (or specify with move suffix like e7e8Q)

## Testing

```bash
# Run all tests
make test

# Run Docker tests
make docker-test

# Run performance test (perft)
echo "new\nperft 4\nquit" | node dist/chess.js
# Expected output: 197281 nodes
```

## Building

```bash
# Clean build artifacts
make clean

# Rebuild from scratch
make build

# Static analysis
make analyze
```

## Language-Specific Features

This implementation showcases Imba's features:

- **Clean Syntax**: Ruby-inspired syntax with indentation-based blocks
- **Classes**: Object-oriented design with classes and properties
- **String Interpolation**: Easy string formatting with `{variable}` syntax
- **Modern JavaScript**: Compiles to modern ES6+ JavaScript
- **Type Annotations**: Optional type hints for better IDE support

## File Structure

```
imba/
├── Dockerfile          # Docker container definition
├── Makefile           # Build automation
├── package.json       # npm dependencies
├── chess.meta         # Implementation metadata
├── README.md          # This file
└── src/
    └── chess.imba     # Main chess engine source
```

## Performance

Expected performance on modern hardware:
- Perft(4): ~1000ms
- AI depth 3: ~2000ms
- AI depth 5: ~10000ms

## Compliance

This implementation follows the [Chess Engine Specification v1.0](../../CHESS_ENGINE_SPECS.md) and passes all required tests defined in the test suite.

## License

MIT License - Part of The Great Analysis Challenge project.

## Resources

- [Imba Official Documentation](https://imba.io/docs)
- [Chess Programming Wiki](https://www.chessprogramming.org/)
- [Project Specification](../../CHESS_ENGINE_SPECS.md)
