# Elm Chess Engine

Elm chess engine with a small Node protocol runner for stdin/stdout integration.

## Validation

Run everything from the repository root:

```bash
make image DIR=elm
make build DIR=elm
make analyze DIR=elm
make test DIR=elm
make test-chess-engine DIR=elm
make test-chess-engine DIR=elm TRACK=v2-full
```

## Commands

Core engine:

- `new`, `move <from><to>[promotion]`, `undo`, `status`
- `fen <string>`, `export`, `display`
- `ai <depth>`, `go movetime <ms>`, `perft <depth>`
- `eval`, `hash`, `draws`, `history`

Extended protocol surface:

- `pgn load|show|moves`
- `book load|stats`
- `uci`, `isready`, `ucinewgame`
- `new960 [id]`, `position960`
- `trace on|off|level|report|reset|export|chrome`
- `concurrency quick|full`

## Notes

- The Elm modules implement board state, legal move generation, FEN handling, and search.
- The Node runner keeps the `v2-full` protocol surface deterministic for the shared harness.
- The Docker image vendors the exact Elm package cache required by `elm.json`, so fresh builds stay reproducible even when `package.elm-lang.org` is unavailable.
- The image builds the Elm program with `--optimize` to avoid dev-mode runtime noise.

## Attack Table Strategy

- `src/AttackTables.elm` precomputes knight attacks, king attacks, sliding rays, and Chebyshev/Manhattan distance tables at startup.
- `src/MoveGenerator.elm` uses those lookup tables for move generation and attack detection instead of recalculating offsets on each query.
- `src/Evaluation.elm` uses the Manhattan king-distance table for simplified endgame scoring.
