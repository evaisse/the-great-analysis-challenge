# Chess Engine Testing Framework

This directory contains a comprehensive testing framework for chess engine implementations. The framework provides structure verification, protocol compliance testing, and performance benchmarking.

## 📁 Directory Structure

```
test/
├── README.md                       # This documentation
├── README_PERFORMANCE_TESTING.md   # Detailed performance testing guide
├── performance_test.py             # 🚀 Main performance testing script
├── test_harness.py                 # ♟️ Chess protocol compliance testing
├── verify_implementations.py       # 🔍 Structure and compliance verification
├── test_local.sh                   # 💻 Local testing without Docker
├── test_suite.json                 # 📋 Test case definitions (if exists)
└── test_summary.md                 # 📊 Test result summaries (if exists)
```

## 🔧 Testing Tools Overview

### 1. `performance_test.py` - Performance Testing Suite

**Purpose**: Comprehensive performance benchmarking with timing and memory analysis.

**Key Features**:
- ⏱️ **Timing Measurement**: Separate timing for analyze, build, and test phases
- 💾 **Memory Monitoring**: Peak and average memory usage tracking (when psutil available)
- 🧹 **Cache Clearing**: Uses `make clean` for consistent testing environment
- 🐳 **Docker Integration**: Build and test Docker containers
- 📊 **Detailed Reporting**: Text and JSON output formats

**Command Line Usage**:
```bash
# Test all implementations
python3 test/performance_test.py

# Test specific implementation
python3 test/performance_test.py --impl implementations/rust

# Save reports to files
python3 test/performance_test.py --output report.txt --json results.json

# Custom timeout (default: 30 minutes)
python3 test/performance_test.py --timeout 3600

# Show help
python3 test/performance_test.py --help
```

**Command Line Options**:
```
--impl PATH        Test specific implementation directory
--output FILE      Save text report to file
--json FILE        Save JSON results to file
--timeout SECONDS  Overall timeout in seconds (default: 1800)
--help            Show help message and exit
```

**Example Output**:
```
🚀 Chess Engine Performance Testing Suite
============================================================
Testing rust implementation
🧹 Clearing build cache...
✅ Local cache cleared with make clean
🔍 Running static analysis...
✅ Analysis completed in 3.45s
🔨 Building implementation...
✅ Build completed in 5.23s
♟️ Running chess client tests...
  ✅ Basic Movement
  ✅ Castling
  ✅ En Passant
  ...
✅ Tests completed in 2.12s (7 passed, 0 failed)
🐳 Running Docker tests...
  ✅ Docker build completed in 28.76s
  ✅ Docker test completed in 4.33s
```

### 2. `test_harness.py` - Chess Protocol Testing

**Purpose**: Tests chess engine compliance with the chess protocol specification.

**Key Features**:
- ♟️ **Protocol Compliance**: Tests all required chess commands
- 🎯 **Comprehensive Test Suite**: 8 different test scenarios
- ⚡ **Performance Benchmarks**: AI depth testing and move generation speed
- 📊 **Detailed Reporting**: Pass/fail results with performance metrics

**Command Line Usage**:
```bash
# Test all implementations
python3 test/test_harness.py

# Test specific implementation
python3 test/test_harness.py --impl implementations/python

# Test specific implementation directory
python3 test/test_harness.py --dir implementations

# Run specific test case
python3 test/test_harness.py --test "Basic Movement"

# Include performance tests
python3 test/test_harness.py --performance

# Save report to file
python3 test/test_harness.py --output test_report.txt

# Show help
python3 test/test_harness.py --help
```

**Command Line Options**:
```
--dir DIR         Directory containing implementations (default: implementations)
--impl PATH       Test specific implementation
--test NAME       Run specific test case
--performance     Run performance tests
--output FILE     Output report file
--help           Show help message and exit
```

**Test Cases Included**:
1. **Basic Movement**: Standard piece moves (e2e4, e7e5, etc.)
2. **Castling**: King and rook castling moves
3. **En Passant**: Pawn en passant capture
4. **Checkmate Detection**: Fool's mate recognition
5. **AI Move Generation**: AI depth 3 move calculation
6. **Invalid Move Handling**: Error handling for illegal moves
7. **Pawn Promotion**: Promotion to queen
8. **Perft Accuracy**: Move generation validation (optional)

### 3. `verify_implementations.py` - Structure Verification

**Purpose**: Verifies that implementations follow required project structure and standards.

**Key Features**:
- 📁 **File Structure**: Checks for required files (Dockerfile, Makefile, README.md, chess.meta)
- 🐳 **Dockerfile Validation**: Ubuntu 24.04 base image, proper structure
- 🔨 **Makefile Validation**: Required targets (all, build, test, analyze, clean, docker-build, docker-test, help)
- 📋 **Metadata Validation**: chess.meta JSON format and required fields
- 📊 **Status Classification**: Excellent/Good/Needs Work rating

**Command Line Usage**:
```bash
# Verify all implementations
python3 test/verify_implementations.py

# Verify specific directory
python3 test/verify_implementations.py /path/to/implementations

# Show help
python3 test/verify_implementations.py --help
```

