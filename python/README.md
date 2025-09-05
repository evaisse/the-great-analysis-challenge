# Python Chess Engine

A complete chess engine implementation in Python following the Chess Engine Specification v1.0.

## Features

- ✅ **Complete Chess Rules**: All standard chess moves including castling, en passant, and promotion
- ✅ **AI with Minimax**: Alpha-beta pruning with configurable depth (1-5)
- ✅ **FEN Support**: Import/export positions using standard FEN notation
- ✅ **Move Validation**: Ensures all moves are legal according to chess rules
- ✅ **Game State Management**: Undo moves, detect checkmate/stalemate
- ✅ **Performance Testing**: Perft function for move generation validation
- ✅ **Static Analysis**: Comprehensive code quality tools

## Quick Start

```bash
# Run the chess engine
python3 chess.py

# Run with Docker
docker build -t chess-python .
docker run -it chess-python

# Run static analysis
python3 analyze.py
```

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `move <from><to>[promotion]` | Make a move | `move e2e4`, `move e7e8Q` |
| `undo` | Undo the last move | `undo` |
| `new` | Start a new game | `new` |
| `ai <depth>` | AI makes a move | `ai 3` |
| `fen <string>` | Load position from FEN | `fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` |
| `export` | Export current position as FEN | `export` |
| `eval` | Display position evaluation | `eval` |
| `perft <depth>` | Performance test | `perft 4` |
| `help` | Display available commands | `help` |
| `quit` | Exit the program | `quit` |

## Performance Benchmarks

From starting position:
- **Perft(1)**: 20 nodes
- **Perft(2)**: 400 nodes  
- **Perft(3)**: 8,902 nodes
- **AI depth 3**: ~200ms response time

## Static Analysis Tools

The implementation includes comprehensive static analysis:

- **mypy**: Type checking for better code safety
- **pylint**: Code quality and style analysis
- **flake8**: Style guide enforcement (PEP 8)
- **black**: Automatic code formatting
- **bandit**: Security vulnerability scanning

## Architecture

```
chess.py              # Main entry point and command interface
lib/
├── types.py          # Type definitions and data classes
├── board.py          # Board representation and game state
├── move_generator.py # Legal move generation for all pieces
├── fen_parser.py     # FEN import/export functionality
├── ai.py             # Minimax AI with alpha-beta pruning
└── perft.py          # Performance testing for validation
```

## Testing

```bash
# Test basic functionality
python3 test_engine.py

# Test specific features
python3 chess.py <<EOF
new
move e2e4
move e7e5
ai 3
export
quit
EOF
```

## Docker Usage

```bash
# Build image
docker build -t chess-python .

# Run chess engine
docker run -it chess-python

# Run static analysis
docker run --rm chess-python ./analyze

# Run specific analysis tool
docker run --rm chess-python python3 -m mypy .
```

## Compliance

This implementation fully complies with the Chess Engine Specification v1.0:

- ✅ All required commands implemented
- ✅ Standard chess rules including special moves
- ✅ FEN import/export support
- ✅ AI with minimax and alpha-beta pruning  
- ✅ Perft validation (correct node counts)
- ✅ Proper error handling and game state management
- ✅ ASCII board display with coordinate labels