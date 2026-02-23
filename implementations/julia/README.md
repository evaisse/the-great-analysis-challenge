# Julia Chess Engine

A complete chess engine implementation in Julia, featuring:

- Full chess rules implementation (moves, castling, en passant, promotion)
- AI with minimax algorithm and alpha-beta pruning (depths 1-5)
- FEN import/export support
- Performance testing (perft) 
- Command-line interface

## Requirements

- Julia 1.9 or later

## Running

```bash
julia chess.jl
```

## Docker

```bash
docker build -t chess-julia .
docker run --network none -it chess-julia
```

## Commands

- `new` - Start a new game
- `move <from><to>` - Make a move (e.g., `move e2e4`)
- `undo` - Undo the last move
- `ai <depth>` - AI makes a move (depth 1-5)
- `fen <string>` - Load position from FEN
- `export` - Export current position as FEN
- `eval` - Display position evaluation
- `perft <depth>` - Performance test (move count)
- `help` - Display available commands
- `quit` - Exit the program

## Features

- **Paradigm**: High-performance dynamic programming
- **Key Features**: Multiple dispatch, metaprogramming, scientific computing optimizations
- **Build Time**: ~0-2 seconds (interpreted/JIT compiled)