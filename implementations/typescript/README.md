# TypeScript Chess Engine

A complete chess engine implementation in TypeScript following the shared chess specification.

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- AI opponent with minimax algorithm and alpha-beta pruning
- FEN import/export support
- Performance testing with perft
- Interactive command-line interface
- All standard chess piece movements and special rules

## Development

Use the repository root Docker workflow for validation:

```bash
make image DIR=typescript
make build DIR=typescript
make analyze DIR=typescript
make test DIR=typescript
make test-chess-engine DIR=typescript
make test-chess-engine DIR=typescript TRACK=v2-system
```

For local work inside the implementation directory:

```bash
make build
make test
make analyze
```

## Docker Usage

### Build the Docker image
```bash
docker build -t chess-typescript .
```

### Run interactively
```bash
docker run --network none -it chess-typescript
```

### Using Docker Compose
```bash
# Run the chess engine
docker-compose up chess-engine

# Development mode with shell access
docker-compose run chess-dev
```

### Example Docker commands
```bash
# Quick game
echo -e "new\nmove e2e4\nmove e7e5\nai 3\nquit" | docker run --network none -i chess-typescript

# Interactive play
docker run --network none -it chess-typescript

# Build and run in one command
docker-compose up --build chess-engine
```

## Commands

- `status`, `hash`, `draws`, `history` - State/introspection surfaces
- `go movetime <ms>` - Time-managed search
- `pgn load|show|moves` - PGN command surface
- `book load|stats` - Opening book command surface
- `uci`, `isready`, `ucinewgame` - UCI handshake surface
- `new960 [id]`, `position960` - Chess960 metadata
- `trace on|off|level|report|reset|export|chrome` - Trace diagnostics
- `concurrency quick|full` - Deterministic concurrency fixture
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

- `src/types.ts` - Type definitions and constants
- `src/board.ts` - Board representation and game state
- `src/moveGenerator.ts` - Move generation and validation  
- `src/fen.ts` - FEN parsing and serialization
- `src/ai.ts` - AI engine with minimax/alpha-beta
- `src/perft.ts` - Performance testing utilities
- `src/chess.ts` - Main engine and command interface

## Testing

The engine includes perft testing for move generation verification:
```bash
# In the chess engine
perft 4
```

Expected result: 197281 nodes for perft(4) from starting position.
