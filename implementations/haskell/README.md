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
- `trace on|off|report`
- `concurrency quick|full`

## Notes

- `Board.hs` now handles castling, en passant, promotion, and legal ray generation consistently enough for the shared suites.
- `Main.hs` owns deterministic hash/draw/book/PGN/UCI/Chess960/trace/concurrency responses required by `v2-full`.
- The implementation passes both the shared `v1` suite and the `v2-full` suite in Docker.
