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
| 💠 Crystal | [5,325.75](implementations/crystal/src/chess_engine.cr) | 2,201 | 1.3s, 249 MB | 979ms, 197 MB | 2.5s, 526 MB | 9.8s, 62 MB | 🟢 6/9 |
| 🎯 Dart | [10,100.25](implementations/dart/bin/main.dart) | 3,308 | 195ms, 5 MB | 185ms, 5 MB | 190ms, 5 MB | 10.5s, 62 MB | 🟡 6/9 |
| 🌳 Elm | [5,305](implementations/elm/src/ChessEngine.elm) | 1,669 | 192ms, 7 MB | 187ms, 7 MB | 184ms, 7 MB | 9.8s, 62 MB | 🟢 6/9 |
| ✨ Gleam | [27,937](implementations/gleam/src/chess_engine.gleam) | 14,964 | 265ms, 6 MB | 335ms, 7 MB | 770ms, 56 MB | 10s, 63 MB | 🟢 6/9 |
| 🐹 Go | [9,967.5](implementations/go/chess.go) | 3,919 | 546ms, 87 MB | 1.2s, 112 MB | 1.1s, 128 MB | 10.5s, 62 MB | 🟢 6/9 |
| 📐 Haskell | [5,560.5](implementations/haskell/src/Main.hs) | 1,407 | 332ms, 42 MB | 191ms, 7 MB | 234ms, 7 MB | 1m 10s, 62 MB | 🟢 6/9 |
| 🪶 Imba | [6,002](implementations/imba/chess.imba) | 1,634 | 199ms, 6 MB | 189ms, 7 MB | 194ms, 7 MB | 9.9s, 62 MB | 🟡 6/9 |
| 🟨 Javascript | [2,661](implementations/javascript/chess.js) | 820 | -, - MB | 207ms, 7 MB | 185ms, 7 MB | 1m 10s, 62 MB | 🔴 6/9 |
| 🔮 Julia | [5,517.5](implementations/julia/chess.jl) | 1,949 | -, - MB | 182ms, 7 MB | 179ms, 7 MB | 13.6s, 62 MB | 🟡 6/9 |
| 🧡 Kotlin | [4,868.5](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 1,525 | 154ms, 7 MB | 153ms, 7 MB | 151ms, 7 MB | 10s, 62 MB | 🟡 6/9 |
| 🪐 Lua | [10,381.5](implementations/lua/chess.lua) | 2,885 | -, - MB | 212ms, 7 MB | 195ms, 7 MB | 10.9s, 63 MB | 🟢 6/9 |
| 🦊 Nim | [5,748](implementations/nim/chess.nim) | 1,339 | 209ms, 7 MB | 193ms, 7 MB | 199ms, 7 MB | 9.8s, 62 MB | 🟢 6/9 |
| 🐘 Php | [9,808.25](implementations/php/chess.php) | 3,445 | -, - MB | 281ms, 9 MB | 168ms, 9 MB | 13.1s, 63 MB | 🟢 6/9 |
| 🐍 Python | [9,146.5](implementations/python/chess.py) | 3,678 | -, - MB | 220ms, 6 MB | 190ms, 7 MB | 16.7s, 62 MB | 🟡 6/9 |
| 🧠 Rescript | [4,903.75](implementations/rescript/src/Chess.res) | 1,688 | 199ms, 7 MB | 193ms, 7 MB | 196ms, 5 MB | 9.9s, 62 MB | 🟡 6/9 |
| ❤️ Ruby | [4,133.25](implementations/ruby/chess.rb) | 1,908 | -, - MB | 2.3s, 230 MB | 299ms, 9 MB | 12.1s, 62 MB | 🟡 6/9 |
| 🦀 Rust | [6,761](implementations/rust/src/main.rs) | 1,854 | 150ms, 7 MB | 148ms, 7 MB | 144ms, 7 MB | 9.7s, 62 MB | 🟢 6/9 |
| 🐦 Swift | [3,387](implementations/swift/src/main.swift) | 932 | 192ms, 7 MB | 184ms, 7 MB | 188ms, 7 MB | 3m 00s, - MB | 🟢 6/9 |
| 📘 Typescript | [6,211](implementations/typescript/src/chess.ts) | 2,038 | 193ms, 7 MB | 193ms, 7 MB | 188ms, 6 MB | 9.9s, 62 MB | 🟡 6/9 |
| ⚡ Zig | [8,232.75](implementations/zig/src/main.zig) | 1,633 | 215ms, 6 MB | 183ms, 7 MB | 184ms, 7 MB | 58s, 62 MB | 🟢 6/9 |
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
