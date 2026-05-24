# The Great Analysis Challenge: Multi-Language Chess Engine Project

Polyglot chess engine benchmark: same functional spec, multiple language implementations, Docker-first workflow, shared tests.

## Documentation

Start here: [Documentation Hub](docs/README.md)

Core references:
- [CHESS_ENGINE_SPECS.md](CHESS_ENGINE_SPECS.md) - authoritative engine and CLI requirements
- [AI_ALGORITHM_SPEC.md](AI_ALGORITHM_SPEC.md) - minimax + alpha-beta deterministic behavior
- [AGENTS.md](AGENTS.md) - agent operating rules for this repository
- [llms.txt](llms.txt) - compact file map for LLM tooling

## Available Implementations

All implementations target parity for core features: `perft`, `fen`, `ai`, `castling`, `en_passant`, `promotion`.

<!-- status-table-start -->
| Language | Complexity | LOC | make build | make analyze | make test | make test-chess-engine | Features |
|----------|------------|-----|------------|--------------|-----------|------------------------|----------|
| 📦 C | [7,151.5](implementations/c/src/chess.c) | 2,406 | 894ms, - MB | 174ms, - MB | 885ms, - MB | 18.1s, - MB | 🟢 9/9 |
| 💠 Crystal | [8,040.5](implementations/crystal/src/chess_engine.cr) | 3,308 | 1.3s, - MB | 182ms, - MB | 4.1s, - MB | 19.1s, - MB | 🟢 9/9 |
| 🎯 Dart | [15,055.25](implementations/dart/bin/main.dart) | 5,006 | 528ms, - MB | 262ms, - MB | 542ms, - MB | 20.3s, - MB | 🟡 9/9 |
| 💧 Elixir | [5,312.75](implementations/elixir/mix.exs) | 2,084 | 587ms, - MB | 1s, - MB | 612ms, - MB | 20.7s, - MB | 🟢 9/9 |
| 🌳 Elm | [5,109.75](implementations/elm/src/ChessEngine.elm) | 1,811 | 205ms, - MB | 191ms, - MB | 196ms, - MB | 18.5s, - MB | 🟢 9/9 |
| ✨ Gleam | [28,222.5](implementations/gleam/src/chess_engine.gleam) | 4,275 | 157ms, - MB | 306ms, - MB | 365ms, - MB | 20.4s, - MB | 🟢 9/9 |
| 🐹 Go | [15,016.25](implementations/go/chess.go) | 5,703 | 568ms, - MB | 973ms, - MB | 1.1s, - MB | 24.5s, - MB | 🟢 9/9 |
| 📐 Haskell | [8,143.25](implementations/haskell/src/Main.hs) | 2,312 | 253ms, - MB | 442ms, - MB | 134ms, - MB | 21s, - MB | 🟢 9/9 |
| 🪶 Imba | [6,167](implementations/imba/chess.imba) | 1,708 | 479ms, - MB | 458ms, - MB | 150ms, - MB | 19s, - MB | 🟡 9/9 |
| 🟨 Javascript | [4,396.5](implementations/javascript/chess.js) | 1,602 | <1ms, - MB | 153ms, - MB | 172ms, - MB | 39.9s, - MB | 🟢 9/9 |
| 🔮 Julia | [5,997.25](implementations/julia/chess.jl) | 2,083 | <1ms, - MB | 871ms, - MB | 3.2s, - MB | 22.1s, - MB | 🟡 9/9 |
| 🧡 Kotlin | [6,774](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 1,974 | 9.7s, - MB | 9.2s, - MB | 219ms, - MB | 20s, - MB | 🟡 9/9 |
| 🪐 Lua | [15,254.25](implementations/lua/chess.lua) | 4,192 | <1ms, - MB | 157ms, - MB | 168ms, - MB | 32.2s, - MB | 🟢 9/9 |
| 🦊 Nim | [7,067](implementations/nim/chess.nim) | 1,636 | 938ms, - MB | 880ms, - MB | 138ms, - MB | 18.6s, - MB | 🟢 9/9 |
| 🐘 Php | [18,067.25](implementations/php/chess.php) | 5,879 | <1ms, - MB | 408ms, - MB | 165ms, - MB | 24.1s, - MB | 🟢 9/9 |
| 🐍 Python | [12,581.25](implementations/python/chess.py) | 4,978 | <1ms, - MB | 235ms, - MB | 1.8s, - MB | 41.1s, - MB | 🟡 9/9 |
| 🧠 Rescript | [6,827.75](implementations/rescript/src/Chess.res) | 2,381 | 376ms, - MB | 607ms, - MB | 223ms, - MB | 21.8s, - MB | 🟡 9/9 |
| ❤️ Ruby | [5,466](implementations/ruby/chess.rb) | 2,469 | <1ms, - MB | 1.8s, - MB | 237ms, - MB | 18.3s, - MB | 🟡 9/9 |
| 🦀 Rust | [9,721.75](implementations/rust/src/main.rs) | 2,834 | 230ms, - MB | 597ms, - MB | 817ms, - MB | 18.3s, - MB | 🟢 9/9 |
| 🐦 Swift | [5,497.5](implementations/swift/src/main.swift) | 1,506 | 2s, - MB | 9s, - MB | 11.7s, - MB | 18.6s, - MB | 🟢 9/9 |
| 📘 Typescript | [7,773.5](implementations/typescript/src/chess.ts) | 2,586 | 2.1s, - MB | 4s, - MB | 2.2s, - MB | 25.1s, - MB | 🟡 9/9 |
| ⚡ Zig | [13,193](implementations/zig/src/main.zig) | 2,509 | 217ms, - MB | 167ms, - MB | 156ms, - MB | 33.8s, - MB | 🟢 9/9 |
<!-- status-table-end -->

Legend:
- `Features`: `🟢/🟡/🔴` status badge followed by implemented features count from metadata, e.g. `🟡 6/9`.
- `Complexity`: weighted `tokens-v3` semantic `complexity_score`, linked to the implementation entrypoint.
- `LOC`: source lines of code from Git-discovered source files filtered by metadata `org.chess.source_exts`.
- `make ...` columns: `<duration>, <peak memory>`.
- `-`: metric missing or intentionally skipped.

## Semantic Token Metrics (tokens-v3)

The README matrix uses the weighted `complexity_score` from `tokens-v3`. Raw `tokens-v2` counts and the full semantic breakdown remain available in the versioned report JSON files and through the shared Bun tooling. These metrics are powered by Shiki and classify tokens into semantic categories while down-weighting punctuation and excluding comments from scoring.

### Running semantic analysis

```bash
# Single implementation
bun run scripts/semantic-tokens/semantic_tokens.mjs implementations/rust --pretty

# All implementations
bun run scripts/semantic-tokens/semantic_tokens.mjs --all implementations/ --pretty

# Shared metrics pipeline (tokens-v2 + optional tokens-v3)
./workflow code-size-metrics --impl implementations/rust

# Refresh semantic metrics inside versioned reports
./workflow refresh-report-metrics
```

### Complexity score

| Category | Weight | Examples |
| --- | --- | --- |
| `keyword` | 1.0 | `if`, `fn`, `return`, `class` |
| `identifier` | 1.0 | variables, functions, methods |
| `type` | 1.0 | type annotations, generics |
| `operator` | 0.5 | `+`, `==`, `&&`, `->` |
| `literal` | 0.5 | numbers, strings |
| `punctuation` | 0.25 | `{}`, `()`, `;`, `,` |
| `comment` | 0.0 | excluded from scoring |
| `unknown` | 0.5 | fallback classification |

`complexity_score = Σ(weight × count)`.

## Quick Commands

```bash
make list-implementations
make image DIR=<language>
make build DIR=<language>
make analyze DIR=<language>
make test DIR=<language>
make test-unit-contract DIR=<language>
make test-chess-engine DIR=<language>
./workflow semantic-tokens implementations/<language> --pretty
./workflow refresh-report-metrics
```

All implementation build/test/analyze operations are Docker-only.
