# The Great Analysis Challenge: Multi-Language Chess Engine Project

A comprehensive project implementing identical chess engines across **different programming languages** to compare their approaches, performance, and unique paradigms.

## 📚 Available Implementations

All implementations have complete feature parity with the following features:

- ✅ **perft** - Performance testing with recursive move generation
- ✅ **fen** - Forsyth-Edwards Notation support
- ✅ **ai** - Artificial intelligence with minimax algorithms
- ✅ **castling** - Special king-rook moves
- ✅ **en_passant** - Special pawn capture rules
- ✅ **promotion** - Pawn advancement to other pieces

<!-- status-table-start -->

| Language | Status | LOC | make build | make analyze | make test | make test-chess-engine | make test score | make test-chess-engine score | Features |
|----------|--------|-----|------------|--------------|-----------|------------------------|-----------------|------------------------------|----------|
| 📦 Bun | 🟢 | [669](implementations/bun/chess.js) | -, - MB | 170ms, 7 MB | 157ms, 7 MB | 65274ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [1692](implementations/crystal/src/chess_engine.cr) | 1272ms, 248 MB | 972ms, 195 MB | 2450ms, 525 MB | 8412ms, 61 MB | 1/1 | 5/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [1739](implementations/dart/bin/main.dart) | -, - MB | 186ms, 7 MB | 184ms, 7 MB | 11228ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [1663](implementations/elm/src/ChessEngine.elm) | 187ms, 7 MB | 186ms, 7 MB | 184ms, 7 MB | 8376ms, 62 MB | 1/1 | 3/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [1917](implementations/gleam/src/chess_engine.gleam) | 423ms, 18 MB | 382ms, 7 MB | 819ms, 75 MB | 52913ms, 62 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [2237](implementations/go/chess.go) | 441ms, 63 MB | 1116ms, 111 MB | 1016ms, 111 MB | 8414ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [1085](implementations/haskell/src/Main.hs) | 385ms, 38 MB | 205ms, 7 MB | 213ms, 7 MB | 52810ms, 62 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [700](implementations/imba/chess.imba) | 229ms, 7 MB | 208ms, 7 MB | 194ms, 6 MB | 98559ms, 61 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [682](implementations/javascript/chess.js) | -, - MB | 222ms, 7 MB | 224ms, 6 MB | 73157ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [1369](implementations/julia/chess.jl) | -, - MB | 183ms, 6 MB | 184ms, 7 MB | 10733ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [1524](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 192ms, 6 MB | 198ms, 7 MB | 193ms, 7 MB | 8480ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [1331](implementations/lua/chess.lua) | -, - MB | 160ms, 5 MB | 138ms, 5 MB | 8413ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [275](implementations/mojo/chess.mojo) | 10478ms, - MB | 10204ms, - MB | 11012ms, - MB | 10828ms, 61 MB | 0/1 | 0/49 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [1105](implementations/nim/chess.nim) | 202ms, 5 MB | 187ms, 5 MB | 187ms, 6 MB | 8334ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [2016](implementations/php/chess.php) | -, - MB | 343ms, 9 MB | 208ms, 9 MB | 8339ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [2373](implementations/python/chess.py) | -, - MB | 177ms, 6 MB | 189ms, 5 MB | 8388ms, 61 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [1678](implementations/rescript/src/Chess.res) | 184ms, 7 MB | 184ms, 7 MB | 182ms, 6 MB | 600025ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [1906](implementations/ruby/chess.rb) | -, - MB | 2336ms, 230 MB | 293ms, 9 MB | 8449ms, 61 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [1852](implementations/rust/src/main.rs) | 194ms, 7 MB | 199ms, 7 MB | 178ms, 7 MB | 8316ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [856](implementations/swift/src/main.swift) | 201ms, 7 MB | 190ms, 7 MB | 210ms, 7 MB | 304210ms, 63 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [1773](implementations/typescript/src/chess.ts) | 176ms, 7 MB | 175ms, 4 MB | 193ms, 5 MB | 8440ms, 61 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [1589](implementations/zig/src/main.zig) | 201ms, 7 MB | 203ms, 6 MB | 199ms, 5 MB | 51999ms, 62 MB | 1/1 | 0/18 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
<!-- status-table-end -->

Legend:
- `Status`: `🟢 excellent` = 0 error / 0 warning, `🟡 good` = 0 error with warnings, `🔴 needs_work` = at least 1 error.
- `make ...` columns: benchmarked command shown as `<duration>, <peak memory>`.
- `make test score`: score of `make test` (binary `1/1` success, `0/1` failure).
- `make test-chess-engine score`: shared harness score (`passed/total`) for the benchmark track.
- `-`: metric not yet available for this implementation/run, or intentionally skipped (for example `make build` on interpreted runtimes).

## ⚡ Speed Charts

<!-- speed-chart-start -->
Lower is better. Bars are normalized per step (`####################` = fastest).

#### `make build`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 📘 Typescript | 176ms | `####################` |
| 2 | 🧠 Rescript | 184ms | `###################` |
| 3 | 🌳 Elm | 187ms | `###################` |
| 4 | 🧡 Kotlin | 192ms | `##################` |
| 5 | 🦀 Rust | 194ms | `##################` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🪐 Lua | 160ms | `####################` |
| 2 | 📦 Bun | 170ms | `###################` |
| 3 | 📘 Typescript | 175ms | `##################` |
| 4 | 🐍 Python | 177ms | `##################` |
| 5 | 🔮 Julia | 183ms | `#################` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🪐 Lua | 138ms | `####################` |
| 2 | 📦 Bun | 157ms | `##################` |
| 3 | 🦀 Rust | 178ms | `################` |
| 4 | 🧠 Rescript | 182ms | `###############` |
| 5 | 🔮 Julia | 184ms | `###############` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦀 Rust | 8316ms | `####################` |
| 2 | 🦊 Nim | 8334ms | `####################` |
| 3 | 🐘 Php | 8339ms | `####################` |
| 4 | 🌳 Elm | 8376ms | `####################` |
| 5 | 🐍 Python | 8388ms | `####################` |
<!-- speed-chart-end -->

## 🚀 Quick Start

```bash
# List all available implementations
make list-implementations

# Build Docker image for a specific implementation
make image DIR=go

# Run compilation only for a specific implementation
make build DIR=go

# Run internal implementation tests only
make test DIR=ruby

# Run shared chess engine suite only
make test-chess-engine DIR=ruby

# Analyze a specific implementation
make analyze DIR=python

# Build and test all implementations
make image
make build
make analyze
make test
make test-chess-engine

# Test from within an implementation directory
cd implementations/<language> && make docker-test

# Run performance benchmarks
./workflow run-benchmark <language>

# Verify all implementations
python3 test/verify_implementations.py
```

**New Convention-Based Approach**: All root Makefile commands now use the `DIR` parameter (e.g., `make build DIR=go`) instead of language-specific targets. This makes the infrastructure 100% implementation-agnostic!

## CI/CD

- **🔄 Continuous Testing**: All implementations tested via Docker on every commit
- **📊 Weekly Benchmarks**: Performance reports generated every Sunday
- **🏷️ Automatic Releases**: Semantic versioning based on implementation health
- **📈 Performance Tracking**: Historical analysis and build time monitoring
- **🎯 Issue Triage**: Automated label application and clarification requests

**Manual Operations**: [GitHub Actions](../../actions/workflows/bench.yaml) | [Latest Results](../../releases/latest) | [Issue Triage Docs](./docs/ISSUE_TRIAGE_WORKFLOW.md)

All implementations MUST be built, tested, and analyzed exclusively via Docker containers to ensure:

- **Zero Host Dependencies**: No local toolchains required (python, rust, etc.)
- **Consistent Environment**: Identical tool versions for all contributors
- **Reproducible Results**: Identical testing and analysis conditions
- **Simplified CI/CD**: Only Docker required, not X language toolchains

## 📋 Architecture

Each implementation follows identical specifications:

- **Chess Rules & Interface**: [CHESS_ENGINE_SPECS.md](./CHESS_ENGINE_SPECS.md) - Core engine requirements
- **AI Algorithm**: [AI_ALGORITHM_SPEC.md](./AI_ALGORITHM_SPEC.md) - Deterministic move selection algorithm
- **Standardized Commands**: Identical interface across all languages
- **Docker Support**: Containerized testing and deployment
- **Makefile Targets**: `image`, `build`, `analyze`, `test`, `test-chess-engine`, `docker-test`
- **Metadata**: Structured information in `chess.meta` files
