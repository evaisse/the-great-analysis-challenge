# Modular Workflow Scripts

This directory contains a modular workflow system with individual Python modules for each command, orchestrated by a unified `workflow.py` dispatcher. Each subcommand has its own dedicated module for better organization and maintainability.

A convenient entrypoint script (`/workflow`) is provided at the project root for easier command-line usage.

## Architecture

- **`workflow.py`** - Main dispatcher that delegates to individual command modules
- **Individual modules** - Each subcommand has its own Python file (e.g., `detect_changes.py`, `generate_matrix.py`)
- **Fallback support** - If modules can't be imported, falls back to inline implementations
- **Standalone capability** - Each module can be run independently if needed

## Usage

```bash
# From project root directory (recommended)
./workflow <command> [arguments]

# Or directly from scripts directory  
python3 workflow.py <command> [arguments]

# Or run individual modules directly
python3 .github/workflows/scripts/detect_changes.py <args>
python3 .github/workflows/scripts/generate_matrix.py <args>
```

## Individual Modules

Each command is implemented in its own module:

| Module | Command | Description |
|--------|---------|-------------|
| `detect_changes.py` | `detect-changes` | Detect changed implementations from git diff |
| `generate_matrix.py` | `generate-matrix` | Generate GitHub Actions matrix for parallel jobs |
| `run_benchmark.py` | `run-benchmark` | Run benchmark for specific implementation |
| `verify_implementations.py` | `verify-implementations` | Run structure verification and count results |
| `combine_results.py` | `combine-results` | Combine benchmark artifacts from multiple jobs |
| `update_readme.py` | `update-readme` | Update README status table with latest results |
| `get_test_config.py` | `get-test-config` | Get test configuration from chess.meta files |
| `create_release.py` | `create-release` | Create and tag releases with version bumping |

All modules can be run standalone with their own `--help` for detailed usage.

## Available Commands

### Development and Local Testing

```bash
# Detect changed implementations (useful for local testing)
./workflow detect-changes "workflow_dispatch" --test-all "true"

# Generate matrix for specific implementations
./workflow generate-matrix "python rust go"

# Get test configuration for an implementation
./workflow get-test-config "python"

# Run benchmark for a single implementation
./workflow run-benchmark "python" "implementations/python" --timeout 300

# Run structure verification
./workflow verify-implementations
```

### CI/CD Operations

```bash
# Combine benchmark results from artifacts
./workflow combine-results

# Update README status table
./workflow update-readme

# Create a release
./workflow create-release \
  --version-type "patch" \
  --readme-changed "true" \
  --excellent-count 5 \
  --good-count 3 \
  --needs-work-count 2 \
  --total-count 10
```

### Docker Testing Commands

```bash
# Test basic chess engine commands
./workflow test-basic-commands "python"

# Test advanced features
./workflow test-advanced-features "python" --supports-perft true --supports-ai true

# Test demo mode
./workflow test-demo-mode "python"

# Cleanup Docker images and files
./workflow cleanup-docker "python"
```

## Advantages of the Unified Script

1. **Reproducible**: All operations use arguments instead of environment variables, making them easy to test locally
2. **Consistent**: Single Python codebase instead of mixed bash/Python scripts
3. **Maintainable**: All workflow logic in one place with proper error handling
4. **Documented**: Built-in help with `--help` for each command
5. **Testable**: Can be run outside GitHub Actions environment

## Command Details

### detect-changes
Detects changed implementations based on git diff.
- `event_name`: GitHub event name (push, pull_request, workflow_dispatch, etc.)
- `--test-all`: Whether to test all implementations (true/false)
- `--base-sha`, `--head-sha`, `--before-sha`: Git SHAs for diff comparison

### generate-matrix
Generates GitHub Actions matrix for parallel jobs.
- `changed_implementations`: Space-separated list of implementation names, or "all"

### run-benchmark
Runs benchmark for a specific implementation.
- `impl_name`: Implementation name (e.g., "python")
- `impl_dir`: Implementation directory (e.g., "implementations/python")
- `--timeout`: Timeout in seconds (default: 300)

### verify-implementations
Runs structure verification and counts results by status.

### combine-results
Combines benchmark artifacts from multiple parallel jobs.

### update-readme
Updates README status table with latest benchmark results.

### create-release
Creates and tags a release with version bumping.
- `--version-type`: major, minor, or patch (default: patch)
- `--readme-changed`: Whether README was changed (true/false)
- `--excellent-count`, `--good-count`, `--needs-work-count`, `--total-count`: Status counts

### get-test-config
Reads chess.meta files to determine test configuration.
- `implementation`: Implementation name

## Examples

### Local Development Workflow

```bash
# Check what implementations would be tested
./workflow detect-changes "push" --before-sha "HEAD~1"

# Generate matrix for changed implementations
./workflow generate-matrix "$(./workflow detect-changes "push" --before-sha "HEAD~1" | jq -r .implementations)"

# Test a specific implementation locally
./workflow run-benchmark "python" "implementations/python"

# Check implementation configuration
./workflow get-test-config "python"
```

### CI/CD Workflow

The GitHub Actions workflow now uses this script instead of individual bash scripts:

```yaml
- name: Detect changed implementations
  run: |
    python3 .github/workflows/scripts/workflow.py detect-changes \
      "${{ github.event_name }}" \
      --test-all "true" \
      --base-sha "${{ github.event.pull_request.base.sha }}" \
      --head-sha "${{ github.sha }}" \
      --before-sha "${{ github.event.before }}"

- name: Run benchmark for ${{ matrix.name }}
  run: python3 .github/workflows/scripts/workflow.py run-benchmark ${{ matrix.engine }} ${{ matrix.directory }} --timeout 300
```

## Migration from Old Scripts

The following old scripts have been replaced:

| Old Script | New Command |
|------------|-------------|
| `detect_changes.py` | `workflow.py detect-changes` |
| `generate_matrix.py` | `workflow.py generate-matrix` |
| `run_benchmark.sh` | `workflow.py run-benchmark` |
| `count_verification_results.sh` | `workflow.py verify-implementations` |
| `combine_benchmark_artifacts.sh` | `workflow.py combine-results` |
| `update_readme_and_check.sh` | `workflow.py update-readme` |
| `create_release.sh` | `workflow.py create-release` |
| `test_basic_commands.sh` | `workflow.py test-basic-commands` |
| `test_advanced_features.sh` | `workflow.py test-advanced-features` |
| `test_demo_mode.sh` | `workflow.py test-demo-mode` |
| `cleanup_docker.sh` | `workflow.py cleanup-docker` |
| `get_test_config.py` | `workflow.py get-test-config` |

All old scripts can be safely removed once the workflow migration is complete and tested.