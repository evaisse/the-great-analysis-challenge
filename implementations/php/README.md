# PHP Chess Engine Implementation

A complete chess engine implementation in PHP following the Chess Engine Specification v1.0.

## Overview

This implementation demonstrates PHP's object-oriented programming capabilities while maintaining clean, readable code. Built with PHP 8.3, it leverages modern PHP features like typed properties, match expressions, and named arguments.

## Features

✅ **Complete Chess Rules Implementation**
- All standard piece movements (Pawn, Knight, Bishop, Rook, Queen, King)
- Special moves: Castling (kingside and queenside), En Passant, Pawn Promotion
- Check, Checkmate, and Stalemate detection
- Move validation ensuring no self-checks

✅ **FEN Support**
- Load positions from Forsyth-Edwards Notation
- Export current position as FEN string
- Full support for castling rights and en passant targets

✅ **AI Engine**
- Minimax algorithm with alpha-beta pruning
- Configurable search depth (1-5)
- Material and positional evaluation
- Center control and pawn advancement bonuses

✅ **Performance Testing**
- Perft (performance test) for move generation verification
- Accurately counts positions at various depths

## Requirements

- PHP 8.0 or higher
- Docker (for containerized testing)

## Quick Start

### Local Usage

```bash
# Run the chess engine
php chess.php

# Test basic functionality
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | php chess.php
```

### Using Make

```bash
# Build (syntax check)
make build

# Run tests
make test

# Static analysis
make analyze

# Clean artifacts
make clean
```

### Docker Usage

```bash
# Build Docker image
make docker-build

# Test in Docker
make docker-test

# Run interactively
docker run -it chess-php
```

## Project Structure

```
php/
├── chess.php           # Main entry point
├── lib/
│   ├── Types.php       # Constants and Move class
│   ├── Board.php       # Board representation and state management
│   ├── MoveGenerator.php  # Move generation and validation
│   ├── FenParser.php   # FEN import/export
│   ├── AI.php          # Minimax AI with alpha-beta pruning
│   └── Perft.php       # Performance testing
├── Dockerfile          # Container definition
├── Makefile           # Build automation
├── chess.meta         # Implementation metadata
└── README.md          # This file
```

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `new` | Start a new game | `new` |
| `move <from><to>[promotion]` | Make a move | `move e2e4` or `move e7e8Q` |
| `undo` | Undo the last move | `undo` |
| `ai <depth>` | Let AI make a move | `ai 3` |
| `fen <string>` | Load position from FEN | `fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` |
| `export` | Export position as FEN | `export` |
| `eval` | Show position evaluation | `eval` |
| `perft <depth>` | Run performance test | `perft 4` |
| `help` | Show available commands | `help` |
| `quit` | Exit the program | `quit` |

## Implementation Details

### Board Representation

The board is represented as an 8x8 array where each square contains:
- Piece type (EMPTY, PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING)
- Piece color (WHITE, BLACK)

### Move Generation

Moves are generated for each piece type following chess rules:
- Pawns: Forward movement, diagonal captures, en passant, promotion
- Knights: L-shaped moves
- Bishops: Diagonal sliding
- Rooks: Horizontal/vertical sliding
- Queens: Combined rook and bishop movement
- Kings: One square in any direction, castling

All moves are validated to ensure the king is not left in check.

### AI Evaluation

The evaluation function considers:
- **Material Value**: Pawn=100, Knight=320, Bishop=330, Rook=500, Queen=900, King=20000
- **Positional Bonuses**: 
  - Center control: +10 for pieces on central squares (d4, d5, e4, e5)
  - Pawn advancement: +5 per rank advanced from starting position
- **Special Scores**: Checkmate = ±100000, Stalemate = 0

### Performance

Expected performance on modern hardware:
- **Perft(4)**: ~1500ms (197,281 nodes)
- **AI Depth 3**: < 2 seconds
- **AI Depth 5**: < 10 seconds

## PHP-Specific Features

This implementation showcases modern PHP features:

- **Typed Properties**: All class properties use type declarations
- **Match Expressions**: Clean piece-to-character conversions
- **Namespaces**: Organized code structure
- **Array Functions**: Efficient array operations with array_filter, array_merge
- **Spaceship Operator**: Used in path-clearing logic ($to <=> $from)
- **Null Coalescing**: Safe handling of optional parameters

## Testing

### Basic Functionality Test

```bash
make test
```

Expected output should include:
- Board display with proper piece placement
- FEN string matching the position after e2e4, e7e5

### Perft Validation

```bash
echo -e "new\nperft 4\nquit" | php chess.php
```

Expected output: `197281 nodes`

### AI Test

```bash
echo -e "new\nai 3\nquit" | php chess.php
```

Should output a legal move with evaluation score.

## Development

### Code Style

The implementation follows PSR-12 coding standards:
- 4-space indentation
- Opening braces on same line for methods
- Type declarations for all parameters and return values

### Debugging

Enable error reporting for debugging:
```php
error_reporting(E_ALL);
ini_set('display_errors', 1);
```

## Comparison with Other Languages

**Advantages of PHP:**
- Simple, readable syntax
- Excellent for rapid development
- Strong array manipulation capabilities
- Good for demonstrating OOP concepts

**Considerations:**
- Slower than compiled languages (C, Rust, Go)
- No native support for multithreading
- Type system less strict than TypeScript or Rust

## License

Part of The Great Analysis Challenge multi-language chess engine project.

## Contributing

Follow the implementation guidelines in `CHESS_ENGINE_SPECS.md` and `README_IMPLEMENTATION_GUIDELINES.md` at the project root.
