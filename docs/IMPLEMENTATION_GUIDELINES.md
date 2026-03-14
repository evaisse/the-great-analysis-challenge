# Chess Engine Implementation Guidelines

This guide is the practical checklist for adding or maintaining a language implementation.

## Required Inputs

- Specification: [CHESS_ENGINE_SPECS.md](../CHESS_ENGINE_SPECS.md)
- AI behavior: [AI_ALGORITHM_SPEC.md](../AI_ALGORITHM_SPEC.md)
- Contribution process: [CONTRIBUTING.md](CONTRIBUTING.md)

## Mandatory Constraints

- Docker-first workflow for all implementation operations.
- No language-specific branching in root infrastructure.
- Standard library only for chess engine logic.
- No ad-hoc external downloads in Dockerfiles.

## Required Layout

```text
implementations/<language>/
├── Dockerfile
├── Makefile
├── README.md
└── source files
```

## Required Make Targets

Implementation `Makefile` must provide at least:
- `make` (default build/prep)
- `make test`
- `make analyze`
- `make clean`
- `make docker-build`
- `make docker-test`

Root integration commands use:
- `make image DIR=<language>`
- `make build DIR=<language>`
- `make analyze DIR=<language>`
- `make test DIR=<language>`
- `make test-chess-engine DIR=<language>`

## Required Engine Commands

Every implementation must support:
- `new`
- `move <from><to>[promotion]` (e.g. `move e2e4`, `move e7e8q`)
- `undo`
- `export`
- `ai <depth>` (1..5)
- `quit`

Board rendering, move legality, error messages, and output format must match the authoritative spec.

## Required Docker Labels

`Dockerfile` metadata must include:
- `org.chess.language`
- `org.chess.version`
- `org.chess.author`
- `org.chess.features`
- `org.chess.max_ai_depth`
- `org.chess.estimated_perft4_ms`
- `org.chess.build`
- `org.chess.test`
- `org.chess.analyze`
- `org.chess.run`

Optional benchmark labels:
- `org.chess.bugit`
- `org.chess.fix`

## Functional Requirements Checklist

- Correct board state representation and turn tracking
- Full legal move generation
- Castling, en passant, promotion
- FEN parser + serializer
- Check/checkmate/stalemate detection
- Deterministic minimax + alpha-beta AI
- `perft 4` result equals `197281`
- Robust invalid input handling

## Recommended Build Sequence

1. Board + move representation
2. Move generation and legality filtering
3. State transitions (`move`, `undo`)
4. FEN import/export
5. CLI command loop + board display
6. AI search and evaluation
7. Edge-case hardening + optimization

## Validation Sequence

```bash
make image DIR=<language>
make build DIR=<language>
make analyze DIR=<language>
make test DIR=<language>
make test-chess-engine DIR=<language>
make bugit DIR=<language>
make fix DIR=<language>
make benchmark-analysis-error DIR=<language>
```

Manual smoke checks:

```bash
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run --network none -i chess-<language>
echo -e "new\nai 3\nquit" | docker run --network none -i chess-<language>
echo -e "new\nperft 4\nquit" | docker run --network none -i chess-<language>
```

## Common Failure Modes

- Incorrect castling preconditions
- En passant allowed outside immediate window
- Promotion handling without default queen fallback
- Illegal move accepted while king remains in check
- Coordinate orientation mistakes (`a1` baseline)
- Output buffering issues in interactive protocol
