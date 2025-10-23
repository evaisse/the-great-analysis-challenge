# The Great Analysis Challenge: Multi-Language Chess Engine Project

A comprehensive project implementing identical chess engines across **different programming languages** to compare their approaches, performance, and unique paradigms.

All implementations have complete feature parity:

- ✅ **perft** - Performance testing with recursive move generation
- ✅ **fen** - Forsyth-Edwards Notation support
- ✅ **ai** - Artificial intelligence with minimax algorithms
- ✅ **castling** - Special king-rook moves
- ✅ **en_passant** - Special pawn capture rules
- ✅ **promotion** - Pawn advancement to other pieces

## 📊 Performance Overview

<!-- status-table-start -->

| Language   | Status | Analysis Time | Build Time | Test Time |
| ---------- | ------ | ------------- | ---------- | --------- |
| Crystal    | 🟢     | 38ms          | 18ms       | 0ms       |
| Dart       | 🟢     | 1055ms        | 639ms      | 0ms       |
| Elm        | 🟢     | 722ms         | 847ms      | 0ms       |
| Gleam      | 🟢     | 36ms          | 22ms       | 0ms       |
| Go         | 🟢     | 280ms         | 153ms      | 0ms       |
| Haskell    | 🟢     | 42ms          | 15ms       | 0ms       |
| Julia      | 🟢     | 33ms          | 25ms       | 0ms       |
| Kotlin     | 🟢     | 258ms         | 128ms      | 0ms       |
| Mojo       | 🟢     | 33ms          | 33ms       | 0ms       |
| Nim        | 🟢     | 33ms          | 29ms       | 0ms       |
| Python     | 🟢     | 209ms         | 103ms      | 597ms     |
| Rescript   | 🟢     | 141ms         | 3443ms     | 0ms       |
| Ruby       | 🟢     | 1661ms        | 354ms      | 1850ms    |
| Rust       | 🟢     | 899ms         | 567ms      | 518ms     |
| Swift      | 🟢     | 1087ms        | 398ms      | 0ms       |
| Typescript | 🟢     | 0ms           | 0ms        | 0ms       |
| Zig        | 🟢     | 29ms          | 18ms       | 0ms       |

<!-- status-table-end -->

_All implementations tested via Docker for consistency. Times in milliseconds, measured on the same github actions vm._

## 🚀 Quick Start

```bash
# Test any implementation
cd implementations/<language> && make docker-test

# Run performance benchmarks
./workflow run-benchmark <language>

# Verify all implementations
python3 test/verify_implementations.py

# Test static analysis error detection
make bugit-all                   # Inject bugs in all implementations
make analyze-with-bug-all        # Run analysis and generate report
make fix-all                     # Clean up injected bugs
```

## 🔍 Error Analysis Performance Testing

Test how static analysis tools detect errors across different languages:

- **`make bugit`** - Inject a bug designed for static analysis detection
- **`make fix`** - Restore the original code
- **`make analyze-with-bug`** - Run static analysis with the bug and capture results
- **`make analyze-with-bug-all`** - Compare all languages' static analysis capabilities

📖 **[Complete Error Analysis Guide](./ERROR_ANALYSIS_GUIDE.md)** - Detailed documentation and examples

## CI/CD

- **🔄 Continuous Testing**: All implementations tested via Docker on every commit
- **📊 Weekly Benchmarks**: Performance reports generated every Sunday
- **🏷️ Automatic Releases**: Semantic versioning based on implementation health
- **📈 Performance Tracking**: Historical analysis and build time monitoring

**Manual Operations**: [GitHub Actions](../../actions/workflows/bench.yaml) | [Latest Results](../../releases/latest)

All implementations are tested exclusively via Docker containers to ensure:

- **Consistent Environment**: No host toolchain dependencies
- **Reproducible Results**: Identical testing conditions
- **Simplified CI/CD**: Only Docker required, not X language toolchains

## 📋 Architecture

Each implementation follows identical specifications defined in [CHESS_ENGINE_SPECS.md](./CHESS_ENGINE_SPECS.md):

- **Standardized Commands**: Identical interface across all languages
- **Docker Support**: Containerized testing and deployment
- **Makefile Targets**: `build`, `test`, `analyze`, `docker-test`, `bugit`, `fix`, `analyze-with-bug`
- **Metadata**: Structured information in `chess.meta` files
- **Error Analysis**: Bug injection system for testing static analyzers
