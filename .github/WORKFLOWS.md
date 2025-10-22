# GitHub Actions Workflows Documentation

This document provides a comprehensive overview of the automated CI/CD workflows for the Great Analysis Challenge project, which tests and benchmarks 17 different chess engine implementations.

## 🏗️ Workflow Architecture

The project uses a sophisticated workflow system with two main GitHub Actions workflows and a unified command-line tool that orchestrates all operations.

### Core Components

- **🔧 Unified Workflow Script** (`./workflow`): Central command-line interface
- **📊 Benchmark Suite** (`bench.yaml`): Automated performance testing and releases
- **🧪 Test Suite** (`test.yaml`): Pull request validation and testing
- **📁 Support Scripts** (`.github/workflows/scripts/`): Modular Python utilities

---

## 📊 Benchmark Suite Workflow (`bench.yaml`)

**Purpose**: Automated performance benchmarking, status reporting, and release management

### Triggers
- **Push to master**: Full benchmark suite on production changes
- **Weekly Schedule**: Sunday 6 AM UTC for regular status updates
- **Manual Dispatch**: On-demand execution with version bump options

### Workflow Stages

#### 1. **Detect Changes** 
```bash
./workflow detect-changes <event_name> --test-all true --base-sha <sha> --head-sha <sha>
```
- Analyzes git diff to identify modified implementations
- Generates dynamic matrix for parallel job execution
- Supports full testing override for scheduled runs

#### 2. **Structure Validation**
```bash
./workflow verify-implementations
```
- Validates all implementation structure and metadata
- Checks for required files (Dockerfile, Makefile, chess.meta, README.md)
- Verifies feature completeness and compliance
- Outputs counts: excellent/good/needs-work status

#### 3. **Parallel Benchmarking**
```bash
./workflow run-benchmark <engine> --timeout 300
```
- **Matrix Strategy**: Dynamic parallel execution per implementation
- **Docker Testing**: Builds and runs each chess engine in isolation
- **Performance Metrics**: Build time, execution time, memory usage
- **Chess Protocol Testing**: Validates engine compliance with specification
- **Artifact Generation**: Creates JSON and text reports per implementation

#### 4. **Results Aggregation**
```bash
./workflow combine-results
./workflow update-readme
```
- Combines individual benchmark artifacts into unified reports
- Updates main README.md status table with latest results
- Integrates verification data for accurate status reporting
- Generates comprehensive performance summaries

#### 5. **Release Management**
```bash
./workflow create-release --version-type <patch|minor|major>
```
- Automated semantic versioning based on implementation health
- Creates GitHub releases with benchmark artifacts
- Tags repository with version information
- Includes detailed release notes and performance metrics

### Key Features
- **⏱️ Timeout Protection**: 20-minute workflow limit with per-job timeouts
- **🔄 Failure Tolerance**: Continues testing even if individual engines fail
- **📦 Artifact Management**: Comprehensive result collection and storage
- **🎯 Selective Testing**: Only tests changed implementations for efficiency

---

## 🧪 Test Suite Workflow (`test.yaml`)

**Purpose**: Pull request validation and development workflow testing

### Triggers
- **Pull Requests**: Validates changes before merge
- **Manual Dispatch**: Development testing with optional full test override

### Workflow Stages

#### 1. **Change Detection**
```bash
./workflow detect-changes <event_name> --test-all <boolean>
```
- Identifies implementations modified in PR
- Generates targeted test matrix for efficiency
- Supports full test override for comprehensive validation

#### 2. **Structure Validation**
```bash
python3 test/verify_implementations.py
```
- Validates implementation structure and metadata
- Ensures compliance with project standards
- Verifies chess.meta configuration accuracy

#### 3. **Build and Test Matrix**
```bash
./workflow get-test-config <engine>
./workflow test-basic-commands <engine>
./workflow test-advanced-features <engine> --supports-perft <bool> --supports-ai <bool>
./workflow test-demo-mode <engine>
```

**Testing Modes**:
- **Full Mode**: Complete chess engine functionality testing
  - Basic commands (help, display, fen)
  - Advanced features (perft, AI, move validation)
  - Interactive gameplay testing
  - Performance validation

- **Demo Mode**: Limited testing for proof-of-concept implementations
  - Basic command validation
  - Structure verification
  - Reduced feature requirements

#### 4. **Cleanup and Summary**
```bash
./workflow cleanup-docker <engine>
```
- Automatic Docker resource cleanup
- Test result aggregation and reporting
- PR status summary with actionable feedback

### Key Features
- **🎯 Smart Testing**: Only tests changed implementations
- **⚡ Fast Feedback**: Optimized for development workflow
- **🧪 Adaptive Testing**: Handles both full and demo implementations
- **🏗️ Docker Isolation**: Each engine tested in clean environment
- **📋 Comprehensive Reporting**: Detailed test results and summaries

---

## 🔧 Unified Workflow Tool (`./workflow`)

