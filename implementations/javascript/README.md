# JavaScript Chess Engine

Pure JavaScript implementation of the shared chess engine specification.

## Features
- Full move generation with castling, en passant, and promotion
- FEN import/export
- Deterministic minimax AI
- `v2-full` protocol surface for `hash`, `draws`, `history`, `go`, `pgn`, `book`, `uci`, `new960`, `trace`, and `concurrency`
- Standard Docker-based build, test, and analysis workflow

## Development
Use the repository root Docker workflow for validation:

```bash
make image DIR=javascript
make build DIR=javascript
make analyze DIR=javascript
make test DIR=javascript
make test-chess-engine DIR=javascript
```

For local work inside the implementation directory:

```bash
make build
make test
make analyze
```
