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
| 📦 Bun | 🟢 | [669](implementations/bun/chess.js) | -, - MB | 219ms, 7 MB | 211ms, 7 MB | 65292ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [1692](implementations/crystal/src/chess_engine.cr) | 1320ms, 249 MB | 1006ms, 195 MB | 2461ms, 525 MB | 8423ms, 62 MB | 1/1 | 5/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [2052](implementations/dart/bin/main.dart) | 191ms, 6 MB | 181ms, 7 MB | 182ms, 7 MB | 13706ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [1663](implementations/elm/src/ChessEngine.elm) | 201ms, 7 MB | 195ms, 7 MB | 188ms, 6 MB | 8398ms, 64 MB | 1/1 | 3/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [1917](implementations/gleam/src/chess_engine.gleam) | 334ms, 18 MB | 369ms, 7 MB | 794ms, 75 MB | 52900ms, 61 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [2638](implementations/go/chess.go) | 506ms, 69 MB | 1251ms, 110 MB | 1150ms, 114 MB | 8630ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [1085](implementations/haskell/src/Main.hs) | 336ms, 38 MB | 203ms, 7 MB | 215ms, 7 MB | 52804ms, 61 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [700](implementations/imba/chess.imba) | 214ms, 7 MB | 199ms, 7 MB | 203ms, 6 MB | 93531ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [682](implementations/javascript/chess.js) | -, - MB | 218ms, 7 MB | 230ms, 7 MB | 65348ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [1369](implementations/julia/chess.jl) | -, - MB | 187ms, 7 MB | 185ms, 7 MB | 10647ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [1524](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 202ms, 7 MB | 187ms, 7 MB | 181ms, 6 MB | 8484ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [1547](implementations/lua/chess.lua) | -, - MB | 199ms, 7 MB | 204ms, 7 MB | 8424ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [275](implementations/mojo/chess.mojo) | 10053ms, - MB | 10091ms, - MB | 10032ms, - MB | 10662ms, 62 MB | 0/1 | 0/49 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [1105](implementations/nim/chess.nim) | 192ms, 7 MB | 198ms, 7 MB | 175ms, 5 MB | 8320ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [2384](implementations/php/chess.php) | -, - MB | 347ms, 9 MB | 209ms, 9 MB | 8551ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [2614](implementations/python/chess.py) | -, - MB | 195ms, 7 MB | 205ms, 7 MB | 8591ms, 61 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [1678](implementations/rescript/src/Chess.res) | 203ms, 7 MB | 190ms, 7 MB | 213ms, 7 MB | 180016ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [1906](implementations/ruby/chess.rb) | -, - MB | 2032ms, 232 MB | 235ms, 9 MB | 8370ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [1852](implementations/rust/src/main.rs) | 184ms, 7 MB | 187ms, 7 MB | 179ms, 7 MB | 8312ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [856](implementations/swift/src/main.swift) | 204ms, 6 MB | 201ms, 7 MB | 201ms, 7 MB | 180086ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [1773](implementations/typescript/src/chess.ts) | 182ms, 5 MB | 177ms, 7 MB | 189ms, 7 MB | 8443ms, 61 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [1589](implementations/zig/src/main.zig) | 195ms, 7 MB | 182ms, 7 MB | 185ms, 7 MB | 51998ms, 62 MB | 1/1 | 0/18 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
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
| 1 | 📘 Typescript | 182ms | `####################` |
| 2 | 🦀 Rust | 184ms | `####################` |
| 3 | 🎯 Dart | 191ms | `###################` |
| 4 | 🦊 Nim | 192ms | `###################` |
| 5 | ⚡ Zig | 195ms | `###################` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 📘 Typescript | 177ms | `####################` |
| 2 | 🎯 Dart | 181ms | `####################` |
| 3 | ⚡ Zig | 182ms | `###################` |
| 4 | 🦀 Rust | 187ms | `###################` |
| 5 | 🧡 Kotlin | 187ms | `###################` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦊 Nim | 175ms | `####################` |
| 2 | 🦀 Rust | 179ms | `####################` |
| 3 | 🧡 Kotlin | 181ms | `###################` |
| 4 | 🎯 Dart | 182ms | `###################` |
| 5 | ⚡ Zig | 185ms | `###################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦀 Rust | 8312ms | `####################` |
| 2 | 🦊 Nim | 8320ms | `####################` |
| 3 | ❤️ Ruby | 8370ms | `####################` |
| 4 | 🌳 Elm | 8398ms | `####################` |
| 5 | 💠 Crystal | 8423ms | `####################` |
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
