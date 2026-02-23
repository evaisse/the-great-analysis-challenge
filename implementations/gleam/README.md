# Gleam Chess Engine

A complete chess engine implementation in Gleam following the Chess Engine Specification v1.0.

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- AI opponent with minimax algorithm and alpha-beta pruning
- FEN import/export support
- Performance testing with perft
- Functional programming approach with immutable data structures
- Type-safe implementation showcasing Gleam's features

## Local Development

### Prerequisites
- Gleam >= 1.0.0
- Erlang >= 26

### Setup
```bash
gleam run
```

## Docker Usage

### Build the Docker image
```bash
docker build -t chess-gleam .
```

### Run interactively
```bash
docker run --network none -it chess-gleam
```

## Commands

- `move <from><to>[promotion]` - Make a move (e.g., e2e4, e7e8Q)
- `undo` - Undo the last move
- `new` - Start a new game  
- `ai <depth>` - Let AI make a move (depth 1-5)
- `fen <string>` - Load position from FEN
- `export` - Export current position as FEN
- `eval` - Evaluate current position
- `perft <depth>` - Run performance test
- `help` - Show available commands
- `quit` - Exit the program

## Architecture

- `src/types.gleam` - Core type definitions and constants
- `src/board.gleam` - Board representation and game state
- `src/move_generator.gleam` - Move generation and validation  
- `src/fen.gleam` - FEN parsing and serialization
- `src/ai.gleam` - AI engine with minimax/alpha-beta
- `src/perft.gleam` - Performance testing utilities
- `src/chess_engine.gleam` - Main engine and command interface

## Gleam Language Features

This implementation showcases Gleam's functional programming strengths:

- **Immutable Data Structures**: All game state changes create new instances
- **Pattern Matching**: Elegant piece movement and command parsing
- **Type Safety**: Compile-time guarantees for chess rules
- **Functional Style**: Pure functions with no side effects where possible
- **Result Types**: Proper error handling without exceptions

## Testing

The engine includes perft testing for move generation verification:
```bash
# In the chess engine
perft 4
```

Expected result: 197281 nodes for perft(4) from starting position.

## Implementation Notes

The Gleam chess engine demonstrates functional programming principles:

- All board operations are pure functions returning new game states
- Pattern matching is used extensively for piece movement logic
- Type safety ensures invalid game states cannot be represented
- Recursive algorithms for move generation and AI search
- Immutable data structures prevent accidental state mutations