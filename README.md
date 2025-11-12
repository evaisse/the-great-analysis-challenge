# The Great Analysis Challenge: Multi-Language Chess Engine Project

A comprehensive project implementing identical chess engines across **different programming languages** to compare their approaches, performance, and unique paradigms.

🌐 **[View Interactive Website](https://evaisse.github.io/the-great-analysis-challenge/)** - Complete comparison table and source code explorer

All implementations have complete feature parity:

- ✅ **perft** - Performance testing with recursive move generation
- ✅ **fen** - Forsyth-Edwards Notation support
- ✅ **ai** - Artificial intelligence with minimax algorithms
- ✅ **castling** - Special king-rook moves
- ✅ **en_passant** - Special pawn capture rules
- ✅ **promotion** - Pawn advancement to other pieces

## 📊 Performance Overview

<!-- status-table-start -->

| Language | Status | Analysis Time | Build Time | Test Time |
|----------|--------|---------------|------------|-----------|
| Crystal | 🟢 | 38ms | 18ms | - |
| Dart | 🟢 | 977ms | 406ms | 2489ms |
| Elm | 🟢 | 722ms | 847ms | - |
| Gleam | 🟢 | 36ms | 22ms | - |
| Go | 🟢 | 280ms | 153ms | - |
| Haskell | 🟢 | 42ms | 15ms | - |
| Julia | 🟢 | 33ms | 25ms | - |
| Kotlin | 🟢 | 258ms | 128ms | - |
| Lua | 🟢 | - | - | - |
| Mojo | 🟢 | 33ms | 33ms | - |
| Nim | 🟢 | 33ms | 29ms | - |
| Php | 🟢 | - | - | - |
| Python | 🟢 | 209ms | 103ms | 597ms |
| Rescript | 🟢 | 141ms | 3443ms | - |
| Ruby | 🟢 | 1661ms | 354ms | 1850ms |
| Rust | 🟢 | 899ms | 567ms | 518ms |
| Swift | 🟢 | 1087ms | 398ms | - |
| Typescript | 🟢 | 1919ms | 448ms | 945ms |
| Zig | 🟢 | 29ms | 18ms | - |
<!-- status-table-end -->

_All implementations tested via Docker for consistency. Times in milliseconds, measured on the same github actions vm._

**Language Statistics**: Language popularity rankings from [TIOBE Index](https://www.tiobe.com/tiobe-index/) and GitHub repository counts from [GitHub Ranking](https://github.com/EvanLi/Github-Ranking). Data is stored in [`language_statistics.yaml`](./language_statistics.yaml) and updated monthly.

## 🚀 Quick Start

```bash
# Test any implementation
cd implementations/<language> && make docker-test

# Run performance benchmarks
./workflow run-benchmark <language>

# Verify all implementations
python3 test/verify_implementations.py
```

## CI/CD

- **🔄 Continuous Testing**: All implementations tested via Docker on every commit
- **📊 Weekly Benchmarks**: Performance reports generated every Sunday
- **🏷️ Automatic Releases**: Semantic versioning based on implementation health
- **📈 Performance Tracking**: Historical analysis and build time monitoring
- **🎯 Issue Triage**: Automated label application and clarification requests

**Manual Operations**: [GitHub Actions](../../actions/workflows/bench.yaml) | [Latest Results](../../releases/latest) | [Issue Triage Docs](./docs/ISSUE_TRIAGE_WORKFLOW.md)

All implementations are tested exclusively via Docker containers to ensure:

- **Consistent Environment**: No host toolchain dependencies
- **Reproducible Results**: Identical testing conditions
- **Simplified CI/CD**: Only Docker required, not X language toolchains

## 📋 Architecture

Each implementation follows identical specifications defined in [CHESS_ENGINE_SPECS.md](./CHESS_ENGINE_SPECS.md):

- **Standardized Commands**: Identical interface across all languages
- **Docker Support**: Containerized testing and deployment
- **Makefile Targets**: `build`, `test`, `analyze`, `docker-test`
- **Metadata**: Structured information in `chess.meta` files
