# C Chess Engine

C implementation of the shared `v1` chess engine specification.

## Highlights

- Standard-library-only engine logic
- Legal move generation with castling, en passant, and promotion
- FEN import/export
- Alpha-beta minimax AI (depth 1..5)
- Snapshot-based undo and repetition tracking
- Docker-first build and validation

## Repository Workflow

Run all validation from the repository root:

```bash
make image DIR=c
make build DIR=c
make analyze DIR=c
make test DIR=c
make test-chess-engine DIR=c
```

## Commands

- `new`
- `move <from><to>[promotion]`
- `undo`
- `status`
- `fen <string>`
- `export`
- `eval`
- `hash`
- `draws`
- `history`
- `ai <depth>`
- `perft <depth>`
- `help`
- `quit`

## Local Development

```bash
cd implementations/c
make build
./chess
```

Run the built-in self-test:

```bash
make test
```

## Implementation Notes

- The board uses a flat 64-square array with FEN-compatible piece characters.
- Move legality is validated by applying candidate moves on board copies and rejecting positions that leave the side to move in check.
- `undo` restores full board snapshots, which keeps the engine simple and reliable for CLI usage, perft, and search.
