# Lua Chess Engine Implementation

A complete command-line chess engine implementation in Lua 5.4, featuring AI with minimax algorithm, FEN support, and all standard chess rules including castling, en passant, and pawn promotion.

## Features

- ✅ **Complete Chess Rules**: All standard moves including castling, en passant, and promotion
- ✅ **AI Engine**: Minimax algorithm with alpha-beta pruning (depths 1-5)
- ✅ **FEN Support**: Import and export positions using Forsyth-Edwards Notation
- ✅ **Performance Testing**: Perft function for move generation validation
- ✅ **Move Validation**: Full legal move checking with king safety
- ✅ **Interactive CLI**: Easy-to-use command-line interface

## Implementation Details

### Language Features

This implementation showcases Lua's strengths:

- **Tables as Data Structures**: Uses Lua tables for board representation and game state
- **Lightweight and Fast**: Efficient execution with minimal overhead
- **Simple Syntax**: Clean, readable code following Lua conventions
- **Dynamic Typing**: Flexible type system for game state management
- **First-Class Functions**: Functions as values for move generation and evaluation

### Architecture

- **Board Representation**: 8x8 table (indexed 1-8 in Lua style)
- **Move Generation**: Iterates through all pieces to generate legal moves
- **AI Evaluation**: Material counting with position bonuses
- **State Management**: Tables for castling rights, en passant, and move history

## Building and Running

### Prerequisites

- Docker (recommended)
- Or Lua 5.4 installed locally

### Using Docker (Recommended)

Build and test the implementation:

```bash
make docker-build
make docker-test
```

Run interactively:

```bash
docker run --network none -it chess-lua
```

### Local Development

Install Lua 5.4:

```bash
# Ubuntu/Debian
sudo apt-get install lua5.4

# macOS
brew install lua@5.4
```

Build and test:

```bash
make build
make test
```

Run the chess engine:

```bash
lua5.4 chess.lua
```

## Usage

### Available Commands

```
new              - Start a new game
move <from><to>  - Make a move (e.g., 'move e2e4')
undo             - Undo last move
display          - Show the board
export           - Export position as FEN
fen <string>     - Load position from FEN
ai <depth>       - AI makes a move (depth 1-5)
eval             - Show position evaluation
perft <depth>    - Performance test
help             - Show help message
quit             - Exit the program
```

### Example Session

```lua
> new
  a b c d e f g h
8 r n b q k b n r 8
7 p p p p p p p p 7
6 . . . . . . . . 6
5 . . . . . . . . 5
4 . . . . . . . . 4
3 . . . . . . . . 3
2 P P P P P P P P 2
1 R N B Q K B N R 1
  a b c d e f g h

White to move

> move e2e4
OK: e2e4

> ai 3
AI: e7e5 (depth=3, eval=0, time=150ms)

> export
FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2
```

### Testing Special Moves

#### Castling
```lua
> fen r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1
> move e1g1  # Kingside castling
```

#### En Passant
```lua
> fen rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3
> move e5f6  # En passant capture
```

#### Promotion
```lua
> fen 8/P7/8/8/8/8/8/8 w - - 0 1
> move a7a8Q  # Promote to queen (or specify R/B/N)
```

## Makefile Targets

- `make` or `make build` - Check syntax and validate code
- `make test` - Run basic functionality tests
- `make analyze` - Run static analysis
- `make clean` - Clean build artifacts
- `make docker-build` - Build Docker image
- `make docker-test` - Test in Docker container

## Performance

The Lua implementation is designed for clarity and correctness while maintaining good performance:

- **Perft(4)**: ~1000ms (197,281 positions)
- **AI Depth 3**: ~2s for typical positions
- **AI Depth 5**: ~10s for typical positions

## Code Structure

The implementation is contained in a single file (`chess.lua`) for simplicity:

- **Board Representation**: 8x8 table with piece characters
- **Move Generation**: `generate_legal_moves()` with full validation
- **Move Execution**: `make_move_internal()` with undo support
- **AI Engine**: `minimax()` with alpha-beta pruning
- **FEN Support**: `import_fen()` and `export_fen()`
- **Command Loop**: `main()` with interactive CLI

## Testing

Run the test suite:

```bash
make test
```

Or test manually:

```bash
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | lua5.4 chess.lua
```

Expected output should include:
```
FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2
```

## Lua-Specific Features

### Tables
Lua's table data structure is used extensively:
- Board representation
- Move history
- Castling rights
- Generated moves list

### 1-Based Indexing
Following Lua convention, arrays are 1-indexed (ranks 1-8, files 1-8).

### Pattern Matching
Lua's string pattern matching is used for FEN parsing and command parsing.

### Closures
Local functions capture game state through Lua's closure mechanism.

## Contributing

Follow the project's standard guidelines in `README_IMPLEMENTATION_GUIDELINES.md`.

## License

Part of the Great Analysis Challenge project. See repository root for license information.
