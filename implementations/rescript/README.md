# ReScript Chess Engine

A ReScript chess engine implementation with the shared core chess spec and the current `v2-full` protocol surface.

## Features

- Core chess engine parity: `perft`, `fen`, `ai`, `castling`, `en_passant`, `promotion`
- Protocol features: `pgn`, `uci`, `chess960`
- System surfaces: deterministic `hash`, `draws`, `history`, `trace`, and `concurrency`
- Precomputed knight, king, sliding-ray, and Manhattan distance lookup tables
- Opening-book and time-managed search command surfaces for the shared harness

## Validation

Run validation from the repository root with the shared Docker-first workflow:

```bash
make image DIR=rescript
make build DIR=rescript
make analyze DIR=rescript
make test DIR=rescript
make test-chess-engine DIR=rescript TRACK=v2-full
```

## Runtime

Build the image directly from this implementation directory if needed:

```bash
docker build -t chess-rescript .
echo -e "new\nmove e2e4\nmove e7e5\nai 3\nquit" | docker run --network none -i chess-rescript
```

## Commands

- `move <from><to>[promotion]` - Make a move (e.g., e2e4, e7e8Q)
- `undo` - Undo the last move
- `new` - Start a new game  
- `ai <depth>` - Let AI make a move (depth 1-5)
- `go movetime <ms>` - Time-managed search
- `fen <string>` - Load position from FEN
- `export` - Export current position as FEN
- `eval` - Evaluate current position
- `hash` - Show current position hash
- `draws` - Show draw counters
- `history` - Show position history summary
- `pgn load|show|moves` - PGN command surface
- `book load|stats` - Opening-book command surface
- `uci` / `isready` / `ucinewgame` - UCI protocol surface
- `new960 [id]` / `position960` - Chess960 metadata surface
- `trace on|off|level|report|reset|export|chrome` - Trace command surface
- `concurrency quick|full` - Deterministic concurrency fixture
- `status` - Show current game status
- `perft <depth>` - Run performance test
- `help` - Show available commands
- `quit` - Exit the program

## Architecture

- `src/Chess.res` - Main chess engine implementation
- `src/Node.res` - Node.js bindings and utilities

## Testing

The implementation passes the shared `v2-full` chess-engine harness, including PGN, book, UCI, Chess960, trace, and concurrency command surfaces.
