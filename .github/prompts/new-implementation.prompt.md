# New Chess Engine Implementation

Implement a chess engine in a new programming language following the project specifications.

## Required Reading

Before starting, read these specification files:
- [Chess Engine Specs](../../CHESS_ENGINE_SPECS.md)
- [AI Algorithm Spec](../../AI_ALGORITHM_SPEC.md)
- [Implementation Guidelines](../../README_IMPLEMENTATION_GUIDELINES.md)
- [Contributing Guide](../../CONTRIBUTING.md)

## Implementation Order

1. **Setup**: Create `implementations/<language>/` with Dockerfile, Makefile, chess.meta, README.md
2. **Board representation**: 8x8 grid, piece tracking (K/Q/R/B/N/P uppercase White, lowercase Black)
3. **Move generator**: Pseudo-legal moves for all piece types, then filter illegal moves (king in check)
4. **Special moves**: Castling (all FIDE conditions), en passant, pawn promotion (default to Queen)
5. **FEN parser**: Import and export positions (all 6 FEN fields)
6. **Game state**: Execute/undo moves, checkmate/stalemate detection
7. **Command interface**: stdin/stdout protocol per spec, flush after each output
8. **AI engine**: Minimax with alpha-beta pruning, piece-square tables, depths 1-5

## Reference Implementations

Study these for patterns:
- [Ruby](../../implementations/ruby/) — Clean OOP
- [TypeScript](../../implementations/typescript/) — Typed, modern JS
- [Rust](../../implementations/rust/) — High performance, ownership
- [Python](../../implementations/python/) — Readable, Pythonic

## Validation

After implementing, verify:
- `make docker-build` succeeds
- `echo -e "new\nperft 4\nquit" | docker run -i chess-<lang>` returns 197281
- `echo -e "new\nai 3\nquit" | docker run -i chess-<lang>` makes a legal move
- All commands work: new, move, undo, ai, fen, export, help, quit
