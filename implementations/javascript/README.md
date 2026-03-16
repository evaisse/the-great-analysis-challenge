# JavaScript Chess Engine

Pure JavaScript implementation of the shared chess engine specification.

## Features
- Full move generation
- FEN import/export
- Basic minimax AI
- Standard CLI, test, and analysis workflow

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
