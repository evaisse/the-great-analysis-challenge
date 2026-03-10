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
| 📦 Bun | 🟢 | [6523](implementations/bun/chess.js) | 299ms, 110 MB | 192ms, 7 MB | 192ms, 7 MB | 73115ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [9441](implementations/crystal/src/chess_engine.cr) | 241ms, 110 MB | 959ms, 196 MB | 2394ms, 526 MB | 8411ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [13314](implementations/dart/bin/main.dart) | 542ms, - MB | 1277ms, 211 MB | 3109ms, 451 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [7868](implementations/elm/src/ChessEngine.elm) | 1395ms, - MB | 379ms, 4 MB | 358ms, 9 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [107698](implementations/gleam/src/chess_engine.gleam) | 288ms, 110 MB | 333ms, 6 MB | 777ms, 61 MB | 52904ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [14374](implementations/go/chess.go) | 443ms, 65 MB | 1150ms, 111 MB | 1085ms, 115 MB | 8417ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [8520](implementations/haskell/src/Main.hs) | 423ms, 115 MB | 217ms, 7 MB | 229ms, 6 MB | 52855ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [6956](implementations/imba/chess.imba) | 322ms, 110 MB | 209ms, 7 MB | 195ms, 7 MB | 101421ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [6596](implementations/javascript/chess.js) | 200ms, 110 MB | 192ms, 6 MB | 191ms, 7 MB | 68310ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [9783](implementations/julia/chess.jl) | 235ms, 112 MB | 192ms, 7 MB | 181ms, 7 MB | 10843ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [9666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 213ms, 111 MB | 149ms, 7 MB | 171ms, 7 MB | 8463ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [10144](implementations/lua/chess.lua) | 432ms, - MB | 316ms, - MB | 264ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [1820](implementations/mojo/chess.mojo) | 581ms, 115 MB | 9695ms, - MB | 10301ms, - MB | 10071ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [8410](implementations/nim/chess.nim) | 215ms, 110 MB | 184ms, 7 MB | 191ms, 6 MB | 8321ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [15126](implementations/php/chess.php) | 326ms, 9 MB | 335ms, 9 MB | 212ms, 9 MB | 8350ms, 61 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [17166](implementations/python/chess.py) | 103ms, - MB | 209ms, - MB | 597ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [11181](implementations/rescript/src/Chess.res) | 291ms, 110 MB | 192ms, 7 MB | 206ms, 7 MB | 180096ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [9600](implementations/ruby/chess.rb) | 354ms, - MB | 1661ms, - MB | 1850ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [12770](implementations/rust/src/main.rs) | 13974ms, 110 MB | 197ms, 7 MB | 188ms, 7 MB | 8327ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [7650](implementations/swift/src/main.swift) | 369ms, 114 MB | 195ms, 7 MB | 181ms, 7 MB | 180096ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [13805](implementations/typescript/src/chess.ts) | 183ms, 7 MB | 216ms, 7 MB | 179ms, 7 MB | 8443ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [13302](implementations/zig/src/main.zig) | 280ms, 110 MB | 187ms, 7 MB | 188ms, 7 MB | 51994ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
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
| 1 | 🐍 Python | 103ms | `####################` |
| 2 | 📘 Typescript | 183ms | `###########` |
| 3 | 🟨 Javascript | 200ms | `##########` |
| 4 | 🧡 Kotlin | 213ms | `##########` |
| 5 | 🦊 Nim | 215ms | `##########` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🧡 Kotlin | 149ms | `####################` |
| 2 | 🦊 Nim | 184ms | `################` |
| 3 | ⚡ Zig | 187ms | `################` |
| 4 | 🔮 Julia | 192ms | `################` |
| 5 | 🧠 Rescript | 192ms | `################` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🧡 Kotlin | 171ms | `####################` |
| 2 | 📘 Typescript | 179ms | `###################` |
| 3 | 🔮 Julia | 181ms | `###################` |
| 4 | 🐦 Swift | 181ms | `###################` |
| 5 | 🦀 Rust | 188ms | `##################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦊 Nim | 8321ms | `####################` |
| 2 | 🦀 Rust | 8327ms | `####################` |
| 3 | 🐘 Php | 8350ms | `####################` |
| 4 | 💠 Crystal | 8411ms | `####################` |
| 5 | 🐹 Go | 8417ms | `####################` |
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
