# Duration Output for Build, Analyze, and Test Operations

## Overview

All chess engine implementations now output timing information for their build, analyze, and test operations. This allows for performance tracking and benchmarking across different language implementations.

## Format

Each operation (build, analyze, test) outputs duration information in the following standardized format:

```
⏱️  <Operation> started...
[operation output]
⏱️  <Operation> duration: <N>s
```

Where:
- `<Operation>` is one of: Build, Analyze, Test
- `<N>` is the number of seconds (as an integer) the operation took

## Examples

### Build Operation
```bash
$ make build
⏱️  Build started...
[build output]
⏱️  Build duration: 5s
```

### Analyze Operation
```bash
$ make analyze
⏱️  Analyze started...
Running Python static analysis...
[analysis output]
⏱️  Analyze duration: 12s
```

### Test Operation
```bash
$ make test
⏱️  Test started...
Running basic functionality test...
✅ Basic test passed
⏱️  Test duration: 2s
```

## Implementation Details

### Timing Mechanism

The duration is measured using the bash `date` command which is portable across all Unix-like systems:

```makefile
@START_TIME=$$(date +%s); \
[commands]; \
EXIT_CODE=$$?; \
END_TIME=$$(date +%s); \
DURATION=$$((END_TIME - START_TIME)); \
echo "⏱️  <Operation> duration: $${DURATION}s"; \
exit $$EXIT_CODE
```

### Exit Code Preservation

The implementation preserves the original exit code of the operation, ensuring that:
- Failed builds still report as failures
- Analysis warnings/errors are properly propagated
- Test failures are correctly detected by CI/CD systems

## Coverage

All 17 implementations in the `implementations/` directory support duration output:

- ✅ crystal
- ✅ dart
- ✅ elm
- ✅ gleam
- ✅ haskell
- ✅ julia
- ✅ kotlin
- ✅ lua
- ✅ mojo
- ✅ nim
- ✅ php
- ✅ python
- ✅ rescript
- ✅ ruby
- ✅ rust
- ✅ typescript
- ✅ zig

## Usage in CI/CD

The duration output is particularly useful in automated workflows:

1. **Performance Tracking**: Compare build/test times across implementations
2. **Regression Detection**: Identify when operations start taking longer
3. **Benchmarking**: Generate comparative performance reports
4. **Optimization**: Identify slow operations that need optimization

## Parsing Duration Output

To extract duration values programmatically:

```bash
# Extract duration from output
make build 2>&1 | grep "⏱️.*duration" | grep -oP '\d+(?=s)'
```

## Testing

To verify duration output is working:

```bash
# Test all three operations for an implementation
cd implementations/python
make build | grep "duration"
make analyze | grep "duration"
make test | grep "duration"
```

All three commands should output a duration line.

## Quarantine Policy

Implementations that cannot successfully output duration for build, analyze, and test operations should be moved to the `implementations-wip/` directory until the issues are resolved.

As of the last check, all implementations in `implementations/` have working duration output, so no implementations are currently quarantined for this reason.
