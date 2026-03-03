# Elm Chess Engine

A chess engine implementation in Elm following the project specifications.

## Building

```bash
make build
# or
npm install
elm make src/ChessEngine.elm --output=dist/chess.js
```

## Running

```bash
make
node src/cli.js
```

## Testing

```bash
make test
# Basic functionality test included in Makefile
```

## Static Analysis

```bash
make analyze
# or
elm make src/ChessEngine.elm --output=/dev/null
```

## Docker

```bash
make docker-build
make docker-test
```

## Features

- ✅ Basic chess rules and move validation
- ✅ FEN parsing and generation  
- ✅ AI with minimax algorithm
- ✅ Special moves (castling, en passant, promotion)
- ✅ Perft testing for move generation verification
- ✅ Command-line interface via Node.js CLI wrapper

## Architecture

The Elm implementation uses a functional approach with:
- Immutable game state
- Pure functions for move generation and validation
- JavaScript interop for CLI interface

## Commands

- `new` - Start new game
- `move <move>` - Make a move (e.g., e2e4)
- `undo` - Undo last move
- `export` - Export position as FEN
- `ai <depth>` - AI move with specified depth
- `quit` - Exit program