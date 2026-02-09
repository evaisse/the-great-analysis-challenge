# Swift Chess Engine

A complete chess engine implementation in Swift following the Chess Engine Specification v1.0.

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- AI opponent with minimax algorithm and alpha-beta pruning
- FEN import/export support
- Performance testing with perft
- Interactive command-line interface
- All standard chess piece movements and special rules
- Native Swift performance and type safety

## Local Development

### Prerequisites
- Swift 5.5+ 
- Swift Package Manager

### Setup
```bash
swift build -c release
.build/release/Chess
```

### Development and Testing
```bash
# Build for development
swift build

# Run tests
swift test

# Build and run
swift run Chess
```

## Docker Usage

### Build the Docker image
```bash
docker build -t chess-engine .
```

### Run interactively
```bash
docker run -it chess-engine
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
echo -e "new\nmove e2e4\nmove e7e5\nai 3\nquit" | docker run -i chess-engine

# Interactive play
docker run -it chess-engine

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

- `src/main.swift` - Main application entry point and chess engine implementation
- `Package.swift` - Swift Package Manager configuration
- `Tests/ChessTests/` - Unit tests for the chess engine

## Testing

The engine includes perft testing for move generation verification:
```bash
# In the chess engine
perft 4
```

Expected result: 197281 nodes for perft(4) from starting position.

## Performance

This Swift implementation leverages:
- Strong type system for correctness
- Value types for performance
- Memory safety
- Native compilation for speed