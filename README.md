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
| 📦 Bun | 🟢 | [6523](implementations/bun/chess.js) | -, - MB | 183ms, 7 MB | 181ms, 7 MB | 90291ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [9441](implementations/crystal/src/chess_engine.cr) | 1277ms, 249 MB | 953ms, 196 MB | 2408ms, 524 MB | 9826ms, 62 MB | 1/1 | 5/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [18050](implementations/dart/bin/main.dart) | 196ms, 7 MB | 182ms, 7 MB | 190ms, 5 MB | 15119ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [7868](implementations/elm/src/ChessEngine.elm) | 192ms, 7 MB | 194ms, 7 MB | 191ms, 7 MB | 9782ms, 62 MB | 1/1 | 3/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [107698](implementations/gleam/src/chess_engine.gleam) | 361ms, 18 MB | 379ms, 7 MB | 786ms, 76 MB | 70215ms, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [21391](implementations/go/chess.go) | 511ms, 79 MB | 1187ms, 108 MB | 1107ms, 114 MB | 10034ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [11812](implementations/haskell/src/Main.hs) | 352ms, 42 MB | 184ms, 7 MB | 229ms, 7 MB | 69887ms, 62 MB | 1/1 | 0/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [6956](implementations/imba/chess.imba) | 232ms, 7 MB | 202ms, 7 MB | 209ms, 7 MB | 126231ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [6596](implementations/javascript/chess.js) | -, - MB | 204ms, 7 MB | 206ms, 5 MB | 93217ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [9783](implementations/julia/chess.jl) | -, - MB | 202ms, 7 MB | 176ms, 7 MB | 12076ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [9666](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 170ms, 7 MB | 157ms, 7 MB | 157ms, 7 MB | 9955ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [16287](implementations/lua/chess.lua) | -, - MB | 191ms, 7 MB | 180ms, 6 MB | 10036ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [1820](implementations/mojo/chess.mojo) | 11287ms, - MB | 11370ms, - MB | 11371ms, - MB | 12225ms, 62 MB | 0/1 | 0/58 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [8410](implementations/nim/chess.nim) | 195ms, 7 MB | 172ms, 7 MB | 185ms, 7 MB | 9733ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [23021](implementations/php/chess.php) | -, - MB | 344ms, 9 MB | 204ms, 9 MB | 9952ms, 63 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [22884](implementations/python/chess.py) | -, - MB | 210ms, 7 MB | 180ms, 6 MB | 10008ms, 62 MB | 1/1 | 16/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [11181](implementations/rescript/src/Chess.res) | 194ms, 7 MB | 193ms, 7 MB | 185ms, 7 MB | 180008ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [9600](implementations/ruby/chess.rb) | -, - MB | 2261ms, 231 MB | 296ms, 9 MB | 12136ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [12770](implementations/rust/src/main.rs) | 195ms, 7 MB | 186ms, 7 MB | 197ms, 7 MB | 9738ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [7650](implementations/swift/src/main.swift) | 188ms, 7 MB | 186ms, 7 MB | 184ms, 7 MB | 180086ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [13192](implementations/typescript/src/chess.ts) | 150ms, 7 MB | 136ms, 7 MB | 148ms, 7 MB | 9876ms, 62 MB | 1/1 | 2/16 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [13302](implementations/zig/src/main.zig) | 190ms, 7 MB | 194ms, 7 MB | 190ms, 5 MB | 58002ms, 62 MB | 1/1 | 0/36 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
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
| 1 | 📘 Typescript | 150ms | `####################` |
| 2 | 🧡 Kotlin | 170ms | `##################` |
| 3 | 🐦 Swift | 188ms | `################` |
| 4 | ⚡ Zig | 190ms | `################` |
| 5 | 🌳 Elm | 192ms | `################` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 📘 Typescript | 136ms | `####################` |
| 2 | 🧡 Kotlin | 157ms | `#################` |
| 3 | 🦊 Nim | 172ms | `################` |
| 4 | 🎯 Dart | 182ms | `###############` |
| 5 | 📦 Bun | 183ms | `###############` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 📘 Typescript | 148ms | `####################` |
| 2 | 🧡 Kotlin | 157ms | `###################` |
| 3 | 🔮 Julia | 176ms | `#################` |
| 4 | 🪐 Lua | 180ms | `################` |
| 5 | 🐍 Python | 180ms | `################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦊 Nim | 9733ms | `####################` |
| 2 | 🦀 Rust | 9738ms | `####################` |
| 3 | 🌳 Elm | 9782ms | `####################` |
| 4 | 💠 Crystal | 9826ms | `####################` |
| 5 | 📘 Typescript | 9876ms | `####################` |
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
