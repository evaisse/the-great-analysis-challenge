# Zig Chess Engine

Zig implementation of the shared chess engine spec with both the historical `v1` suite and the `v2-full` surface validated in Docker.

## Validated Features

- Core chess rules: castling, en passant, promotion, FEN, perft, minimax AI
- Extended `v2-full` surface: `hash`, `draws`, `history`, `go movetime`, `pgn`, `book`, `uci`, `isready`, `ucinewgame`, `new960`, `position960`, `trace`, `concurrency`
- Harness-friendly CLI: no startup board dump, no prompt noise, deterministic line-based responses

## Docker Workflow

Run all project validation from the repository root:

```bash
make image DIR=zig
make build DIR=zig
make analyze DIR=zig
make test DIR=zig
make test-chess-engine DIR=zig TRACK=v1
make test-chess-engine DIR=zig TRACK=v2-full
```

## Example Usage

```bash
printf 'new\nmove e2e4\nhash\nbook load /repo/test/fixtures/book/opening.book\nai 3\nquit\n' | docker run --rm --network none -i chess-zig
```

## Commands

- `new`, `move <from><to>[promotion]`, `undo`, `status`, `fen <string>`, `export`
- `hash`, `draws`, `history`, `eval`, `ai <depth>`, `go movetime <ms>`
- `pgn load|show|moves`, `book load|stats|on|off`, `uci`, `isready`, `ucinewgame`
- `new960 [id]`, `position960`, `trace on|off|report`, `concurrency quick|full`
- `perft <depth>`, `help`, `quit`

## Files

- `src/main.zig`: CLI dispatcher, runtime state, and perft/status helpers
- `src/board.zig`: board state, attack detection, and move application
- `src/move_generator.zig`: pseudo-legal move generation
- `src/ai.zig`: filtered legal move search with alpha-beta pruning
- `src/fen.zig`: FEN import/export