Central command-line interface that orchestrates all operations. Built with Python and modular architecture.

### Core Commands

#### Development & Testing
```bash
./workflow test-basic-commands <engine>     # Basic functionality testing
./workflow test-advanced-features <engine> # Full feature testing  
./workflow test-demo-mode <engine>         # Demo implementation testing
./workflow get-test-config <engine>        # Extract testing configuration
```

#### Benchmarking & Performance
```bash
./workflow run-benchmark <engine>          # Single implementation benchmark
./workflow combine-results                 # Aggregate benchmark data
./workflow verify-implementations          # Structure and compliance verification
```

#### CI/CD Operations
```bash
./workflow detect-changes <event>          # Git diff analysis for selective testing
./workflow generate-matrix <implementations> # Dynamic GitHub Actions matrix
./workflow update-readme                   # Automated documentation updates
./workflow create-release --version-type <type> # Release management
```

#### Maintenance
```bash
./workflow cleanup-docker <engine>         # Docker resource cleanup
```

### Command Details

#### `detect-changes`
- **Purpose**: Intelligent change detection for efficient CI/CD
- **Logic**: Analyzes git diff, supports override flags, handles multiple trigger types
- **Output**: JSON list of changed implementations for matrix generation

#### `run-benchmark` 
- **Purpose**: Comprehensive performance testing of individual implementations
- **Process**: Docker build → Chess protocol testing → Performance measurement → Report generation
- **Output**: JSON performance data and human-readable reports

#### `verify-implementations`
- **Purpose**: Structure validation and compliance checking
- **Validation**: Required files, metadata accuracy, feature declarations, docker compatibility
- **Classification**: Excellent (all features + compliance) / Good (minor issues) / Needs Work (significant problems)

#### `update-readme`
- **Purpose**: Automated documentation maintenance
- **Integration**: Combines verification results with performance data
- **Safety**: Validates target file content before modifications

---

## 📁 Support Scripts Architecture

Located in `.github/workflows/scripts/`, these modular Python scripts power the workflow system:

### Core Modules

| Script | Purpose | Usage |
|--------|---------|-------|
| `workflow.py` | Main orchestrator and CLI interface | Entry point for all operations |
| `detect_changes.py` | Git diff analysis and change detection | Selective testing logic |
| `generate_matrix.py` | GitHub Actions matrix generation | Parallel job configuration |
| `run_benchmark.py` | Performance testing and measurement | Individual engine benchmarking |
| `verify_implementations.py` | Structure validation and compliance | Quality assurance checks |
| `combine_results.py` | Benchmark data aggregation | Results compilation |
| `update_readme.py` | Documentation automation | README status table updates |
| `create_release.py` | Release management and versioning | GitHub release automation |
| `test_docker.py` | Docker testing utilities | Container-based validation |
| `get_test_config.py` | Configuration extraction | chess.meta parsing |

### Design Principles

- **🔧 Modular Architecture**: Each script handles specific functionality
- **🐍 Python-based**: Consistent language across all tooling
- **📊 Data-driven**: JSON-based configuration and result formats
- **🛡️ Error Handling**: Comprehensive validation and graceful failure
- **📝 Logging**: Detailed output for debugging and monitoring

---

## 🎯 Testing Strategy

### Implementation Classification

The system automatically classifies implementations based on completeness:

#### 🟢 **Excellent Status**
- ✅ All 6 standard features: `perft`, `fen`, `ai`, `castling`, `en_passant`, `promotion`
- ✅ Complete file structure: `Dockerfile`, `Makefile`, `chess.meta`, `README.md`
- ✅ Successful Docker build and execution
- ✅ All chess protocol tests passing
- ✅ Performance benchmarks within expected ranges

#### 🟡 **Good Status**  
- ✅ Most core features implemented (4+ of 6)
- ✅ Essential files present
- ✅ Successful build process
- ⚠️ Minor issues or missing optional components

#### 🔴 **Needs Work Status**
- ❌ Missing core features or files
- ❌ Build failures or significant errors
- ❌ Chess protocol compliance issues

### Testing Modes

#### **Full Feature Testing**
Complete validation for production-ready implementations:
- **Basic Commands**: `help`, `display`, `fen`
- **Move Generation**: `perft` accuracy testing
- **AI System**: Computer move generation
- **Special Moves**: Castling, en passant, promotion
- **Interactive Mode**: Human vs. computer gameplay
- **Performance**: Speed and memory benchmarks

#### **Demo Mode Testing**
Simplified validation for proof-of-concept implementations:
- **Basic Functionality**: Help and display commands
- **Structure Validation**: Required files and metadata
- **Build Verification**: Docker container creation
- **Limited Protocol**: Subset of chess engine specification

---

## 📈 Performance Metrics

### Automated Measurements

