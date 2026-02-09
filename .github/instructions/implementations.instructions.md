---
applyTo: "implementations/**"
---

# Chess Engine Implementation Instructions

- MUST follow `CHESS_ENGINE_SPECS.md` for board representation, CLI protocol, AI search, and perft targets
- MUST follow `AI_ALGORITHM_SPEC.md` for exact minimax + alpha-beta requirements
- Each implementation lives in `implementations/<language>/` and MUST include: `Dockerfile`, `Makefile`, `chess.meta`, `README.md`
- All builds and tests run inside Docker — never rely on host tools
- Convention over Configuration: never modify root Makefile or CI scripts
- No external chess libraries — implement all logic from scratch
- Write idiomatic code for the target language, showcase unique features
- Flush stdout after each output (critical for stdin/stdout protocol)
- perft(4) from the starting position MUST return exactly 197281
- AI depth 3 < 2 seconds, depth 5 < 10 seconds
- Standard Makefile targets: `all`, `build`, `test`, `analyze`, `clean`, `docker-build`, `docker-test`
- Reference existing implementations (Ruby, TypeScript, Rust, Python) for patterns
- `chess.meta` must accurately describe build, run, analyze, and test commands
- Board display: a1 is bottom-left, White pieces uppercase, Black pieces lowercase, coordinate labels on all sides
- Test commands: `make docker-build`, `make docker-test`, `echo -e "new\nperft 4\nquit" | docker run -i chess-<language>`
- Reference [CHESS_ENGINE_SPECS.md](../../CHESS_ENGINE_SPECS.md), [AI_ALGORITHM_SPEC.md](../../AI_ALGORITHM_SPEC.md), and [README_IMPLEMENTATION_GUIDELINES.md](../../README_IMPLEMENTATION_GUIDELINES.md)
