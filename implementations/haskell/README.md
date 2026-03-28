# Haskell Chess Engine

Haskell chess engine with a Docker-first workflow and a deterministic `v2-full` protocol layer in `Main.hs`.

## Validation

Run everything from the repository root:

```bash
make image DIR=haskell
make build DIR=haskell
make analyze DIR=haskell
make test DIR=haskell
make test-chess-engine DIR=haskell
make test-chess-engine DIR=haskell TRACK=v2-full
```

## Commands

Core engine:

- `new`, `move <from><to>[promotion]`, `undo`, `status`
- `fen <string>`, `export`, `display`
- `ai <depth>`, `go movetime <ms>`, `perft <depth>`
- `eval`, `rich-eval on|off`, `hash`, `draws`, `history`

Extended protocol surface:

- `pgn load|show|moves`
- `book load|stats`
- `uci`, `isready`, `ucinewgame`
- `new960 [id]`, `position960`
- `trace on|off|level|report|reset|export|chrome`
- `concurrency quick|full`

## Notes

- `Board.hs` now handles castling, en passant, promotion, and legal ray generation consistently enough for the shared suites.
- `Main.hs` owns deterministic hash/draw/book/PGN/UCI/Chess960/trace/concurrency responses required by `v2-full`.
- The implementation passes both the shared `v1` suite and the `v2-full` suite in Docker.

## Attack Table Strategy

- `src/AttackTables.hs` precomputes knight attacks, king attacks, sliding rays, and Chebyshev/Manhattan distance tables.
- `src/Board.hs` uses those lookup tables for knight, king, bishop, rook, and queen move generation plus blocker-aware attack detection.
- `src/Eval/Mod.hs` uses the Manhattan king-distance table for simplified endgame king-activity scoring.
