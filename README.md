# The Great Analysis Challenge: Multi-Language Chess Engine Project

A comprehensive project implementing identical chess engines across **different programming languages** to compare their approaches, performance, and unique paradigms.

🌐 **[View Interactive Website](https://evaisse.github.io/the-great-analysis-challenge/)** - Complete comparison table and source code explorer

## 📚 Available Implementations

All implementations have complete feature parity with the following features:

- ✅ **perft** - Performance testing with recursive move generation
- ✅ **fen** - Forsyth-Edwards Notation support
- ✅ **ai** - Artificial intelligence with minimax algorithms
- ✅ **castling** - Special king-rook moves
- ✅ **en_passant** - Special pawn capture rules
- ✅ **promotion** - Pawn advancement to other pieces

### Working Implementations (7 languages)

All implementations are fully working with complete feature support and produce benchmark timing results:

- Dart
- Lua
- PHP
- Python
- Ruby
- Rust
- TypeScript

### Work In Progress (12 languages)

These implementations are available in the `implementations-wip/` directory and have various issues preventing them from producing benchmark results. See [implementations-wip/README.md](./implementations-wip/README.md) for details:

- Crystal (no compiler on test host)
- Elm (no compiler + type errors)
- Gleam (no compiler on test host)
- Go (build structure mismatch)
- Haskell (network issues)
- Julia (slow package installation)
- Kotlin (Gradle wrapper issue)
- Mojo (no compiler + Docker issues)
- Nim (no compiler on test host)
- ReScript (no compiler + deprecated config)
- Swift (folder structure mismatch)
- Zig (no compiler on test host)

📊 **For detailed performance metrics, build times, and comprehensive comparisons**, visit the [Interactive Website](https://evaisse.github.io/the-great-analysis-challenge/).

## 🚀 Quick Start

```bash
# List all available implementations
make list-implementations

# Build a specific implementation
make build DIR=go

# Test a specific implementation
make test DIR=ruby

# Analyze a specific implementation
make analyze DIR=python

# Build and test all implementations
make build-all
make test-all

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
- **Makefile Targets**: `build`, `test`, `analyze`, `docker-test`
- **Metadata**: Structured information in `chess.meta` files
