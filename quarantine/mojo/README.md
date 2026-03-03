# Chess Engine - Mojo Implementation

This is a chess engine implementation in [Mojo](https://www.modular.com/mojo), showcasing the language's performance-oriented features while maintaining Python-like syntax.

## Current Status

**WIP Implementation**: The Docker image now provides a Mojo runtime, but the engine is still in progress and not yet fully spec-compliant.

## Features (Planned/Implemented)

- Complete chess engine with CLI interface
- Standard chess rules implementation  
- AI with minimax and alpha-beta pruning (depths 1-5)
- FEN import/export support
- Move validation and generation
- Board display in standard format

## Language Highlights

Mojo brings several advantages to this implementation:

- **Performance**: Systems-level performance with Python-like syntax
- **Memory Safety**: Compile-time memory safety without garbage collection
- **Type System**: Strong static typing with type inference
- **Structs**: Value semantics for efficient data structures
- **Zero-cost Abstractions**: High-level features without runtime overhead

## Commands (Planned)

| Command | Description | Example |
|---------|-------------|---------|
| `new` | Start a new game | `new` |
| `move` | Make a move | `move e2e4` |
| `undo` | Undo last move | `undo` |
| `ai` | AI makes a move | `ai 3` |
| `export` | Export FEN | `export` |
| `eval` | Show evaluation | `eval` |
| `help` | Show commands | `help` |
| `quit` | Exit program | `quit` |

## Building and Running

### Docker (Current)
```bash
docker build -t chess-mojo .
docker run --network none -it chess-mojo
```

Note: The `xanonymous/mojo` image is published for `linux/amd64` only. On Apple Silicon, use `--platform=linux/amd64` when building/running.

### Via Makefile
```bash
make build DIR=mojo
make test DIR=mojo
```

### Local (if Mojo is installed)
```bash
mojo chess.mojo
```

## Implementation Details

### Architecture

The chess engine is structured using Mojo's struct-based approach:

- **Board**: Efficient board representation using StaticTuple
- **Types**: Value types for pieces, moves, and game state
- **MoveGenerator**: Legal move validation and generation
- **AI**: Minimax algorithm with alpha-beta pruning
- **ChessEngine**: Main CLI interface and command processing

### Key Mojo Features Showcased

1. **@value structs**: For immutable game pieces and moves
2. **StaticTuple**: For fixed-size board representation
3. **Strong typing**: Compile-time type safety
4. **Memory efficiency**: No garbage collection overhead
5. **Performance**: Systems-level performance for AI calculations

### Performance Characteristics (Expected)

- **Board representation**: Compact integer encoding
- **Move generation**: Efficient iteration over possible moves
- **AI search**: Fast minimax with aggressive pruning
- **Memory usage**: Minimal allocation during gameplay

## Testing

```bash
make test DIR=mojo
```

## Current Limitations

- **Runtime Architecture**: `xanonymous/mojo` is `linux/amd64` only (use emulation on ARM hosts).
- **WIP Engine**: CLI and engine components are still incomplete and may not pass the full test suite.

## Mojo-Specific Optimizations

1. **Integer piece encoding**: Uses integers instead of objects for pieces
2. **StaticTuple board**: Fixed-size array for O(1) access
3. **Value semantics**: Efficient copying without heap allocation
4. **Compile-time optimizations**: Mojo's compiler optimizes the code

## Comparison with Other Implementations

Compared to the Python version, this Mojo implementation offers:

- **Better performance**: Compiled to native code
- **Memory efficiency**: No GC overhead
- **Type safety**: Compile-time error detection
- **Similar syntax**: Easy to understand for Python developers

The code maintains the same command interface and behavior as other language implementations while showcasing Mojo's unique strengths in systems programming.

## Future Work

When Mojo becomes more widely available:
- Switch to an official Mojo runtime image
- Enable full interactive chess gameplay
- Add performance benchmarks comparing to other implementations
- Implement additional optimizations using Mojo's advanced features
