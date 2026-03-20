# Swift Chess Engine

Swift implementation of the shared chess engine spec with the `v2-full` command surface validated in Docker.

## Validated Features

- Core chess rules: castling, en passant, promotion, FEN, perft, minimax AI
- Extended `v2-full` surface: `hash`, `draws`, `history`, `go movetime`, `pgn`, `book`, `uci`, `isready`, `ucinewgame`, `new960`, `position960`, `trace`, `concurrency`
- Harness-friendly CLI: no startup board dump, no prompt noise, flushed line-based responses

## Docker Workflow

Run all project validation from the repository root:

```bash
make image DIR=swift
make build DIR=swift
make analyze DIR=swift
make test DIR=swift
make test-chess-engine DIR=swift TRACK=v2-full
```

## Example Usage

```bash
printf 'new\nmove e2e4\nhash\npgn show\nquit\n' | docker run --rm --network none -i chess-swift
```

## Commands

- `new`, `move <from><to>[promotion]`, `undo`, `status`, `fen <string>`, `export`
- `hash`, `draws`, `history`, `eval`, `ai <depth>`, `go movetime <ms>`
- `pgn load|show|moves`, `book load|stats`, `uci`, `isready`, `ucinewgame`
- `new960 [id]`, `position960`, `trace on|off|level|report|reset|export|chrome`, `concurrency quick|full`
- `perft <depth>`, `help`, `quit`

## Files

- `src/main.swift`: engine, CLI dispatcher, and `v2-full` runtime helpers
- `Package.swift`: Swift package definition
