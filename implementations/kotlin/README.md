# Kotlin Chess Engine

A complete chess engine implementation in Kotlin following the Chess Engine Specification v1.0.

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- AI opponent with minimax algorithm and alpha-beta pruning
- FEN import/export support
- Performance testing with perft
- Object-oriented design with Kotlin's modern language features
- Null safety and immutable data structures
- Type-safe implementation with sealed classes and enums

## Local Development

### Prerequisites
- JDK 11 or higher
- Gradle (or use the included wrapper)

### Setup
```bash
./gradlew build
./gradlew run
```

## Docker Usage

### Build the Docker image
```bash
docker build -t chess-kotlin .
```

### Run interactively
```bash
docker run --network none -it chess-kotlin
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

- `Types.kt` - Core type definitions and data classes
- `Board.kt` - Board representation and game state management
- `MoveGenerator.kt` - Move generation and validation  
- `FenParser.kt` - FEN parsing and serialization
- `AI.kt` - AI engine with minimax/alpha-beta
- `Perft.kt` - Performance testing utilities
- `ChessEngine.kt` - Main engine and CLI interface

## Kotlin Language Features

This implementation showcases Kotlin's modern language features:

- **Data Classes**: Immutable game state with automatic copy functions
- **Sealed Classes**: Type-safe piece and move representations
- **Extension Functions**: Clean utility functions for chess operations
- **Null Safety**: Compile-time null checks prevent runtime errors
- **Smart Casts**: Automatic type casting based on checks
- **When Expressions**: Elegant pattern matching for piece movement
- **Collection APIs**: Functional programming with lists and maps

## Testing

The engine includes perft testing for move generation verification:
```bash
# In the chess engine
perft 4
```

Expected result: 197281 nodes for perft(4) from starting position.

## Implementation Notes

The Kotlin chess engine demonstrates object-oriented and functional programming:

- Data classes ensure immutable game states with structural equality
- Sealed classes provide type-safe piece and color representations  
- Extension functions add chess-specific operations to basic types
- Null safety prevents common chess programming errors
- Smart casts eliminate unnecessary type checking
- Functional collection operations make move generation clean and readable