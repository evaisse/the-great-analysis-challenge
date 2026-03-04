# Chess Engine Performance Testing

This directory contains the performance benchmark runner used by CI and local workflows.

## `performance_test.py`

The benchmark now measures strictly separated phases for each implementation:

1. `make image DIR=<lang>`: Docker image build only
2. `make build DIR=<lang>`: compilation/build command only (`org.chess.build`)
3. `make analyze DIR=<lang>`: static analysis/lint only (`org.chess.analyze`)
4. `make test-chess-engine DIR=<lang>`: shared chess engine suite only (`test/test_suite.json`)

`build_seconds` and `test_seconds` in JSON outputs are based on steps 2 and 4.

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
- `test-chess-engine` runs the full shared suite.
- Host memory sampling is best-effort (requires `psutil`).
