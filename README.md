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
| 📦 Bun | [6,523](implementations/bun/chess.js) | -, - MB | 200ms, 6 MB | 189ms, 7 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 💠 Crystal | [9,441](implementations/crystal/src/chess_engine.cr) | 1.4s, 247 MB | 1s, 194 MB | 2.5s, 526 MB | 9.8s, 62 MB | 🟡 6/9 |
| 🎯 Dart | [21,057](implementations/dart/bin/main.dart) | 187ms, 6 MB | 188ms, 6 MB | 179ms, 7 MB | 10.4s, 62 MB | 🟡 6/9 |
| 🌳 Elm | [7,868](implementations/elm/src/ChessEngine.elm) | 200ms, 7 MB | 193ms, 7 MB | 188ms, 7 MB | 9.8s, 62 MB | 🟡 6/9 |
| ✨ Gleam | [107,699](implementations/gleam/src/chess_engine.gleam) | 486ms, 18 MB | 409ms, 7 MB | 888ms, 75 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 🐹 Go | [24,803](implementations/go/chess.go) | 572ms, 85 MB | 1.2s, 110 MB | 1.2s, 123 MB | 10.5s, 62 MB | 🟡 6/9 |
| 📐 Haskell | [11,812](implementations/haskell/src/Main.hs) | 365ms, 42 MB | 188ms, 7 MB | 242ms, 7 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 🪶 Imba | [13,544](implementations/imba/chess.imba) | 186ms, 7 MB | 189ms, 7 MB | 183ms, 7 MB | 9.9s, 62 MB | 🟡 6/9 |
| 🟨 Javascript | [6,596](implementations/javascript/chess.js) | -, - MB | 186ms, 7 MB | 174ms, 6 MB | 1m 10s, 62 MB | 🟡 6/9 |
| 🔮 Julia | [9,783](implementations/julia/chess.jl) | -, - MB | 196ms, 7 MB | 204ms, 7 MB | 12.2s, 62 MB | 🟡 6/9 |
| 🧡 Kotlin | [9,666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 213ms, 7 MB | 187ms, 6 MB | 199ms, 7 MB | 10s, 62 MB | 🟡 6/9 |
| 🪐 Lua | [20,806](implementations/lua/chess.lua) | -, - MB | 188ms, 7 MB | 190ms, 7 MB | 10.9s, 62 MB | 🟡 6/9 |
| 🦊 Nim | [8,410](implementations/nim/chess.nim) | 207ms, 7 MB | 192ms, 7 MB | 192ms, 7 MB | 9.7s, 62 MB | 🟡 6/9 |
| 🐘 Php | [26,871](implementations/php/chess.php) | -, - MB | 345ms, 9 MB | 225ms, 9 MB | 13.6s, 63 MB | 🟡 6/9 |
| 🐍 Python | [26,928](implementations/python/chess.py) | -, - MB | 199ms, 7 MB | 192ms, 7 MB | 16.7s, 62 MB | 🟡 6/9 |
| 🧠 Rescript | [11,181](implementations/rescript/src/Chess.res) | 190ms, 7 MB | 197ms, 5 MB | 206ms, 7 MB | 9.9s, 62 MB | 🟡 6/9 |
| ❤️ Ruby | [9,600](implementations/ruby/chess.rb) | -, - MB | 2.2s, 230 MB | 291ms, 9 MB | 12.1s, 62 MB | 🟡 6/9 |
| 🦀 Rust | [12,770](implementations/rust/src/main.rs) | 198ms, 7 MB | 204ms, 7 MB | 196ms, 7 MB | 9.7s, 62 MB | 🟡 6/9 |
| 🐦 Swift | [7,650](implementations/swift/src/main.swift) | 189ms, 7 MB | 184ms, 7 MB | 182ms, 6 MB | 3m 00s, - MB | 🟡 6/9 |
| 📘 Typescript | [13,192](implementations/typescript/src/chess.ts) | 201ms, 7 MB | 204ms, 7 MB | 200ms, 7 MB | 9.9s, 62 MB | 🟡 6/9 |
| ⚡ Zig | [13,277](implementations/zig/src/main.zig) | 183ms, 5 MB | 191ms, 7 MB | 182ms, 7 MB | 58s, 62 MB | 🟡 6/9 |
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
