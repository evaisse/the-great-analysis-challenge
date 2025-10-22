# Chess Engine Performance Testing

This directory contains comprehensive performance testing tools for chess engine implementations.

## Scripts Overview

### `performance_test.py` - Comprehensive Performance Testing
The main performance testing script that provides detailed analysis of implementation performance.

**Features:**
- 🧹 **Cache Clearing**: Clears local build artifacts using `make clean`
- ⏱️ **Timing Measurement**: Measures analyze, build, and test phases separately
- 💾 **Memory Monitoring**: Tracks memory consumption during all phases
- ♟️ **Chess Testing**: Uses existing test harness for consistent chess protocol testing
- 🐳 **Docker Testing**: Builds and tests Docker containers
- 📊 **Comprehensive Reporting**: Detailed text and JSON output

### `test_harness.py` - Chess Protocol Testing
Existing chess engine testing framework for protocol compliance.

### `verify_implementations.py` - Structure Verification
Verifies that implementations follow required project structure.

## Usage

### Test All Implementations
```bash
# Run complete performance test suite
python3 test/performance_test.py

# Save detailed report
python3 test/performance_test.py --output performance_report.txt --json results.json
```

### Test Specific Implementation
```bash
# Test only Python implementation
python3 test/performance_test.py --impl implementations/python

# Test Rust implementation with custom timeout
python3 test/performance_test.py --impl implementations/rust --timeout 3600
```

### Example Output
```
🚀 Chess Engine Performance Testing Suite
============================================================
Found 17 implementation(s) to test

============================================================
Testing python implementation
Path: /path/to/implementations/python
============================================================
🧹 Clearing build cache...
✅ Cache cleared
🔍 Running static analysis...
✅ Analysis completed in 0.85s
🔨 Building implementation...
✅ Build completed in 0.12s
♟️ Running chess client tests...
  ✅ Basic Movement
  ✅ Castling
  ✅ En Passant
  ✅ Checkmate Detection
  ✅ AI Move Generation
  ✅ Invalid Move Handling
  ✅ Pawn Promotion
✅ Tests completed in 2.34s (7 passed, 0 failed)
🐳 Running Docker tests...
  ✅ Docker build completed in 15.67s
  ✅ Docker test completed in 3.21s
```

## Test Phases

### 1. Cache Clearing
- Runs `make clean` to remove local build artifacts
- Ensures clean build environment for accurate timing measurements

### 2. Static Analysis (`make analyze`)
- Runs language-specific linters and type checkers
- Measures execution time and memory usage
- Captures warnings and errors

### 3. Build (`make build`)
- Compiles/builds the implementation
- Measures compilation time and memory usage
- Tracks build success/failure

### 4. Chess Client Tests
- Uses existing `test_harness.py` for consistent testing
- Tests basic moves, special moves, AI, error handling
- Measures test execution time and memory usage

### 5. Docker Tests
- Builds Docker image from scratch
- Runs containerized tests
- Measures Docker build and test times

## Memory Monitoring

The script uses `psutil` to monitor:
- **RSS Memory**: Resident Set Size in MB
- **Peak Memory**: Maximum memory usage during each phase
- **Average Memory**: Mean memory usage during monitoring
- **CPU Usage**: Average CPU utilization

Memory is sampled every 100ms during each test phase.

## Performance Metrics

### Timing Measurements
- `analyze_seconds`: Time spent on static analysis
- `build_seconds`: Time spent building/compiling
- `test_seconds`: Time spent running chess tests
- `docker.build_time`: Docker image build time
- `docker.test_time`: Docker test execution time

### Memory Measurements
- `analyze.peak_memory_mb`: Peak memory during analysis
- `build.peak_memory_mb`: Peak memory during build
- `test.peak_memory_mb`: Peak memory during testing
- `*.avg_memory_mb`: Average memory usage per phase

## Output Formats

### Text Report
Human-readable summary with:
- Performance summary table
- Detailed per-implementation results
- Error reporting
- Memory and timing breakdowns

### JSON Report
Machine-readable detailed results including:
- All timing measurements
- Memory usage statistics
- Test results and errors
- Docker build/test results
- Implementation metadata

## Error Handling

The script handles various failure scenarios:
- Build timeouts (10 minutes default)
- Analysis timeouts (5 minutes default)
- Docker build failures
- Chess engine startup failures
- Memory monitoring errors

Failed implementations are marked with status "failed" and detailed error messages are provided.

## Requirements

- Python 3.7+
- `psutil` library for memory monitoring
- Docker (for containerized testing)
- Each implementation's specific build tools

Install Python dependencies:
```bash
pip3 install psutil
```

## Performance Baseline

Expected performance characteristics on Apple Silicon M1:

| Language | Analyze | Build | Test | Memory |
|----------|---------|-------|------|---------|
| Python | ~0.2s | ~0.1s | ~2s | ~50MB |
| Rust | ~3-8s | ~5s | ~2s | ~200MB |
| Go | ~1-2s | ~1s | ~2s | ~100MB |
| TypeScript | ~2-4s | ~2s | ~3s | ~150MB |
| Ruby | ~1-3s | ~0.1s | ~2s | ~80MB |

Actual times may vary based on system load and hardware specifications.