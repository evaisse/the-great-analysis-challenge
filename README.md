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
| 📦 Bun | 🟢 | [669](implementations/bun/chess.js) | 299ms, 110 MB | 192ms, 7 MB | 192ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 💠 Crystal | 🟢 | [1692](implementations/crystal/src/chess_engine.cr) | 241ms, 110 MB | 959ms, 196 MB | 2394ms, 526 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🎯 Dart | 🟡 | [1739](implementations/dart/bin/main.dart) | 542ms, - MB | 1277ms, 211 MB | 3109ms, 451 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🌳 Elm | 🟢 | [1663](implementations/elm/src/ChessEngine.elm) | 1395ms, - MB | 379ms, 4 MB | 358ms, 9 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ✨ Gleam | 🟢 | [1917](implementations/gleam/src/chess_engine.gleam) | 288ms, 110 MB | 333ms, 6 MB | 777ms, 61 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐹 Go | 🟢 | [2237](implementations/go/chess.go) | 443ms, 65 MB | 1150ms, 111 MB | 1085ms, 115 MB | 8417ms, - MB | 1/1 | 1/1 | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📐 Haskell | 🟢 | [1085](implementations/haskell/src/Main.hs) | 423ms, 115 MB | 217ms, 7 MB | 229ms, 6 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪶 Imba | 🟡 | [700](implementations/imba/chess.imba) | 322ms, 110 MB | 209ms, 7 MB | 195ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🟨 Javascript | 🟡 | [682](implementations/javascript/chess.js) | 200ms, 110 MB | 192ms, 6 MB | 191ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔮 Julia | 🟢 | [1369](implementations/julia/chess.jl) | 235ms, 112 MB | 192ms, 7 MB | 181ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧡 Kotlin | 🟡 | [1524](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 213ms, 111 MB | 149ms, 7 MB | 171ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🪐 Lua | 🟢 | [1331](implementations/lua/chess.lua) | 432ms, - MB | 316ms, - MB | 264ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🔥 Mojo | 🟢 | [275](implementations/mojo/chess.mojo) | 581ms, 115 MB | 9695ms, - MB | 10301ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦊 Nim | 🟢 | [1105](implementations/nim/chess.nim) | 215ms, 110 MB | 184ms, 7 MB | 191ms, 6 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐘 Php | 🟢 | [2016](implementations/php/chess.php) | 711ms, - MB | 460ms, - MB | 241ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐍 Python | 🟡 | [2373](implementations/python/chess.py) | 103ms, - MB | 209ms, - MB | 597ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🧠 Rescript | 🟡 | [1678](implementations/rescript/src/Chess.res) | 291ms, 110 MB | 192ms, 7 MB | 206ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ❤️ Ruby | 🟡 | [1906](implementations/ruby/chess.rb) | 354ms, - MB | 1661ms, - MB | 1850ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🦀 Rust | 🟢 | [1852](implementations/rust/src/main.rs) | 13974ms, 110 MB | 197ms, 7 MB | 188ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 🐦 Swift | 🟢 | [856](implementations/swift/src/main.swift) | 369ms, 114 MB | 195ms, 7 MB | 181ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| 📘 Typescript | 🟡 | [1773](implementations/typescript/src/chess.ts) | 448ms, - MB | 1919ms, - MB | 945ms, - MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
| ⚡ Zig | 🟢 | [1589](implementations/zig/src/main.zig) | 280ms, 110 MB | 187ms, 7 MB | 188ms, 7 MB | -, - MB | 1/1 | - | 6/9 (67%) `perft` `fen` `ai` `castling` `en_passant` `promotion` |
<!-- status-table-end -->

Legend:
- `Status`: `🟢 excellent` = 0 error / 0 warning, `🟡 good` = 0 error with warnings, `🔴 needs_work` = at least 1 error.
- `make ...` columns: benchmarked command shown as `<duration>, <peak memory>`.
- `make test score`: score of `make test` (binary `1/1` success, `0/1` failure).
- `make test-chess-engine score`: shared harness score (`passed/total`) for the benchmark track.
- `-`: metric not yet available for this implementation/run.

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
