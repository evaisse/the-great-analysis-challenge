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

| Language | Status | LOC | make build | make analyze | make test | make test-chess-engine | make test score | make test-chess-engine score | Features |
|----------|--------|-----|------------|--------------|-----------|------------------------|-----------------|------------------------------|----------|
| 📦 Bun | 🟢 | [669](implementations/bun/chess.js) | -, - MB | 223ms, 7 MB | 209ms, 7 MB | 98046ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [1692](implementations/crystal/src/chess_engine.cr) | 1303ms, 250 MB | 967ms, 195 MB | 2388ms, 524 MB | 9826ms, 62 MB | 1/1 | 5/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [2742](implementations/dart/bin/main.dart) | -, - MB | 188ms, 7 MB | 192ms, 7 MB | 15068ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [1663](implementations/elm/src/ChessEngine.elm) | 148ms, 6 MB | 144ms, 7 MB | 162ms, 7 MB | 9745ms, 62 MB | 1/1 | 3/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [1917](implementations/gleam/src/chess_engine.gleam) | 443ms, 18 MB | 360ms, 7 MB | 824ms, 77 MB | 70240ms, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [3352](implementations/go/chess.go) | 530ms, 80 MB | 1188ms, 111 MB | 1083ms, 110 MB | 10031ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [1085](implementations/haskell/src/Main.hs) | 358ms, 38 MB | 207ms, 6 MB | 230ms, 6 MB | 70408ms, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [700](implementations/imba/chess.imba) | 168ms, 7 MB | 166ms, 7 MB | 169ms, 7 MB | 110879ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [682](implementations/javascript/chess.js) | -, - MB | 209ms, 7 MB | 190ms, 7 MB | 85603ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [1369](implementations/julia/chess.jl) | -, - MB | 190ms, 6 MB | 192ms, 7 MB | 12323ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [1524](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 191ms, 7 MB | 185ms, 7 MB | 185ms, 7 MB | 10000ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [2230](implementations/lua/chess.lua) | -, - MB | 146ms, 7 MB | 149ms, 7 MB | 10020ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [275](implementations/mojo/chess.mojo) | 10073ms, - MB | 10052ms, - MB | 10042ms, - MB | 10753ms, 62 MB | 0/1 | 0/58 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [1105](implementations/nim/chess.nim) | 185ms, 7 MB | 200ms, 7 MB | 192ms, 6 MB | 9733ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [2936](implementations/php/chess.php) | -, - MB | 329ms, 9 MB | 214ms, 9 MB | 9949ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [3077](implementations/python/chess.py) | -, - MB | 204ms, 7 MB | 185ms, 7 MB | 10001ms, 61 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [1678](implementations/rescript/src/Chess.res) | 204ms, 7 MB | 191ms, 7 MB | 181ms, 5 MB | 180083ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [1906](implementations/ruby/chess.rb) | -, - MB | 2238ms, 229 MB | 279ms, 9 MB | 12036ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [1852](implementations/rust/src/main.rs) | 187ms, 7 MB | 182ms, 7 MB | 181ms, 7 MB | 9714ms, 61 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [856](implementations/swift/src/main.swift) | 192ms, 6 MB | 185ms, 7 MB | 187ms, 6 MB | 180082ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [1773](implementations/typescript/src/chess.ts) | 195ms, 7 MB | 188ms, 7 MB | 196ms, 7 MB | 9922ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [1589](implementations/zig/src/main.zig) | 184ms, 7 MB | 205ms, 5 MB | 184ms, 7 MB | 58003ms, 62 MB | 1/1 | 0/36 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
<!-- status-table-end -->

Legend:
- `Status`: `🟢 excellent` (no errors/warnings), `🟡 good` (warnings only), `🔴 needs_work` (at least one error).
- `make ...` columns: `<duration>, <peak memory>`.
- `-`: metric missing or intentionally skipped.

## Speed Charts

<!-- speed-chart-start -->
Lower is better. Bars are normalized per step (`####################` = fastest).

#### `make build`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🌳 Elm | 148ms | `####################` |
| 2 | 🪶 Imba | 168ms | `##################` |
| 3 | ⚡ Zig | 184ms | `################` |
| 4 | 🦊 Nim | 185ms | `################` |
| 5 | 🦀 Rust | 187ms | `################` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🌳 Elm | 144ms | `####################` |
| 2 | 🪐 Lua | 146ms | `####################` |
| 3 | 🪶 Imba | 166ms | `#################` |
| 4 | 🦀 Rust | 182ms | `################` |
| 5 | 🧡 Kotlin | 185ms | `################` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🪐 Lua | 149ms | `####################` |
| 2 | 🌳 Elm | 162ms | `##################` |
| 3 | 🪶 Imba | 169ms | `##################` |
| 4 | 🦀 Rust | 181ms | `################` |
| 5 | 🧠 Rescript | 181ms | `################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦀 Rust | 9714ms | `####################` |
| 2 | 🦊 Nim | 9733ms | `####################` |
| 3 | 🌳 Elm | 9745ms | `####################` |
| 4 | 💠 Crystal | 9826ms | `####################` |
| 5 | 📘 Typescript | 9922ms | `####################` |
<!-- speed-chart-end -->

## Quick Commands

```bash
make list-implementations
make image DIR=<language>
make build DIR=<language>
make analyze DIR=<language>
make test DIR=<language>
make test-chess-engine DIR=<language>
```

All implementation build/test/analyze operations are Docker-only.
