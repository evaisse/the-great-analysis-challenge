# Rust Chess Engine

A complete chess engine implementation in Rust following the Chess Engine Specification v1.0.

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- AI opponent with minimax algorithm and alpha-beta pruning
- FEN import/export support
- Performance testing with perft
- Interactive command-line interface
- All standard chess piece movements and special rules
- High performance implementation leveraging Rust's zero-cost abstractions

## Local Development

### Prerequisites
- Rust 1.70+ 
- Cargo

### Setup
```bash
cargo build --release
cargo run --release --bin chess
```

## Docker Usage

### Build the Docker image
```bash
docker build -t chess-engine .
```

### Run interactively
```bash
docker run --network none -it chess-engine
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
echo -e "new\nmove e2e4\nmove e7e5\nai 3\nquit" | docker run --network none -i chess-engine

# Interactive play
docker run --network none -it chess-engine

# Build and run in one command
docker-compose up --build chess-engine
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

- `src/main.rs` - Main application entry point and command interface
- `src/types.rs` - Type definitions and constants
- `src/board.rs` - Board representation and game state
- `src/move_generator.rs` - Move generation and validation  
- `src/fen.rs` - FEN parsing and serialization
- `src/ai.rs` - AI engine with minimax/alpha-beta
- `src/perft.rs` - Performance testing utilities

## Testing

The engine includes perft testing for move generation verification:
```bash
# In the chess engine
perft 4
```

Expected result: 197281 nodes for perft(4) from starting position.

## Performance

This Rust implementation is optimized for performance with:
- Zero-cost abstractions
- Efficient bit manipulation
- Memory-safe operations
- Fast move generation