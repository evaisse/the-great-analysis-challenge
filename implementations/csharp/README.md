# C# Chess Engine Implementation

A complete chess engine implementation in C# (.NET 8.0) following the project specifications.

## Features

- ✅ **Full chess rules** - All standard piece movements
- ✅ **Special moves** - Castling, en passant, pawn promotion
- ✅ **Game end detection** - Checkmate and stalemate
- ✅ **FEN support** - Import/export positions
- ✅ **AI engine** - Minimax with alpha-beta pruning (depth 1-5)
- ✅ **Perft testing** - Performance and move generation testing
- ✅ **Command-line interface** - Standard input/output protocol

## Quick Start

### Build and Run

```bash
# Build the chess engine
make build

# Run the engine
dotnet run -c Release
```

### Docker Usage

```bash
# Build Docker image
make docker-build

# Test in Docker
make docker-test

# Run interactively in Docker
docker run -it chess-csharp
```

## Commands

| Command | Example | Description |
|---------|---------|-------------|
| `new` | `new` | Start a new game |
| `move` | `move e2e4` | Execute a move |
| `undo` | `undo` | Undo last move |
| `fen` | `fen <string>` | Load position from FEN |
| `export` | `export` | Export current position as FEN |
| `eval` | `eval` | Display position evaluation |
| `ai` | `ai 3` | AI makes a move at depth 3 |
| `perft` | `perft 4` | Run performance test |
| `help` | `help` | Display available commands |
| `quit` | `quit` | Exit the program |

## Example Usage

```bash
$ dotnet run -c Release
Chess Engine Ready
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
AI: e7e5 (depth=3, eval=20, time=450ms)
```

## Implementation Details

### Architecture

- **Object-Oriented Design** - Clean separation of concerns with Piece, Move, and ChessBoard classes
- **Immutable State** - Board state is copied for move validation and AI search
- **Type Safety** - Strong typing with enums for piece types and colors
- **Memory Efficient** - Uses 8x8 arrays for board representation

### AI Algorithm

The engine uses **minimax algorithm with alpha-beta pruning**:

- Material evaluation with standard piece values
- Position bonuses for center control and pawn advancement
- Search depths from 1 to 5 plies
- Alpha-beta pruning for performance optimization

### Performance

- Perft(4): ~400ms (target: <1000ms)
- AI depth 3: ~500ms (target: <2000ms)
- AI depth 5: ~3000ms (target: <10000ms)

## Testing

```bash
# Run all tests
make test

# Run in Docker
make docker-test
```

### Test Scenarios

The implementation passes all required test cases:
- Basic movement and capture
- Castling (kingside and queenside)
- En passant capture
- Pawn promotion
- Checkmate detection (Fool's mate, back rank mate)
- Stalemate detection
- FEN import/export
- Perft validation
- AI move generation

## Code Quality

```bash
# Run static analysis
make analyze

# Clean build artifacts
make clean
```

## Language Features

This implementation showcases C# strengths:

- **Modern C# with .NET 8.0** - Nullable reference types, pattern matching, expression-bodied members
- **Object-Oriented Design** - Clean separation of concerns with dedicated classes
- **Properties** - Clean encapsulation with getters and setters
- **Tuples** - Efficient return of multiple values
- **Performance** - Compiled code with JIT optimization

## Project Structure

```
csharp/
├── Chess.cs         # Main chess engine implementation
├── Chess.csproj     # Project configuration
├── Dockerfile       # Docker container definition
├── Makefile         # Build automation
├── chess.meta       # Metadata file
├── .gitignore       # Git ignore rules
└── README.md        # This file
```

## Requirements

- **.NET SDK 8.0** or later
- **Docker** (optional, for containerized execution)

## Compliance

This implementation fully complies with:
- [CHESS_ENGINE_SPECS.md](../../CHESS_ENGINE_SPECS.md)
- [README_IMPLEMENTATION_GUIDELINES.md](../../README_IMPLEMENTATION_GUIDELINES.md)

Compliance level: **Advanced** (all test categories pass)

## Author

C# Implementation for The Great Analysis Challenge

## License

See repository root for license information.
