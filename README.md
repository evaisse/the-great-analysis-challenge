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

| Language | Status | LOC | Build | Test | Analyze | Memory | Features |
|----------|--------|-----|-------|------|---------|--------|----------|
| 📦 Bun | 🟢 | [669](implementations/bun/chess.js) | 299ms | 192ms | 192ms | 110 MB | - |
| 💠 Crystal | 🟢 | [1692](implementations/crystal/src/chess_engine.cr) | 241ms | 2394ms | 959ms | 526 MB | - |
| 🎯 Dart | 🟡 | [1739](implementations/dart/bin/main.dart) | 542ms | 3109ms | 1277ms | 451 MB | - |
| 🌳 Elm | 🟢 | [1663](implementations/elm/src/ChessEngine.elm) | 1395ms | 358ms | 379ms | 9 MB | - |
| ✨ Gleam | 🟢 | [1917](implementations/gleam/src/chess_engine.gleam) | 288ms | 777ms | 333ms | 110 MB | - |
| 🐹 Go | 🟢 | [2237](implementations/go/chess.go) | 202ms | 1039ms | 1145ms | 115 MB | - |
| 📐 Haskell | 🟢 | [1085](implementations/haskell/src/Main.hs) | 423ms | 229ms | 217ms | 115 MB | - |
| 🪶 Imba | 🟡 | [700](implementations/imba/chess.imba) | 322ms | 195ms | 209ms | 110 MB | - |
| 🟨 Javascript | 🟡 | [682](implementations/javascript/chess.js) | 200ms | 191ms | 192ms | 110 MB | - |
| 🔮 Julia | 🟢 | [1369](implementations/julia/chess.jl) | 235ms | 181ms | 192ms | 112 MB | - |
| 🧡 Kotlin | 🟡 | [1524](implementations/kotlin/src/main/kotlin/ChessEngine.kt) | 213ms | 171ms | 149ms | 111 MB | - |
| 🪐 Lua | 🟢 | [1331](implementations/lua/chess.lua) | 432ms | 264ms | 316ms | - MB | - |
| 🔥 Mojo | 🟢 | [275](implementations/mojo/chess.mojo) | 581ms | 10301ms | 9695ms | 115 MB | - |
| 🦊 Nim | 🟢 | [1105](implementations/nim/chess.nim) | 215ms | 191ms | 184ms | 110 MB | - |
| 🐘 Php | 🟢 | [2016](implementations/php/chess.php) | 711ms | 241ms | 460ms | - MB | - |
| 🐍 Python | 🟡 | [2373](implementations/python/chess.py) | 103ms | 597ms | 209ms | - MB | - |
| 🧠 Rescript | 🟡 | [1678](implementations/rescript/src/Chess.res) | 291ms | 206ms | 192ms | 110 MB | - |
| ❤️ Ruby | 🟡 | [1906](implementations/ruby/chess.rb) | 354ms | 1850ms | 1661ms | - MB | - |
| 🦀 Rust | 🟢 | [1852](implementations/rust/src/main.rs) | 13974ms | 188ms | 197ms | 110 MB | - |
| 🐦 Swift | 🟢 | [856](implementations/swift/src/main.swift) | 369ms | 181ms | 195ms | 114 MB | - |
| 📘 Typescript | 🟡 | [1773](implementations/typescript/src/chess.ts) | 448ms | 945ms | 1919ms | - MB | - |
| ⚡ Zig | 🟢 | [1589](implementations/zig/src/main.zig) | 280ms | 188ms | 187ms | 110 MB | - |
<!-- status-table-end -->

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
