# C++ Chess Engine Implementation

A complete chess engine implementation in C++17 following the Chess Engine Specification v1.0.

## Features

- ✅ **Full Chess Rules**: All standard piece movements
- ✅ **Special Moves**: Castling, en passant, pawn promotion
- ✅ **AI Engine**: Minimax with alpha-beta pruning (depth 1-5)
- ✅ **FEN Support**: Import/export positions
- ✅ **Performance Testing**: Perft for move generation validation
- ✅ **Game End Detection**: Checkmate and stalemate

## Building

### Local Build
```bash
make build
```

### Docker Build
```bash
make docker-build
```

## Running

### Local Execution
```bash
./chess
```

### Docker Execution
```bash
docker run -it chess-cplusplus
```

## Testing

### Local Testing
```bash
make test
```

### Docker Testing
```bash
make docker-test
```

## Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `new` | Start a new game | `new` |
| `move <from><to>` | Make a move | `move e2e4` |
| `undo` | Undo last move | `undo` |
| `ai <depth>` | AI makes a move | `ai 3` |
| `fen <string>` | Load FEN position | `fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` |
| `export` | Export current FEN | `export` |
| `eval` | Show position evaluation | `eval` |
| `perft <depth>` | Performance test | `perft 4` |
| `help` | Show help | `help` |
| `quit` | Exit program | `quit` |

## Implementation Details

### Architecture

The implementation uses a single-file approach for simplicity while maintaining all required functionality:

- **Board Representation**: 8x8 integer array with bitflags for piece types and colors
- **Move Generation**: Pseudo-legal move generation with legality verification
- **AI Engine**: Minimax algorithm with alpha-beta pruning
- **State Management**: History stack for undo functionality

### C++ Features Used

- **STL Containers**: `vector` for move lists and history
- **Modern C++17**: Range-based loops, structured bindings
- **Performance**: Optimized with `-O2` compiler flag
- **Memory Safety**: Stack-based allocation, no manual memory management

### Piece Representation

Pieces are represented as integers with bitflags:
- Lower 3 bits: Piece type (Pawn=1, Knight=2, Bishop=3, Rook=4, Queen=5, King=6)
- Bit 3: White flag (8)
- Bit 4: Black flag (16)

### AI Evaluation Function

```
Material Values:
- Pawn: 100
- Knight: 320
- Bishop: 330
- Rook: 500
- Queen: 900
- King: 20000

Position Bonuses:
- Center control: +10
- Pawn advancement: +5 per rank
```

## Performance

Expected performance on modern hardware:

| Operation | Time |
|-----------|------|
| Perft(4) | ~500ms |
| AI Depth 3 | ~1-2s |
| AI Depth 5 | ~5-10s |

## Example Session

```bash
$ ./chess
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
move e2e4
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
ai 3
AI: e7e5 (depth=3, eval=0, time=150ms)
```

## Compliance

This implementation complies with:
- Chess Engine Specification v1.0
- Docker-first testing approach
- Makefile standardization
- Metadata requirements

## Development

### Code Quality
```bash
make analyze
```

### Clean Build
```bash
make clean
make build
```

## License

Part of The Great Analysis Challenge project.