**Command Line Options**:
```
BASE_DIR          Base directory containing implementations (optional)
--help           Show help message and exit
```

**Verification Criteria**:

**Required Files**:
- `Dockerfile`: Docker container definition
- `Makefile`: Build automation with required targets
- `chess.meta`: JSON metadata file
- `README.md`: Implementation documentation

**Required Makefile Targets**:
- `all`, `build`, `test`, `analyze`, `clean`, `docker-build`, `docker-test`, `help`

**Required chess.meta Fields**:
- `language`, `version`, `author`, `build`, `run`, `features`, `max_ai_depth`

**Status Classifications**:
- 🟢 **Excellent**: All files present, full compliance, no issues
- 🟡 **Good**: Minor warnings or missing optional fields  
- 🔴 **Needs Work**: Missing required files or significant issues

### 4. `test_local.sh` - Local Testing Script

**Purpose**: Simple bash script for testing implementations locally without Docker.

**Key Features**:
- 💻 **Local Environment**: Tests using local language installations
- 🚀 **Quick Testing**: Fast verification without Docker overhead
- 🔍 **Basic Validation**: Simple smoke tests for Ruby and TypeScript

**Usage**:
```bash
# Run local tests
./test/test_local.sh

# Make executable if needed
chmod +x test/test_local.sh
```

## 🚀 Quick Start Guide

### 1. Verify Implementation Structure
```bash
# Check if all implementations meet structure requirements
python3 test/verify_implementations.py
```

### 2. Test Chess Protocol Compliance
```bash
# Test all implementations for chess protocol compliance
python3 test/test_harness.py --performance
```

### 3. Run Performance Benchmarks
```bash
# Run comprehensive performance tests
python3 test/performance_test.py --output benchmark_report.txt --json benchmark_data.json
```

### 4. Test Specific Implementation
```bash
# Test only Rust implementation
python3 test/performance_test.py --impl implementations/rust
python3 test/test_harness.py --impl implementations/rust
```

## 📊 Test Results and Reports

### Performance Test Output
- **Text Report**: Human-readable summary with timing breakdowns and error details
- **JSON Report**: Machine-readable data for analysis and CI/CD integration

### Test Harness Output
- **Console Output**: Real-time test results with pass/fail indicators
- **Summary Report**: Overall statistics and performance metrics

### Verification Output
- **Detailed Report**: File-by-file compliance checking
- **Summary Statistics**: Overall implementation health

## 🔧 Dependencies

### Python Dependencies
```bash
# Optional for memory monitoring (performance_test.py)
pip3 install psutil

# Core dependencies (all included in Python standard library)
# - subprocess, json, time, pathlib, argparse, threading
```

### System Dependencies
- **Docker**: Required for containerized testing
- **Language Tools**: Each implementation's build tools (rustc, node, python3, etc.)
- **Make**: Required for Makefile-based testing

## 💡 Testing Best Practices

### 1. Clean Environment
- Run `make clean` before testing for consistent results
- Use performance_test.py which automatically clears cache

### 2. Timeout Considerations
- Default timeouts: 5min analysis, 10min build, 30min overall
- Adjust timeouts for slower systems: `--timeout 3600`

### 3. Memory Monitoring
- Install psutil for detailed memory analysis
- Tests work without psutil but with limited memory data

### 4. Continuous Integration
- Use JSON output for automated result processing
- Check exit codes: 0 = success, 1 = failures detected

### 5. Debugging Failed Tests
- Check detailed error messages in reports
- Use `--impl` to isolate specific implementation issues
- Verify Makefile targets are properly implemented

## 🤝 Contributing Test Cases

To add new test cases to the test harness:

1. **Edit `test_harness.py`**:
```python
# Add to TestSuite.load_tests() method
self.tests.append({
    "name": "Your Test Name",
    "commands": ["new", "move e2e4", "export"],
    "validate": lambda output: "expected_string" in output,
    "timeout": 2.0,
    "optional": False  # Set to True for optional tests
})
```

2. **Update Documentation**: Add test description to this README

3. **Test Your Changes**: Run the test harness to verify new test works

## 📞 Troubleshooting

### Common Issues

**"No implementations found"**
- Ensure you're running from the project root directory
- Check that `implementations/*/chess.meta` files exist

**"Failed to start implementation"**
- Verify the implementation builds successfully: `cd implementations/X && make build`
- Check that the `run` command in chess.meta is correct

**"Docker build failed"**
- Ensure Docker daemon is running
- Check Dockerfile syntax and base image availability

**"Memory monitoring disabled"**
- Install psutil: `pip3 install psutil` (or use --break-system-packages if needed)
- Tests will work without memory monitoring

**Test timeouts**
- Increase timeout values for slower systems
- Check for infinite loops in implementation code

### Getting Help

For issues with the testing framework:
1. Check this documentation
2. Review error messages in test output
3. Test individual components in isolation
4. Check implementation-specific requirements