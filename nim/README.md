# Nim Chess Engine Implementation

This directory contains a chess engine implementation in Nim, following the specification defined in `../CHESS_ENGINE_SPECS.md`.

## Features Implemented

- ✅ **Basic Board Representation**: 8x8 board with piece storage
- ✅ **FEN Import/Export**: Load and save positions in FEN notation
- ✅ **Command Parser**: Interactive command-line interface
- ✅ **Basic Move Execution**: Simple move parsing and execution
- ✅ **Board Display**: ASCII board visualization
- ❌ **Move Validation**: Currently simplified (all moves accepted if basic format is correct)
- ❌ **AI Engine**: Not yet implemented
- ❌ **Special Moves**: Castling, en passant, promotion not implemented
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
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./chess
```

Expected output should include:
```
FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1
```

## Implementation Notes

This implementation showcases Nim's features:

- **Memory Safety**: No manual memory management needed
- **Performance**: Compiles to efficient native code
- **Clean Syntax**: Python-like readability with C-like performance
- **Type Safety**: Compile-time type checking
- **Minimal Dependencies**: Uses only standard library

## Current Limitations

1. **Move Validation**: The current implementation does not perform proper chess move validation. Any move with correct algebraic notation format will be accepted regardless of legality.

2. **Special Moves**: Castling, en passant, and pawn promotion are not implemented.

3. **AI**: No artificial intelligence or move search algorithm implemented yet.

4. **Game End Detection**: Checkmate and stalemate detection not implemented.

## Next Steps

1. Implement proper move validation with chess rules
2. Add support for special moves (castling, en passant, promotion)
3. Implement minimax AI with alpha-beta pruning
4. Add perft testing for move generation verification
5. Implement game end detection (checkmate, stalemate)

## Architecture

The implementation uses a straightforward object-oriented approach:

- `Piece`: Represents a chess piece (type + color)
- `Board`: Holds the 8x8 board state and game metadata
- `Move`: Represents a chess move
- `ChessEngine`: Main game controller

The code is structured as a single file for simplicity, but could be split into modules as it grows.