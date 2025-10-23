# Error Analysis Performance Testing

## Overview

This feature allows you to test and measure how static analysis tools detect errors across different programming language implementations. It provides a fair and consistent way to:

1. Inject language-appropriate bugs that static analyzers should catch
2. Measure analysis time with the injected bugs
3. Capture error output as evidence of analyzer effectiveness
4. Compare static analysis capabilities across languages

## Commands

Each implementation supports three new Makefile targets:

### `make bugit`
Injects a bug designed to be caught by static analysis tools.

- Creates a `.bugit/` directory to store backups
- Backs up the original file
- Injects a language-appropriate bug (unused variable, unused import, etc.)
- Creates a flag file to prevent double injection

**Example:**
```bash
cd implementations/python
make bugit
# ✅ Bug injected in lib/board.py
```

### `make fix`
Restores the original file, removing the injected bug.

- Restores from the backup in `.bugit/`
- Removes the flag file
- Cleans up the injection

**Example:**
```bash
cd implementations/python
make fix
# ✅ Bug fixed, original file restored
```

### `make analyze-with-bug`
Runs static analysis with the bug injected and captures results.

- Automatically injects the bug if not already done
- Runs all static analysis tools for that language
- Measures timing for each analyzer
- Saves complete output to `.bugit/analysis_results.txt`
- Displays a summary of detected issues

**Example:**
```bash
cd implementations/python
make analyze-with-bug
# Running static analysis with injected bug...
# === Analysis Results ===
# ...
# ✅ Analysis complete. Results saved to .bugit/analysis_results.txt
```

## Bulk Operations

The main Makefile provides targets to run operations across all implementations:

### `make bugit-all`
Injects bugs in all language implementations.

```bash
make bugit-all
```

### `make fix-all`
Fixes all injected bugs across all implementations.

```bash
make fix-all
```

### `make analyze-with-bug-all`
Runs static analysis with bugs on all implementations and generates a summary report.

```bash
make analyze-with-bug-all
# Creates analysis_reports/bug_analysis_summary.md
```

## Individual Language Targets

You can also target specific languages from the root directory:

```bash
make bugit-python           # Inject bug in Python
make analyze-with-bug-rust  # Analyze Rust with bug
make fix-typescript         # Fix TypeScript bug
```

## Bug Patterns

Each language has a carefully chosen bug pattern that:

- Is idiomatic to the language
- Should be caught by standard static analysis tools
- Doesn't break the build completely
- Is fair for comparison purposes

Examples:

- **Python**: Unused import and constant
- **Rust**: Unused function with dead code
- **TypeScript**: Unused variable
- **Go**: Unused package-level variable
- **Ruby**: Unused constant

See [bug-patterns.md](bug-patterns.md) for complete details on each language's bug pattern.

## Output Format

### Individual Analysis Results

Each implementation stores results in `.bugit/analysis_results.txt`:

```
=== Analysis Results ===
Timestamp: Wed Oct 23 18:12:33 UTC 2025

--- Pylint Analysis ---
real    0m2.345s
user    0m2.123s
sys     0m0.222s

lib/board.py:8:0: W0611: Unused import os (unused-import)
lib/board.py:9:0: C0103: Constant name "UNUSED_DEBUG_VARIABLE" doesn't conform to UPPER_CASE naming style (invalid-name)
...
```

### Summary Report

The bulk operation creates `analysis_reports/bug_analysis_summary.md`:

```markdown
# Static Analysis Bug Detection Report
Generated: Wed Oct 23 18:12:33 UTC 2025

## python
```
lib/board.py:8:0: W0611: Unused import os (unused-import)
lib/board.py:9:0: W0612: Unused variable 'UNUSED_DEBUG_VARIABLE'
```

## rust
```
warning: function `inject_bug` is never used
```

... (continues for all languages)
```

## Use Cases

### 1. Compare Static Analysis Capabilities

```bash
make analyze-with-bug-all
# Review analysis_reports/bug_analysis_summary.md
```

### 2. Measure Analysis Performance Impact

```bash
cd implementations/python

# Measure baseline
time make analyze

# Measure with bug
time make analyze-with-bug

# Compare timings
```

### 3. Test CI/CD Error Detection

```bash
# Inject bugs
make bugit-all

# Run CI checks (should fail)
# ...

# Clean up
make fix-all
```

### 4. Educational Comparison

```bash
# Show students how different languages detect issues
make bugit-python bugit-rust bugit-go
make analyze-with-bug-python analyze-with-bug-rust analyze-with-bug-go

# Compare the outputs
cat implementations/python/.bugit/analysis_results.txt
cat implementations/rust/.bugit/analysis_results.txt
cat implementations/go/.bugit/analysis_results.txt
```

## Cleanup

The `.bugit/` directories are automatically excluded from git (via `.gitignore`).

To clean up manually:

```bash
# Fix all bugs
make fix-all

# Or clean individual implementations
cd implementations/python
make fix
rm -rf .bugit/
```

## Notes

- Bug injection is idempotent - running `bugit` multiple times won't inject multiple bugs
- You must run `fix` before injecting a new bug
- The `.bugit/` directory structure:
  - `BUGGED` - Flag file indicating a bug is injected
  - `*.backup` - Original file backup
  - `analysis_results.txt` - Analysis output
- All operations are safe and reversible
- The bugs are intentionally simple to ensure consistent detection

## Examples

### Quick Test

```bash
# Test one language
cd implementations/typescript
make bugit
make analyze-with-bug
cat .bugit/analysis_results.txt
make fix
```

### Full Report

```bash
# Generate comprehensive report
make bugit-all
make analyze-with-bug-all
cat analysis_reports/bug_analysis_summary.md
make fix-all
```

## Troubleshooting

### Bug Won't Inject

```bash
# Check if already injected
ls implementations/python/.bugit/BUGGED

# Fix first
make fix-python
make bugit-python
```

### Analysis Results Missing

```bash
# Ensure bug is injected
make bugit-python

# Run analysis
make analyze-with-bug-python

# Check file
cat implementations/python/.bugit/analysis_results.txt
```
