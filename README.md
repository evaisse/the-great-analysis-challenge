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

| Language | TOKENS | make build | make analyze | make test | make test-chess-engine | Features |
|----------|--------|------------|--------------|-----------|------------------------|----------|
| 📦 Bun | [6,523](implementations/bun/chess.js) | -, - MB | 193ms, 7 MB | 191ms, 7 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 💠 Crystal | [9,441](implementations/crystal/src/chess_engine.cr) | 1.2s, 249 MB | 916ms, 195 MB | 2.1s, 526 MB | 9.8s, 62 MB | 🟡 6/9 |
| 🎯 Dart | [21,057](implementations/dart/bin/main.dart) | 213ms, 6 MB | 188ms, 7 MB | 177ms, 7 MB | 10.5s, 62 MB | 🟡 6/9 |
| 🌳 Elm | [7,868](implementations/elm/src/ChessEngine.elm) | 194ms, 7 MB | 188ms, 7 MB | 180ms, 7 MB | 9.8s, 62 MB | 🟡 6/9 |
| ✨ Gleam | [107,699](implementations/gleam/src/chess_engine.gleam) | 422ms, 18 MB | 349ms, 7 MB | 791ms, 76 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 🐹 Go | [24,803](implementations/go/chess.go) | 563ms, 86 MB | 1.2s, 114 MB | 1.1s, 130 MB | 10.5s, 62 MB | 🟡 6/9 |
| 📐 Haskell | [11,812](implementations/haskell/src/Main.hs) | 379ms, 42 MB | 201ms, 6 MB | 260ms, 7 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 🪶 Imba | [13,544](implementations/imba/chess.imba) | 158ms, 5 MB | 166ms, 7 MB | 155ms, 7 MB | 9.9s, 63 MB | 🟡 6/9 |
| 🟨 Javascript | [6,596](implementations/javascript/chess.js) | -, - MB | 197ms, 7 MB | 191ms, 7 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 🔮 Julia | [9,783](implementations/julia/chess.jl) | -, - MB | 184ms, 7 MB | 187ms, 7 MB | 12.1s, 62 MB | 🟡 6/9 |
| 🧡 Kotlin | [9,666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 202ms, 6 MB | 186ms, 7 MB | 185ms, 6 MB | 10s, 62 MB | 🟡 6/9 |
| 🪐 Lua | [20,806](implementations/lua/chess.lua) | -, - MB | 189ms, 7 MB | 181ms, 7 MB | 10.9s, 63 MB | 🟡 6/9 |
| 🦊 Nim | [8,410](implementations/nim/chess.nim) | 198ms, 6 MB | 182ms, 7 MB | 198ms, 6 MB | 9.7s, 62 MB | 🟡 6/9 |
| 🐘 Php | [26,871](implementations/php/chess.php) | -, - MB | 345ms, 9 MB | 209ms, 9 MB | 13.6s, 63 MB | 🟡 6/9 |
| 🐍 Python | [26,928](implementations/python/chess.py) | -, - MB | 214ms, 7 MB | 184ms, 7 MB | 16.6s, 62 MB | 🟡 6/9 |
| 🧠 Rescript | [11,181](implementations/rescript/src/Chess.res) | 202ms, 7 MB | 182ms, 5 MB | 192ms, 7 MB | 9.9s, 62 MB | 🟡 6/9 |
| ❤️ Ruby | [9,600](implementations/ruby/chess.rb) | -, - MB | 2.4s, 230 MB | 295ms, 9 MB | 12.2s, 62 MB | 🟡 6/9 |
| 🦀 Rust | [12,770](implementations/rust/src/main.rs) | 187ms, 7 MB | 182ms, 6 MB | 180ms, 7 MB | 9.7s, 62 MB | 🟡 6/9 |
| 🐦 Swift | [7,650](implementations/swift/src/main.swift) | 190ms, 7 MB | 180ms, 6 MB | 189ms, 7 MB | 3m 00s, - MB | 🟡 6/9 |
| 📘 Typescript | [13,192](implementations/typescript/src/chess.ts) | 188ms, 7 MB | 180ms, 7 MB | 181ms, 7 MB | 9.9s, 62 MB | 🟡 6/9 |
| ⚡ Zig | [13,277](implementations/zig/src/main.zig) | 189ms, 7 MB | 182ms, 7 MB | 175ms, 7 MB | 58s, 62 MB | 🟡 6/9 |
<!-- status-table-end -->

Legend:
- `Features`: `🟢/🟡/🔴` status badge followed by implemented features count from metadata, e.g. `🟡 6/9`.
- `TOKENS`: `tokens-v2` computed from Git-discovered files (tracked + untracked, excluding ignored) filtered by metadata `org.chess.source_exts`.
- `make ...` columns: `<duration>, <peak memory>`.
- `-`: metric missing or intentionally skipped.

## Quick Commands

```bash
make list-implementations
make image DIR=<language>
make build DIR=<language>
make analyze DIR=<language>
make test DIR=<language>
make test-unit-contract DIR=<language>
make test-chess-engine DIR=<language>
```

All implementation build/test/analyze operations are Docker-only.
