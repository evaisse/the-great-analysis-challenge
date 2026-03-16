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
| 📦 Bun | 🟡 | [10,101](implementations/bun/chess.js) | -, - MB | 337ms, 4 MB | 271ms, 4 MB | 10.9s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟡 | [11,632](implementations/crystal/src/chess_engine.cr) | 3.8s, 293 MB | 3.1s, 220 MB | 7.5s, 603 MB | 10.4s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [19,370](implementations/dart/bin/main.dart) | 202ms, 7 MB | 192ms, 7 MB | 180ms, 6 MB | 10.5s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [7,868](implementations/elm/src/ChessEngine.elm) | 189ms, 5 MB | 188ms, 6 MB | 187ms, 6 MB | 9.8s, 62 MB | 1/1 | 3/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [107,698](implementations/gleam/src/chess_engine.gleam) | 385ms, 18 MB | 358ms, 7 MB | 764ms, 76 MB | 1m 10s, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [22,900](implementations/go/chess.go) | 511ms, 83 MB | 1.1s, 111 MB | 1.1s, 120 MB | 10.5s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [11,812](implementations/haskell/src/Main.hs) | 330ms, 39 MB | 185ms, 7 MB | 230ms, 7 MB | 1m 10s, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [9,098](implementations/imba/chess.imba) | 346ms, 4 MB | 365ms, 4 MB | 326ms, 4 MB | 10.8s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [10,094](implementations/javascript/chess.js) | -, - MB | 291ms, 4 MB | 282ms, 4 MB | 10.7s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [9,783](implementations/julia/chess.jl) | -, - MB | 144ms, 6 MB | 151ms, 7 MB | 11.9s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [9,666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 156ms, 6 MB | 171ms, 7 MB | 158ms, 7 MB | 10s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [18,838](implementations/lua/chess.lua) | -, - MB | 159ms, 7 MB | 154ms, 7 MB | 10.7s, 63 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟡 | [10,616](implementations/nim/chess.nim) | 264ms, 4 MB | 240ms, 4 MB | 229ms, 4 MB | 10.2s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [24,435](implementations/php/chess.php) | -, - MB | 328ms, 9 MB | 201ms, 9 MB | 13.6s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [24,228](implementations/python/chess.py) | -, - MB | 192ms, 7 MB | 195ms, 7 MB | 16.7s, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [14,724](implementations/rescript/src/Chess.res) | 293ms, 3 MB | 263ms, 4 MB | 259ms, 4 MB | 10.7s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [9,600](implementations/ruby/chess.rb) | -, - MB | 2s, 230 MB | 230ms, 9 MB | 11.9s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [12,770](implementations/rust/src/main.rs) | 199ms, 7 MB | 192ms, 7 MB | 191ms, 7 MB | 9.7s, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟡 | [11,407](implementations/swift/src/main.swift) | 315ms, 4 MB | 299ms, 4 MB | 301ms, 4 MB | 10.3s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [17,636](implementations/typescript/src/chess.ts) | 263ms, 4 MB | 265ms, 4 MB | 269ms, 4 MB | 10.7s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟡 | [18,026](implementations/zig/src/main.zig) | 261ms, 4 MB | 269ms, 4 MB | 235ms, 4 MB | 10.3s, - MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
<!-- status-table-end -->

Legend:
- `Status`: `🟢 excellent` (no errors/warnings), `🟡 good` (warnings only), `🔴 needs_work` (at least one error).
- `TOKENS`: `tokens-v2` computed from Git-discovered files (tracked + untracked, excluding ignored) filtered by metadata `org.chess.source_exts`.
- `make ...` columns: `<duration>, <peak memory>`.
- `-`: metric missing or intentionally skipped.

## Speed Charts

<!-- speed-chart-start -->
Lower is better. Bars are normalized per step (`####################` = fastest).

#### `make build`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🧡 Kotlin | 156ms | `####################` |
| 2 | 🌳 Elm | 189ms | `#################` |
| 3 | 🦀 Rust | 199ms | `################` |
| 4 | 🎯 Dart | 202ms | `###############` |
| 5 | ⚡ Zig | 261ms | `############` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🔮 Julia | 144ms | `####################` |
| 2 | 🪐 Lua | 159ms | `##################` |
| 3 | 🧡 Kotlin | 171ms | `#################` |
| 4 | 📐 Haskell | 185ms | `################` |
| 5 | 🌳 Elm | 188ms | `###############` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🔮 Julia | 151ms | `####################` |
| 2 | 🪐 Lua | 154ms | `####################` |
| 3 | 🧡 Kotlin | 158ms | `###################` |
| 4 | 🎯 Dart | 180ms | `#################` |
| 5 | 🌳 Elm | 187ms | `################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦀 Rust | 9.7s | `####################` |
| 2 | 🌳 Elm | 9.8s | `####################` |
| 3 | 🧡 Kotlin | 10s | `####################` |
| 4 | 🦊 Nim | 10.2s | `###################` |
| 5 | ⚡ Zig | 10.3s | `###################` |
<!-- speed-chart-end -->

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
