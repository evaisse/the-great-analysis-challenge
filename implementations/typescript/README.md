# TypeScript Chess Engine

A complete chess engine implementation in TypeScript following the Chess Engine Specification v1.0.

## Features

- Complete chess rules implementation (castling, en passant, promotion)
- AI opponent with minimax algorithm and alpha-beta pruning
- FEN import/export support
- Performance testing with perft
- Interactive command-line interface
- All standard chess piece movements and special rules

## Local Development

### Prerequisites
- Node.js 18+ 
- npm

### Setup
```bash
npm install
npm run build
npm start
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

### Core Modules
- `src/types.ts` - Legacy type definitions (re-exports from src/types/)
- `src/types/` - **Type-safe modeling system (PRD-04)**
  - `square.ts` - Branded Square, Rank, File types
  - `piece.ts` - Color, PieceType, Piece types
  - `move.ts` - Move<Legal> / Move<Unchecked> validation states
  - `castling.ts` - Type-safe castling rights
  - `boardState.ts` - Board<WhiteToMove> / Board<BlackToMove> phantom types
- `src/board.ts` - Board representation and game state
- `src/moveGenerator.ts` - Move generation and validation  
- `src/fen.ts` - FEN parsing and serialization
- `src/ai.ts` - AI engine with minimax/alpha-beta
- `src/perft.ts` - Performance testing utilities
- `src/chess.ts` - Main engine and command interface

### Type System

The engine uses advanced TypeScript features for compile-time safety:

**Branded Types** - Prevent mixing incompatible values:
```typescript
type Square = number;  // 0-63 only (branded in strict mode)
type Rank = number;    // 0-7 only
type File = number;    // 0-7 only
```

**Validation States** - Track move validation at type level:
```typescript
Move<Unchecked>  // Raw, unvalidated move
Move<Legal>      // Validated, legal move
```

**Phantom Types** - Encode board state in types:
```typescript
BoardState<WhiteToMove>  // White's turn
BoardState<BlackToMove>  // Black's turn
```

See `TYPE_SAFE_MODELING.md` for full documentation.

## Testing

The engine includes perft testing for move generation verification:
```bash
# In the chess engine
perft 4
```

Expected result: 197281 nodes for perft(4) from starting position.