#### **Build Performance**
- **Compilation Time**: Language-specific build duration
- **Docker Image Size**: Container efficiency metrics
- **Memory Usage**: Build-time resource consumption
- **Dependency Resolution**: Package installation timing

#### **Runtime Performance**
- **Chess Engine Speed**: Perft nodes per second
- **AI Performance**: Move generation and evaluation timing
- **Memory Efficiency**: Runtime resource usage
- **Response Time**: Command processing latency

#### **Quality Metrics**
- **Test Coverage**: Feature implementation completeness
- **Protocol Compliance**: Chess engine specification adherence
- **Error Rates**: Failure frequency and error types
- **Stability**: Consistent performance across runs

### Reporting and Analysis

- **📊 JSON Data**: Machine-readable performance metrics
- **📝 Human Reports**: Formatted summaries and comparisons
- **📈 Trending**: Historical performance tracking
- **🏆 Rankings**: Language performance comparisons
- **📋 Status Badges**: Real-time quality indicators

---

## 🚀 Usage Examples

### Development Workflow

```bash
# Test specific implementation during development
./workflow test-basic-commands rust
./workflow test-advanced-features rust --supports-perft true --supports-ai true

# Run full benchmark suite locally
./workflow run-benchmark python --timeout 300

# Validate all implementations
./workflow verify-implementations

# Update documentation
./workflow update-readme
```

### CI/CD Operations

```bash
# Detect changes for selective testing (used in workflows)
./workflow detect-changes pull_request --base-sha $BASE --head-sha $HEAD

# Generate dynamic test matrix
./workflow generate-matrix "rust,python,go"

# Combine benchmark results and create release
./workflow combine-results
./workflow create-release --version-type minor
```

### Maintenance Tasks

```bash
# Clean up Docker resources
./workflow cleanup-docker rust

# Extract testing configuration
./workflow get-test-config kotlin

# Manual README update
./workflow update-readme
```

---

## 🔧 Configuration

### Implementation Metadata (`chess.meta`)

Each implementation includes a `chess.meta` JSON file with configuration:

```json
{
  "language": "rust",
  "version": "1.70",
  "author": "Rust Implementation",
  "build": "cargo build --release",
  "run": "cargo run --release",
  "analyze": "cargo clippy -- -D warnings && cargo fmt --check", 
  "test": "cargo test",
  "features": ["perft", "fen", "ai", "castling", "en_passant", "promotion"],
  "max_ai_depth": 5,
  "estimated_perft4_ms": 600
}
```

### Workflow Configuration

Environment variables and settings:

```yaml
env:
  PYTHON_VERSION: '3.11'      # Consistent Python runtime
  DOCKER_BUILDKIT: 1          # Enhanced Docker builds
```

---

## 📊 Current Status

**🏆 Achievement: 100% Feature Standardization Complete!**

- **17/17 implementations** with excellent status
- **All standard features** implemented across all languages
- **Comprehensive testing** covering full chess engine specification
- **Automated quality assurance** with continuous monitoring
- **Performance benchmarking** with historical tracking

### Latest Metrics
- **Total Implementations**: 17 programming languages
- **Excellent Status**: 17/17 (100%)
- **Good Status**: 0/17 (0%)
- **Needs Work**: 0/17 (0%)
- **Test Coverage**: 7/7 core features per implementation
- **Build Success Rate**: 100%

---

## 🤝 Contributing

### Adding New Implementations

1. **Create Implementation Directory**: `implementations/<language>/`
2. **Required Files**: 
   - `Dockerfile` - Container build instructions
   - `Makefile` - Build automation
   - `chess.meta` - Implementation metadata
   - `README.md` - Implementation documentation
3. **Chess Engine**: Implement according to `CHESS_ENGINE_SPECS.md`
4. **Testing**: Workflows automatically detect and test new implementations

### Modifying Workflows

1. **Script Changes**: Modify individual scripts in `.github/workflows/scripts/`
2. **Workflow Updates**: Edit `bench.yaml` or `test.yaml` as needed
3. **Testing**: Use `./workflow` commands for local validation
4. **Documentation**: Update this `WORKFLOWS.md` file

### Debugging Workflows

- **Local Testing**: Use `./workflow` commands to reproduce issues
- **Logs Analysis**: Check GitHub Actions logs for detailed error information
- **Docker Debugging**: Test individual containers locally
- **Configuration Validation**: Verify `chess.meta` files and structure

---

## 🔗 Related Documentation

- **[Chess Engine Specification](../CHESS_ENGINE_SPECS.md)**: Complete engine interface requirements
- **[Implementation Guidelines](../README_IMPLEMENTATION_GUIDELINES.md)**: Best practices for new implementations
- **[Main README](../README.md)**: Project overview and current status
- **[Test Documentation](../test/README.md)**: Testing framework details

---

*This workflow system represents one of the most comprehensive multi-language chess engine testing frameworks, achieving 100% feature standardization across 17 different programming languages with automated quality assurance and performance benchmarking.*