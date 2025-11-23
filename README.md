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

Detailed performance benchmarks, build times, and analysis results are available on the interactive website:

👉 **[View Performance Benchmarks](https://evaisse.github.io/the-great-analysis-challenge/)**

**Language Statistics**: Language popularity rankings from [TIOBE Index](https://www.tiobe.com/tiobe-index/) and GitHub repository counts from [GitHub Ranking](https://github.com/EvanLi/Github-Ranking). Data is stored in [`language_statistics.yaml`](./language_statistics.yaml) and updated monthly.

## 🛠 Implementation Status

### ✅ Fully Functional
These implementations pass all basic tests and implement core features:
- **Go**
- **Lua**
- **Nim**
- **PHP**
- **Python**
- **Ruby**
- **Rust**
- **Swift** (Note: `undo` command currently unavailable)
- **TypeScript**

### ⚠️ Partial / In Progress
These implementations have build or runtime issues:
- **Crystal**: Runtime error (Stack overflow)
- **Zig**: Build environment issues
- **Others** (Julia, Kotlin, Haskell, etc.): Pending build environment configuration

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

Each implementation follows identical specifications:

- **Chess Rules & Interface**: [CHESS_ENGINE_SPECS.md](./CHESS_ENGINE_SPECS.md) - Core engine requirements
- **Project Conventions**: [CONVENTIONS.md](./CONVENTIONS.md) - The "Golden Rule" for infrastructure
- **AI Algorithm**: [AI_ALGORITHM_SPEC.md](./AI_ALGORITHM_SPEC.md) - Deterministic move selection algorithm
- **Standardized Commands**: Identical interface across all languages
- **Docker Support**: Containerized testing and deployment
- **Makefile Targets**: `build`, `test`, `analyze` (agnostic of implementation)
- **Metadata**: Structured information in `chess.meta` files
