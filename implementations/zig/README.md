# Zig Chess Engine

A high-performance chess engine implementation in Zig, showcasing the language's systems programming capabilities and zero-cost abstractions.

## Features

- **Complete Chess Rules**: All standard chess rules including castling, en passant, and promotion
- **AI Engine**: Minimax algorithm with alpha-beta pruning (depths 1-5)
- **FEN Support**: Full import/export of chess positions using Forsyth-Edwards Notation
- **Performance Testing**: Perft functionality for move generation verification
- **Memory Safety**: Leverages Zig's compile-time safety features
- **High Performance**: Compiled to optimized native machine code

## Building

### Prerequisites
- Zig 0.13.0 or later

### Build Commands

```bash
# Build the chess engine
zig build

# Build in release mode (optimized)
zig build -Doptimize=ReleaseFast

# Run the chess engine
zig build run

# Run tests
zig build test
```

### Direct Execution

```bash
# Run directly from source
zig run src/main.zig
```

## Usage

The chess engine supports the following commands:

- `new` - Start a new game
- `move <from><to>[promotion]` - Make a move (e.g., e2e4, e7e8Q)
- `undo` - Undo the last move
- `ai <depth>` - AI makes a move (depth 1-5)
- `fen <string>` - Load position from FEN notation
- `export` - Export current position as FEN
- `eval` - Display position evaluation
- `perft <depth>` - Performance test (move count)
- `help` - Display available commands
- `quit` - Exit the program

## Example Session

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

> move e2e4
OK: e2e4

> move e7e5
OK: e7e5

> ai 3
AI: Nf3 (depth=3, eval=25, time=150ms)

> export
FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2
```

## Docker Usage

```bash
# Build Docker image
docker build -t chess-zig .

# Run the chess engine
docker run --network none -it chess-zig
```

## Performance

Zig's performance characteristics make it excellent for chess engines:

- **Compilation Speed**: Fast builds during development
- **Runtime Performance**: Zero-cost abstractions and manual memory management
- **Memory Safety**: Compile-time bounds checking without runtime overhead
- **Cross-platform**: Compiles to native code for multiple architectures

## Architecture

The implementation is organized into several modules:

- `main.zig` - Main game loop and command processing
- `board.zig` - Board representation and basic move handling
- `move_generator.zig` - Legal move generation for all piece types
- `ai.zig` - Minimax algorithm with alpha-beta pruning
- `fen.zig` - FEN notation parsing and generation
- `perft.zig` - Performance testing and move counting

## Language Features Demonstrated

This implementation showcases several Zig language features:

- **Comptime**: Compile-time execution for optimal performance
- **Optional Types**: Safe null handling with `?T` syntax
- **Error Handling**: Explicit error types and propagation
- **Memory Management**: Manual allocation with safety guarantees
- **Packed Structs**: Efficient memory layout for game state
- **Generics**: Type-safe containers and algorithms

## Test Verification

The engine passes all standard chess engine tests:

- **Perft(4)**: 197,281 nodes from starting position
- **Legal Move Generation**: Handles all chess rules correctly
- **FEN Import/Export**: Round-trip compatibility
- **AI Tactical Awareness**: Finds basic tactics at depth 3+

## Contributing

This implementation follows the Chess Engine Specification v1.0. When making changes:

1. Ensure all tests pass
2. Maintain performance benchmarks
3. Follow Zig coding conventions
4. Update documentation as needed