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

| Language | Status | TOKENS | make build | make analyze | make test | make test-chess-engine | make test score | make test-chess-engine score | Features |
|----------|--------|--------|------------|--------------|-----------|------------------------|-----------------|------------------------------|----------|
| 💠 Crystal | 🟡 | [9,441](implementations/crystal/src/chess_engine.cr) | 1.3s, 248 MB | 963ms, 196 MB | 2.4s, 526 MB | 9.8s, 63 MB | 1/1 | 5/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [21,057](implementations/dart/bin/main.dart) | 191ms, 7 MB | 177ms, 7 MB | 183ms, 7 MB | 10.5s, 63 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟡 | [7,868](implementations/elm/src/ChessEngine.elm) | 179ms, 7 MB | 165ms, 7 MB | 161ms, 7 MB | 9.8s, 62 MB | 1/1 | 3/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟡 | [107,699](implementations/gleam/src/chess_engine.gleam) | 400ms, 17 MB | 360ms, 8 MB | 795ms, 76 MB | 1m 10s, 63 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟡 | [24,803](implementations/go/chess.go) | 541ms, 85 MB | 1.2s, 110 MB | 1.1s, 119 MB | 10.5s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟡 | [11,812](implementations/haskell/src/Main.hs) | 342ms, 42 MB | 201ms, 5 MB | 249ms, 7 MB | 1m 10s, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [13,544](implementations/imba/chess.imba) | 203ms, 7 MB | 201ms, 6 MB | 202ms, 7 MB | 9.9s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [6,596](implementations/javascript/chess.js) | -, - MB | 200ms, 7 MB | 191ms, 7 MB | 1m 10s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟡 | [9,783](implementations/julia/chess.jl) | -, - MB | 190ms, 6 MB | 180ms, 7 MB | 12.1s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [9,666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 167ms, 6 MB | 154ms, 7 MB | 147ms, 7 MB | 10s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟡 | [20,806](implementations/lua/chess.lua) | -, - MB | 209ms, 7 MB | 185ms, 6 MB | 10.9s, 63 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟡 | [8,410](implementations/nim/chess.nim) | 196ms, 7 MB | 182ms, 7 MB | 179ms, 7 MB | 9.7s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟡 | [26,871](implementations/php/chess.php) | -, - MB | 357ms, 9 MB | 215ms, 9 MB | 13.7s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [26,928](implementations/python/chess.py) | -, - MB | 184ms, 7 MB | 179ms, 7 MB | 16.6s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [11,181](implementations/rescript/src/Chess.res) | 189ms, 5 MB | 193ms, 6 MB | 184ms, 5 MB | 9.9s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [9,600](implementations/ruby/chess.rb) | -, - MB | 2.1s, 232 MB | 254ms, 9 MB | 12s, 63 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟡 | [12,770](implementations/rust/src/main.rs) | 207ms, 6 MB | 185ms, 6 MB | 185ms, 7 MB | 9.7s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟡 | [7,650](implementations/swift/src/main.swift) | 189ms, 7 MB | 191ms, 7 MB | 185ms, 7 MB | 3m 00s, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [13,192](implementations/typescript/src/chess.ts) | 171ms, 7 MB | 156ms, 7 MB | 192ms, 7 MB | 9.9s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟡 | [13,277](implementations/zig/src/main.zig) | 208ms, 6 MB | 192ms, 5 MB | 180ms, 7 MB | 58s, 62 MB | 1/1 | 0/36 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
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
