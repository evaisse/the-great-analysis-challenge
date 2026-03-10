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
# Enable rich evaluation from startup
cabal run chess -- --rich-eval
```

## Commands

- `move e2e4` - Make a move
- `ai 3` - AI makes a move at depth 3
- `fen <string>` - Load FEN position
- `export` - Export current position as FEN
- `eval` - Show position evaluation
- `rich-eval on|off` - Toggle rich evaluation during a session
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
- **Eval/** - Rich evaluation modules (tapered, mobility, pawn structure, king safety, positional)
- **Main.hs** - Command-line interface

The design emphasizes immutability - game states are never modified in place, but new states are created through pure functions. This makes the code easier to reason about and test.
