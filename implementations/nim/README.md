# Nim Chess Engine Implementation

This directory contains a complete chess engine implementation in Nim, rewritten from the ground up with a clean, modular architecture.

## Features Implemented

- ✅ **Basic Board Representation**: 8x8 board with efficient piece storage
- ✅ **FEN Import/Export**: Load and save positions in FEN notation
- ✅ **Command Parser**: Interactive command-line interface
- ✅ **Move Validation**: Complete chess rules validation for all piece types
- ✅ **Path Checking**: Sliding pieces (rook, bishop, queen) check for clear paths
- ✅ **Turn Validation**: Ensures players can only move their own pieces
- ✅ **Board Display**: Clear ASCII board visualization
- ✅ **Error Handling**: Specific error messages for different invalid move types
- ✅ **AI Engine**: Minimax algorithm with alpha-beta pruning
- ✅ **Special Moves**: Castling, en passant, and pawn promotion fully implemented
- ✅ **Check Detection**: Complete king safety validation
- ✅ **Perft Testing**: Performance testing for move generation verification
- ✅ **Game State Management**: Full move history and undo functionality

## Building and Running

### Requirements
- Nim 1.6.14 or higher

### Build
```bash
nim compile --opt:speed chess.nim
```

### Run
```bash
./chess
```

### Docker
```bash
docker build -t chess-nim .
docker run -it chess-nim
```

## Testing

Basic functionality test:
```bash
echo -e "new\nmove e2e4\nmove e7e5\nmove g1f3\nmove b8c6\nexport\nquit" | ./chess
```

Expected output should include:
```
FEN: r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1
```

Test move validation:
```bash
echo -e "new\nmove e2e5\nmove h1h3\nmove b1d2\nquit" | ./chess
```

Expected: All moves should be rejected with "ERROR: Illegal move"

## Implementation Notes

This implementation showcases Nim's features:

- **Memory Safety**: No manual memory management needed
- **Performance**: Compiles to efficient native code
- **Clean Syntax**: Python-like readability with C-like performance
- **Type Safety**: Compile-time type checking
- **Minimal Dependencies**: Uses only standard library

## Architecture

The new implementation features a clean, modular design organized into logical sections:

### Core Types
- `PieceType`: Enumeration for all piece types (none, pawn, knight, bishop, rook, queen, king)
- `Color`: White and black enumeration
- `Piece`: Object combining piece type and color
- `Square`: Range type for board squares (0-63)
- `Move`: Comprehensive move representation with flags for special moves
- `Board`: Complete board state including position, castling rights, en passant
- `GameState`: Game management with move history and board history

### Key Features
- **Type Safety**: Strong typing prevents common chess programming errors
- **Efficient Representation**: 64-square array with 0x88-style utilities
- **Complete Move Generation**: All legal moves including special cases
- **Attack Detection**: Fast square attack checking for check validation
- **Game Management**: Full game state with undo/redo functionality
- **AI Integration**: Minimax search with alpha-beta pruning
- **Performance Testing**: Perft implementation for move generation verification

### Code Organization
The code is organized into clear sections with comprehensive documentation:
1. Type definitions and constants
2. Utility functions for square manipulation
3. Board management and FEN parsing
4. Move validation and generation
5. Game state management
6. AI implementation
7. Command processing and main loop