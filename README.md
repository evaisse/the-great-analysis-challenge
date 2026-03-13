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
| 📦 Bun | 🟢 | [6523](implementations/bun/chess.js) | -, - MB | 186ms, 7 MB | 189ms, 7 MB | 70044ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [9441](implementations/crystal/src/chess_engine.cr) | 1295ms, 250 MB | 954ms, 194 MB | 2390ms, 526 MB | 9828ms, 62 MB | 1/1 | 5/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [19370](implementations/dart/bin/main.dart) | 202ms, 7 MB | 192ms, 7 MB | 180ms, 6 MB | 10479ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [7868](implementations/elm/src/ChessEngine.elm) | 189ms, 5 MB | 188ms, 6 MB | 187ms, 6 MB | 9794ms, 62 MB | 1/1 | 3/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [107698](implementations/gleam/src/chess_engine.gleam) | 385ms, 18 MB | 358ms, 7 MB | 764ms, 76 MB | 70202ms, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [22900](implementations/go/chess.go) | 511ms, 83 MB | 1142ms, 111 MB | 1094ms, 120 MB | 10477ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [11812](implementations/haskell/src/Main.hs) | 330ms, 39 MB | 185ms, 7 MB | 230ms, 7 MB | 69837ms, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [7261](implementations/imba/chess.imba) | 183ms, 7 MB | 186ms, 7 MB | 183ms, 5 MB | 9860ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [6596](implementations/javascript/chess.js) | -, - MB | 199ms, 7 MB | 189ms, 7 MB | 70165ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [9783](implementations/julia/chess.jl) | -, - MB | 144ms, 6 MB | 151ms, 7 MB | 11940ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [9666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 156ms, 6 MB | 171ms, 7 MB | 158ms, 7 MB | 9957ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [18838](implementations/lua/chess.lua) | -, - MB | 159ms, 7 MB | 154ms, 7 MB | 10706ms, 63 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [1820](implementations/mojo/chess.mojo) | 12423ms, - MB | 12902ms, - MB | 12491ms, - MB | 13566ms, 62 MB | 0/1 | 0/57 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [8410](implementations/nim/chess.nim) | 201ms, 7 MB | 186ms, 6 MB | 182ms, 7 MB | 9725ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [24435](implementations/php/chess.php) | -, - MB | 328ms, 9 MB | 201ms, 9 MB | 13640ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [24228](implementations/python/chess.py) | -, - MB | 192ms, 7 MB | 195ms, 7 MB | 16696ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [11181](implementations/rescript/src/Chess.res) | 202ms, 7 MB | 190ms, 7 MB | 176ms, 7 MB | 9937ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [9600](implementations/ruby/chess.rb) | -, - MB | 1951ms, 230 MB | 230ms, 9 MB | 11931ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [12770](implementations/rust/src/main.rs) | 199ms, 7 MB | 192ms, 7 MB | 191ms, 7 MB | 9746ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [7650](implementations/swift/src/main.swift) | 197ms, 6 MB | 187ms, 7 MB | 195ms, 7 MB | 180080ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [13192](implementations/typescript/src/chess.ts) | 189ms, 5 MB | 187ms, 7 MB | 194ms, 6 MB | 9914ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [13302](implementations/zig/src/main.zig) | 197ms, 7 MB | 197ms, 7 MB | 198ms, 7 MB | 58009ms, 62 MB | 1/1 | 0/36 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
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
| 2 | 🪶 Imba | 183ms | `#################` |
| 3 | 🌳 Elm | 189ms | `#################` |
| 4 | 📘 Typescript | 189ms | `#################` |
| 5 | ⚡ Zig | 197ms | `################` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🔮 Julia | 144ms | `####################` |
| 2 | 🪐 Lua | 159ms | `##################` |
| 3 | 🧡 Kotlin | 171ms | `#################` |
| 4 | 📐 Haskell | 185ms | `################` |
| 5 | 🪶 Imba | 186ms | `###############` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🔮 Julia | 151ms | `####################` |
| 2 | 🪐 Lua | 154ms | `####################` |
| 3 | 🧡 Kotlin | 158ms | `###################` |
| 4 | 🧠 Rescript | 176ms | `#################` |
| 5 | 🎯 Dart | 180ms | `#################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦊 Nim | 9725ms | `####################` |
| 2 | 🦀 Rust | 9746ms | `####################` |
| 3 | 🌳 Elm | 9794ms | `####################` |
| 4 | 💠 Crystal | 9828ms | `####################` |
| 5 | 🪶 Imba | 9860ms | `####################` |
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
