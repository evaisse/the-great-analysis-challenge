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
| 📦 Bun | 🟢 | [669](implementations/bun/chess.js) | -, - MB | 157ms, 7 MB | 152ms, 6 MB | 62459ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [1692](implementations/crystal/src/chess_engine.cr) | 1263ms, 248 MB | 937ms, 196 MB | 2376ms, 524 MB | 8408ms, 61 MB | 1/1 | 5/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [1739](implementations/dart/bin/main.dart) | -, - MB | 211ms, 7 MB | 194ms, 7 MB | 8428ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [1663](implementations/elm/src/ChessEngine.elm) | 187ms, 5 MB | 195ms, 6 MB | 186ms, 7 MB | 8376ms, 62 MB | 1/1 | 3/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [1917](implementations/gleam/src/chess_engine.gleam) | 394ms, 18 MB | 388ms, 7 MB | 885ms, 74 MB | 52958ms, 62 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [2237](implementations/go/chess.go) | 442ms, 65 MB | 1114ms, 108 MB | 1021ms, 108 MB | 8412ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [1085](implementations/haskell/src/Main.hs) | 347ms, 38 MB | 225ms, 7 MB | 230ms, 6 MB | 52814ms, 62 MB | 1/1 | 0/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [700](implementations/imba/chess.imba) | 147ms, 7 MB | 142ms, 7 MB | 139ms, 5 MB | 98513ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [682](implementations/javascript/chess.js) | -, - MB | 221ms, 7 MB | 216ms, 5 MB | 73170ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [1369](implementations/julia/chess.jl) | -, - MB | 190ms, 7 MB | 180ms, 7 MB | 10695ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [1524](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 152ms, 7 MB | 160ms, 6 MB | 162ms, 7 MB | 8466ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [1331](implementations/lua/chess.lua) | -, - MB | 203ms, 7 MB | 195ms, 7 MB | 8424ms, 64 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [275](implementations/mojo/chess.mojo) | 9673ms, - MB | 9885ms, - MB | 10146ms, - MB | 10399ms, 62 MB | 0/1 | 0/49 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [1105](implementations/nim/chess.nim) | 204ms, 7 MB | 210ms, 7 MB | 195ms, 7 MB | 8340ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [2016](implementations/php/chess.php) | -, - MB | 332ms, 9 MB | 204ms, 9 MB | 8348ms, 62 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [2373](implementations/python/chess.py) | -, - MB | 199ms, 6 MB | 185ms, 5 MB | 8397ms, 61 MB | 1/1 | 14/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [1678](implementations/rescript/src/Chess.res) | 195ms, 7 MB | 189ms, 7 MB | 184ms, 6 MB | 180090ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [1906](implementations/ruby/chess.rb) | -, - MB | 2155ms, 230 MB | 315ms, 9 MB | 8413ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [1852](implementations/rust/src/main.rs) | 178ms, 7 MB | 189ms, 6 MB | 183ms, 7 MB | 8336ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [856](implementations/swift/src/main.swift) | 169ms, 7 MB | 162ms, 7 MB | 159ms, 7 MB | 180102ms, - MB | 1/1 | 0/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [1773](implementations/typescript/src/chess.ts) | 200ms, 7 MB | 198ms, 5 MB | 183ms, 6 MB | 8444ms, 62 MB | 1/1 | 2/14 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [1589](implementations/zig/src/main.zig) | 191ms, 7 MB | 179ms, 7 MB | 179ms, 6 MB | 51998ms, 62 MB | 1/1 | 0/18 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
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
| 1 | 🪶 Imba | 147ms | `####################` |
| 2 | 🧡 Kotlin | 152ms | `###################` |
| 3 | 🐦 Swift | 169ms | `#################` |
| 4 | 🦀 Rust | 178ms | `#################` |
| 5 | 🌳 Elm | 187ms | `################` |

#### `make analyze`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🪶 Imba | 142ms | `####################` |
| 2 | 📦 Bun | 157ms | `##################` |
| 3 | 🧡 Kotlin | 160ms | `##################` |
| 4 | 🐦 Swift | 162ms | `#################` |
| 5 | ⚡ Zig | 179ms | `################` |

#### `make test`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🪶 Imba | 139ms | `####################` |
| 2 | 📦 Bun | 152ms | `##################` |
| 3 | 🐦 Swift | 159ms | `#################` |
| 4 | 🧡 Kotlin | 162ms | `#################` |
| 5 | ⚡ Zig | 179ms | `################` |

#### `make test-chess-engine`
| Rank | Implementation | Time | Chart |
|------|----------------|------|-------|
| 1 | 🦀 Rust | 8336ms | `####################` |
| 2 | 🦊 Nim | 8340ms | `####################` |
| 3 | 🐘 Php | 8348ms | `####################` |
| 4 | 🌳 Elm | 8376ms | `####################` |
| 5 | 🐍 Python | 8397ms | `####################` |
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
