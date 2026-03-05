# Chess Engine Performance Testing

This directory contains the performance benchmark runner used by CI and local workflows.

## `performance_test.py`

The benchmark now measures strictly separated phases for each implementation:

1. `make image DIR=<lang>`: Docker image build only
2. `make build`: compilation/build command inside container
3. `make analyze`: static analysis/lint inside container
4. `make test`: internal implementation tests inside container
5. `make test-chess-engine DIR=<lang> [TRACK=...]`: shared chess engine suite (`test/test_suite.json`)

Main JSON timings:
- `build_seconds` -> step 2 (`make build`)
- `analyze_seconds` -> step 3 (`make analyze`)
- `test_seconds` -> step 4 (`make test`)
- `test_chess_engine_seconds` -> step 5 (`make test-chess-engine`)

Additional timing:
- `image_build_seconds` measures step 1 (Docker image build prerequisite)

## Usage

```bash
# Benchmark all implementations
python3 test/performance_test.py

# Benchmark one implementation
python3 test/performance_test.py --impl implementations/rust

# Save reports
python3 test/performance_test.py --output reports/rust.out.txt --json reports/rust.json
```

## Notes

- Benchmarks are Docker-only via root Make targets.
- `build` is compile-only by contract.
- `test` covers implementation-internal checks.
- `test-chess-engine` runs the shared suite for the selected track.
- Host memory sampling is best-effort (requires `psutil`).
