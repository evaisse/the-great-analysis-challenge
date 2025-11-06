# Java Chess Engine Implementation

A command-line chess engine implemented in Java 17, following the specifications from [CHESS_ENGINE_SPECS.md](../../CHESS_ENGINE_SPECS.md).

## Features

- ✅ **perft** - Performance testing with recursive move generation
- ✅ **fen** - Forsyth-Edwards Notation support for position import/export
- ✅ **ai** - Artificial intelligence with minimax and alpha-beta pruning
- ✅ **castling** - Full kingside and queenside castling support
- ✅ **en_passant** - En passant pawn capture
- ✅ **promotion** - Pawn promotion (auto-queen or specified piece)

## Requirements

- Java 17 or higher
- Maven 3.6 or higher
- Docker (for containerized testing)

## Building

```bash
# Build with Maven
mvn clean package

# Or use make
make build
```

## Running

```bash
# Run directly
java -jar target/chess-1.0.0.jar

# Or use make
make run
```

## Docker

```bash
# Build Docker image
make docker-build

# Test in Docker
make docker-test
```

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `new` | Start new game | `new` |
| `move <from><to>` | Make a move | `move e2e4` |
| `move <from><to><piece>` | Move with promotion | `move e7e8Q` |
| `undo` | Undo last move | `undo` |
| `export` | Export FEN position | `export` |
| `fen <string>` | Load FEN position | `fen ...` |
| `ai <depth>` | AI makes move | `ai 3` |
| `eval` | Display evaluation | `eval` |
| `perft <depth>` | Performance test | `perft 4` |
| `help` | Show help | `help` |
| `quit` | Exit program | `quit` |

## Architecture

The implementation showcases Java's object-oriented design principles:

- **Object-Oriented Design**: Clear separation of concerns with Board, Piece, Move classes
- **Design Patterns**: Strategy pattern for piece movement, Command pattern for move history
- **Type Safety**: Strong typing with enums for piece types and colors
- **Collections Framework**: Efficient use of ArrayList, HashMap for game state
- **Stream API**: Modern Java 17 features for move generation and filtering

## Project Structure

```
java/
├── src/main/java/
│   ├── Chess.java          # Main entry point and command parser
│   ├── Board.java          # Chess board representation
│   ├── Piece.java          # Piece representation
│   ├── Move.java           # Move representation
│   ├── MoveGenerator.java  # Legal move generation
│   ├── AI.java             # Minimax AI implementation
│   └── FenParser.java      # FEN import/export
├── pom.xml                 # Maven configuration
├── Dockerfile              # Docker container definition
├── Makefile                # Build automation
└── README.md               # This file
```

## Testing

```bash
# Run unit tests
mvn test

# Run static analysis
mvn checkstyle:check pmd:check

# Or use make
make test
make analyze
```

## Performance

Expected performance metrics:
- **perft(4)**: ~500ms
- **AI depth 3**: <2s
- **AI depth 5**: <10s

## Implementation Notes

This Java implementation emphasizes:
- **Clarity**: Clean, readable code following Java conventions
- **Maintainability**: Well-documented classes and methods
- **Performance**: Efficient data structures and algorithms
- **Correctness**: Comprehensive validation of chess rules
