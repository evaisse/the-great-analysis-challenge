# GitHub Copilot Instructions

## Quick Reference

**Project Type**: Polyglot chess engine benchmark — identical engines in 20+ languages  
**Core Principle**: Convention over Configuration — zero infrastructure changes to add a language  
**Primary Workflow**: Docker-first development  
**Active Languages**: Rust, TypeScript, Python, PHP, Dart, Ruby, Lua (7 in `implementations/`)  
**WIP Languages**: Crystal, Elm, Gleam, Go, Haskell, Julia, Kotlin, Mojo, Nim, Swift, Zig (in `implementations-wip/`)

### Essential Commands

```bash
make build DIR=<lang>          # Build one implementation
make test DIR=<lang>           # Test one implementation
make analyze DIR=<lang>        # Run linters/type-checkers
make workflow DIR=<lang>       # Full pipeline: verify → build → analyze → test
make list-implementations      # List all discovered implementations
```

### Key Specification Files

- [CHESS_ENGINE_SPECS.md](../CHESS_ENGINE_SPECS.md) — **The authoritative spec** (board, CLI protocol, perft targets)
- [AI_ALGORITHM_SPEC.md](../AI_ALGORITHM_SPEC.md) — Minimax + alpha-beta requirements, evaluation function
- [README_IMPLEMENTATION_GUIDELINES.md](../README_IMPLEMENTATION_GUIDELINES.md) — Step-by-step implementation guide
- [CONTRIBUTING.md](../CONTRIBUTING.md) — Contribution process and coding standards
- [AGENTS.md](../AGENTS.md) — Detailed agent workflow and project structure
- [llms.txt](../llms.txt) — Project file map for LLMs

### PRD Feature Roadmap

- [PRD Overview & Dependencies](../docs/prd/README.md) — 9 PRDs to grow from ~9.5K to ~30-55K LOC
- Each PRD has a GitHub issue and targets all 7 active languages

---

## Convention Over Configuration

**CRITICAL**: The project infrastructure is 100% language-agnostic.

- Implementations self-describe via `chess.meta` JSON (build, run, test, analyze commands)
- Directory layout: `implementations/<language>/` with Dockerfile, Makefile, chess.meta, README.md
- Generic Makefile: `make build DIR=<lang>`, `make test DIR=<lang>` — no language-specific logic
- CI auto-discovers implementations by scanning for Dockerfiles
- **NEVER** modify root Makefile, CI workflows, or test infrastructure to add a language

---

## Implementation Requirements

### Required Files

Every implementation in `implementations/<language>/` MUST have:

| File | Purpose |
|------|---------|
| `Dockerfile` | Complete build + runtime environment |
| `Makefile` | Standard targets: all, build, test, analyze, clean, docker-build, docker-test |
| `chess.meta` | JSON metadata: language, version, build/run/test/analyze commands, features |
| `README.md` | Language-specific documentation |

### Chess Engine Correctness

- **perft(4) = 197281** — the ultimate correctness test, non-negotiable
- All special moves: castling (all FIDE conditions), en passant, promotion (default Queen)
- Checkmate and stalemate detection
- AI: minimax + alpha-beta pruning, depths 1-5
- FEN import/export (all 6 fields)
- stdout flush after every output (critical for stdin/stdout protocol)

### Performance Targets

- AI depth 3: < 2 seconds
- AI depth 5: < 10 seconds
- perft(4): < 1 second (nice to have)

### Code Quality

- Idiomatic code — showcase what makes each language unique
- No external chess libraries
- Use language-standard formatting tools
- Comments only for complex chess logic

---

## Docker-First Development

All builds and tests MUST run inside Docker:

```bash
cd implementations/<language>
make docker-build
echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<language>
echo -e "new\nperft 4\nquit" | docker run -i chess-<language>
echo -e "new\nai 3\nquit" | docker run -i chess-<language>
```

### Dockerfile Best Practices

- Use official language base images
- Multi-stage builds to reduce image size
- Working directory: `/app`
- Set executable permissions correctly
- Flush stdout (use unbuffered I/O or explicit flush)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| perft(4) ≠ 197281 | Check move gen for all piece types, verify castling/en passant/promotion, filter moves leaving king in check |
| AI makes illegal moves | Review move validation, check detection, king-in-check filtering |
| stdin/stdout not working | Flush stdout after each output, use unbuffered I/O |
| Docker build fails | Verify Dockerfile base image, COPY paths, dependency availability |
| Board display wrong | a1 = bottom-left, White uppercase, Black lowercase, coordinates on all sides |

---

## Reference Implementations

| Language | Strengths | Good For |
|----------|-----------|----------|
| Ruby | Clean OOP design | Understanding the structure |
| TypeScript | Modern typed JS | Type system patterns |
| Rust | High performance, ownership | Systems-level approach |
| Python | Readable, Pythonic | Quick prototyping reference |

All implementations: `implementations/` (production) and `implementations-wip/` (in progress).

---

## Copilot-Specific Guidelines

- **Always read specs first** — don't assume chess rules
- **Test incrementally** — build after each major component
- **Run perft(4) frequently** — catches move generation bugs early
- **Don't copy blindly** — adapt patterns to the target language's idioms
- **Minimal changes** — fix only what's broken, don't refactor working code
- **No language-specific infra** — everything works through conventions

### Path-Specific Instructions

Additional instructions are available in `.github/instructions/` for:
- `implementations/**` — Chess engine implementation rules
- `implementations-wip/**` — WIP implementation rules
- `test/**` — Test infrastructure rules
- `docs/prd/**` — PRD document rules
- `.github/workflows/**` — CI/CD workflow rules

### Prompt Files

Reusable prompts available in `.github/prompts/`:
- `/new-implementation` — Guide for implementing a new language
- `/debug-perft` — Debug perft failures
- `/implement-prd` — Implement a PRD feature
- `/fix-test` — Fix failing tests
- `/code-review` — Review implementation code
