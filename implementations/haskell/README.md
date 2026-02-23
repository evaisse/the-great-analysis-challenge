# Haskell Chess Engine

A functional programming implementation of a chess engine showcasing Haskell's strengths:

- **Pure functions** for game logic
- **Immutable state** with functional updates  
- **Strong typing** with algebraic data types
- **Pattern matching** for move validation
- **Monadic I/O** for command interface

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- Minimax AI with alpha-beta pruning (depths 1-5)
- FEN import/export support
- Performance testing (perft)
- Command-line interface

## Building

```bash
cabal build
```

## Running

```bash
cabal run chess
```

## Commands

- `move e2e4` - Make a move
- `ai 3` - AI makes a move at depth 3
- `fen <string>` - Load FEN position
- `export` - Export current position as FEN
- `eval` - Show position evaluation
- `perft 4` - Performance test at depth 4
- `help` - Show all commands
- `quit` - Exit

## Docker

```bash
docker build -t chess-haskell .
docker run --network none -it chess-haskell
```

## Architecture

The implementation follows functional programming principles:

- **Types.hs** - Core data types (Board, Piece, Move, GameState)
- **Board.hs** - Game state management and move validation
- **FEN.hs** - FEN string parsing and serialization
- **MoveGenerator.hs** - Move generation and basic evaluation
- **AI.hs** - Minimax search with alpha-beta pruning
- **Perft.hs** - Performance testing utilities
- **Main.hs** - Command-line interface

The design emphasizes immutability - game states are never modified in place, but new states are created through pure functions. This makes the code easier to reason about and test.