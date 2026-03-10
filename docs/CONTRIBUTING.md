# Contributing to The Great Analysis Challenge

This project compares equivalent chess engines across languages. Contributions must preserve cross-language fairness and Docker reproducibility.

## Core Rules

- Follow [CHESS_ENGINE_SPECS.md](../CHESS_ENGINE_SPECS.md) and [AI_ALGORITHM_SPEC.md](../AI_ALGORITHM_SPEC.md).
- Build/test/analyze implementations via Docker commands only.
- Avoid language-specific logic in root tooling (`Makefile`, shared scripts).
- Keep implementation logic standard-library only.
- Do not add non-package-manager external downloads in Dockerfiles.

## Contribution Types

- New implementation under `implementations/<language>/`
- Bug fixes in existing implementation or shared tooling
- Performance improvements with before/after evidence
- Documentation and testing improvements

## Quick Workflow

1. Fork and clone the repository.
2. Create a feature branch from `main`.
3. Make focused changes.
4. Validate with Docker-based commands.
5. Open a PR with clear summary and test evidence.

## Adding a New Language Implementation

Required files:
- `implementations/<language>/Dockerfile`
- `implementations/<language>/Makefile`
- `implementations/<language>/README.md`
- Source files (entrypoint + modules)

Required Docker labels:
- `org.chess.language`
- `org.chess.version`
- `org.chess.author`
- `org.chess.features`
- `org.chess.max_ai_depth`
- `org.chess.estimated_perft4_ms`
- `org.chess.build`
- `org.chess.test`
- `org.chess.analyze`
- `org.chess.run` (or inferable from `CMD`)

Implementation checklist:
- Commands: `new`, `move`, `undo`, `ai`, `export`, `quit`
- Full legal move generation including castling, en passant, promotion
- FEN import/export correctness
- Check/checkmate/stalemate handling
- Minimax + alpha-beta AI (depth 1..5)
- `perft 4` returns `197281`

Reference guide: [IMPLEMENTATION_GUIDELINES.md](IMPLEMENTATION_GUIDELINES.md)

## Validation Commands

From repository root:

```bash
make image DIR=<language>
make build DIR=<language>
make analyze DIR=<language>
make test DIR=<language>
make test-chess-engine DIR=<language>
```

Optional broad checks:

```bash
make image
make build
make analyze
make test
make test-chess-engine
python3 test/verify_implementations.py
```

## Pull Request Expectations

- Keep scope small and explicit.
- Include motivation + behavior change summary.
- Include relevant command outputs (build/test/analyze).
- Update docs when commands, behavior, or constraints change.
- Do not mix unrelated refactors.

## Reporting Issues

For bugs, include:
- Language/implementation affected
- Reproduction steps
- Expected vs actual behavior
- Docker/context details and relevant logs

For feature requests, include:
- Problem statement
- Proposed behavior
- Expected impact

## Related Docs

- [Documentation Hub](README.md)
- [Implementation Guidelines](IMPLEMENTATION_GUIDELINES.md)
- [Issue triage workflow](ISSUE_TRIAGE_WORKFLOW.md)
