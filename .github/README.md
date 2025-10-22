# GitHub Actions Workflows

This directory contains automated workflows for the Chess Engine Implementations project.

## 🚀 `benchmark-and-release.yml` - Automated Benchmark Suite & Release Workflow

### Purpose
Automatically runs comprehensive performance benchmarks on all chess engine implementations, updates the README status table, commits changes, and creates versioned releases.

### Triggers

1. **Manual Trigger** (`workflow_dispatch`):
   - Can be triggered manually from GitHub Actions tab
   - Allows selection of version bump type (patch/minor/major)
   - Useful for immediate testing or custom releases

2. **Scheduled Execution**:
   - Runs every Sunday at 6:00 AM UTC
   - Provides weekly status updates
   - Ensures README stays current with implementation changes

3. **Automatic on Changes**:
   - Triggers on pushes to master branch
   - Only when changes affect implementations/ or test/ directories
   - Ensures status table reflects latest code changes

### Workflow Overview

The workflow performs these key steps:

1. **Environment Setup** - Installs Python, Docker, and language runtimes
2. **Structure Verification** - Validates implementation compliance
3. **Performance Benchmarking** - Runs comprehensive test suite
4. **README Update** - Updates status table with latest results
5. **Version Management** - Determines appropriate version bump
6. **Release Creation** - Creates tagged release with artifacts

### Key Features

#### 📊 Comprehensive Testing
- Cache clearing with `make clean`
- Static analysis timing (`make analyze`)
- Build performance (`make build`)
- Chess protocol compliance testing
- Docker container validation
- Memory usage monitoring

#### 🔄 Automated Updates
- README status table refresh
- Performance metrics update
- Implementation status classification
- Timestamp tracking

#### 🏷️ Smart Versioning
- Semantic version management (patch/minor/major)
- Auto-determined version bumps based on implementation health
- Manual override capability

#### 📦 Release Management
- Automated GitHub releases
- Comprehensive release notes
- Benchmark report artifacts
- Implementation status summaries

### Configuration

#### Environment Variables
```yaml
BENCHMARK_TIMEOUT: 3600    # 1 hour execution limit
PYTHON_VERSION: '3.11'     # Python runtime version
```

#### Triggers Configuration
```yaml
# Manual trigger with version selection
workflow_dispatch:
  inputs:
    version_type: [patch, minor, major]

# Weekly automated run
schedule:
  - cron: '0 6 * * 0'  # Sunday 6 AM UTC

# Auto-trigger on implementation changes
push:
  paths: ['implementations/**', 'test/**']
```

### Outputs

#### 1. Updated README.md
- Fresh implementation status table
- Current performance benchmarks
- Build and analysis timing data
- Status classifications (Excellent/Good/Needs Work)

#### 2. Benchmark Artifacts
- **performance_report.txt**: Detailed human-readable report
- **performance_data.json**: Machine-readable metrics
- **verification_results.txt**: Structure compliance data
- **benchmark_summary.txt**: Key statistics

#### 3. Versioned Release
- Semantic version tag (e.g., v1.2.3)
- Release notes with implementation status
- Artifact download links
- Next steps for problematic implementations

### Usage

#### Manual Execution
1. Navigate to repository → Actions tab
2. Select "Benchmark Suite & Release" workflow
3. Click "Run workflow"
4. Choose version bump type (patch/minor/major)
5. Execute workflow

#### Automated Execution
- Runs weekly on Sundays at 6 AM UTC
- Triggers automatically on implementation changes
- Provides continuous status monitoring

#### View Results
- Check latest release for implementation status
- Download benchmark artifacts for detailed analysis
- Review updated README status table

### Performance Metrics

The workflow tracks these key performance indicators:

- **Build Time**: Compilation/build duration for each implementation
- **Analysis Time**: Static analysis and linting execution time
- **Memory Usage**: Peak and average memory consumption
- **Chess Compliance**: Protocol adherence test results
- **Docker Performance**: Container build and execution timing
- **Overall Health**: Implementation status classification

### Version Management

#### Automatic Version Bumping
- **Patch**: Default for regular updates
- **Minor**: When >10 excellent implementations and 0 need work
- **Major**: Manual selection only

#### Version Determination Logic
```bash
# Current version from git tags
CURRENT_VERSION=$(git tag --sort=-version:refname | head -1)

# Smart bump type selection
if [[ $NEEDS_WORK_COUNT -eq 0 && $EXCELLENT_COUNT -gt 10 ]]; then
  VERSION_TYPE="minor"
else
  VERSION_TYPE="patch"
fi
```

### Integration Benefits

#### Continuous Quality Assurance
- Weekly implementation health monitoring
- Immediate feedback on changes
- Performance regression detection
- Build health tracking

#### Development Workflow
- Automated status updates
- Consistent benchmarking
- Historical progress tracking
- Quality gate enforcement

#### Release Management
- Automated changelog generation
- Semantic versioning compliance
- Artifact preservation
- Status communication

### Troubleshooting

#### Common Issues
- **Timeout Errors**: Adjust BENCHMARK_TIMEOUT or optimize builds
- **Language Installation**: Check package availability and URLs
- **README Updates**: Verify table format and git permissions
- **Version Conflicts**: Review existing tags and conventions

#### Debugging Steps
1. Review workflow execution logs in GitHub Actions
2. Download benchmark artifacts for detailed error analysis
3. Test individual components locally using test scripts
4. Manually verify problematic implementations

This workflow ensures the project maintains current, accurate implementation status while providing automated quality assurance and release management.