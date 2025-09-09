# Nim Chess Engine Implementation

This directory contains a chess engine implementation in Nim, following the specification defined in `../CHESS_ENGINE_SPECS.md`.

## Features Implemented

- ✅ **Basic Board Representation**: 8x8 board with piece storage
- ✅ **FEN Import/Export**: Load and save positions in FEN notation
- ✅ **Command Parser**: Interactive command-line interface
- ✅ **Move Validation**: Proper chess rules validation for all piece types
- ✅ **Path Checking**: Sliding pieces (rook, bishop, queen) check for clear paths
- ✅ **Turn Validation**: Ensures players can only move their own pieces
- ✅ **Board Display**: ASCII board visualization
- ✅ **Error Handling**: Specific error messages for different invalid move types
- ❌ **AI Engine**: Not yet implemented
- ❌ **Special Moves**: Castling, en passant, promotion not implemented
- ❌ **Check Detection**: King safety not validated
- ❌ **Perft Testing**: Not yet implemented

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

## Current Limitations

1. **Special Moves**: Castling, en passant, and pawn promotion are not implemented.

2. **Check Detection**: The engine doesn't detect or prevent moves that leave the king in check.

3. **AI**: No artificial intelligence or move search algorithm implemented yet.

4. **Game End Detection**: Checkmate and stalemate detection not implemented.

5. **Move History**: Undo functionality is not fully implemented.

## Next Steps

1. Implement check detection and prevention
2. Add support for special moves (castling, en passant, promotion)
3. Implement minimax AI with alpha-beta pruning
4. Add perft testing for move generation verification
5. Implement game end detection (checkmate, stalemate)
6. Add move history and proper undo functionality

## Architecture

The implementation uses a straightforward object-oriented approach:

- `Piece`: Represents a chess piece (type + color)
- `Board`: Holds the 8x8 board state and game metadata
- `Move`: Represents a chess move
- `ChessEngine`: Main game controller

The code is structured as a single file for simplicity, but could be split into modules as it grows.