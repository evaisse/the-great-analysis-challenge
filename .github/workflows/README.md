# GitHub Actions Workflows

This directory contains GitHub Actions workflows for automated testing and validation of all chess engine implementations.

## Available Workflows

### 🔨 `build-and-test.yml` - Complete Build and Test Pipeline
**Triggers:** Push to master/main, pull requests, manual dispatch

**What it does:**
- Builds Docker images for all chess engine implementations sequentially
- Runs basic functionality tests for each engine
- Measures compilation times and image sizes
- Provides comprehensive build summary
- Includes failure tolerance (continues even if one engine fails)

**Features:**
- Matrix strategy for parallel language testing
- Docker layer caching for faster builds
- Timeout protection (60 minutes total)
- Automatic cleanup of Docker images
- Build time benchmarking

### ⚡ `quick-build.yml` - Fast Build Verification
**Triggers:** File changes in source directories, manual dispatch

**What it does:**
- Performs quick build verification for all implementations
- Optimized for fast feedback on code changes
- Fails fast if any build is broken
- Minimal resource usage

**Use case:** Perfect for development workflow and quick validation

### 🧪 `chess-functionality-test.yml` - Deep Functionality Testing
**Triggers:** Push to master/main, pull requests, daily schedule (2 AM UTC), manual dispatch

**What it does:**
- Comprehensive functionality testing for each chess engine
- Tests core chess features:
  - Help and command system
  - Board display and FEN notation
  - Move generation (perft tests)
  - AI move calculation
  - Interactive gameplay
- Performance benchmarking with node-per-second metrics
- Validates chess engine correctness

**Test Categories:**
1. **Basic Functionality** - Help, board display, FEN export
2. **Move Generation** - Perft accuracy tests at depth 3-4
3. **AI Testing** - Computer move generation
4. **Interactive Features** - Human move input and validation
5. **Performance** - Speed benchmarks and node counting

## Workflow Status Badges

Add these badges to your main README to show build status:

```markdown
![Build and Test](https://github.com/yourusername/the-great-analysis-challenge/workflows/Build%20and%20Test%20All%20Chess%20Engines/badge.svg)
![Quick Build](https://github.com/yourusername/the-great-analysis-challenge/workflows/Quick%20Build%20Check/badge.svg)
![Functionality Tests](https://github.com/yourusername/the-great-analysis-challenge/workflows/Chess%20Functionality%20Tests/badge.svg)
```

## Language Support Matrix

| Language   | Build Test | Functionality Test | Perft Validation | AI Testing | Interactive Mode |
|------------|------------|-------------------|------------------|------------|-----------------|
| Rust       | ✅         | ✅                | ✅               | ✅         | ✅              |
| Go         | ✅         | ✅                | ✅               | ✅         | ✅              |
| Dart       | ✅         | ✅                | ✅               | ✅         | ✅              |
| TypeScript | ✅         | ✅                | ✅               | ✅         | ✅              |
| Kotlin     | ✅         | ✅                | ✅               | ✅         | ✅              |
| Crystal    | ✅         | ✅                | ✅               | ✅         | ✅              |
| Ruby       | ✅         | ✅                | ✅               | ✅         | ✅              |
| Julia      | ✅         | ✅                | ✅               | ✅         | ✅              |
| Haskell    | ✅         | ✅                | ✅               | ✅         | ✅              |
| Gleam      | ✅         | ✅                | ⏭️               | ⏭️         | ⏭️              |
| Elm        | ✅         | ✅                | ⏭️               | ⏭️         | ⏭️              |

*Note: Gleam and Elm have limited interactive testing due to their demo-mode implementations*

## Performance Benchmarking

The workflows automatically collect performance metrics:

- **Build Times**: Compilation speed for each language
- **Image Sizes**: Final Docker image sizes
- **Perft Performance**: Move generation speed (nodes per second)
- **AI Performance**: Search speed and evaluation time

Results are displayed in workflow logs and can be used to compare language performance characteristics.

## Running Workflows Manually

You can trigger workflows manually from the GitHub Actions tab:

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. Select the workflow you want to run
4. Click "Run workflow"
5. Choose the branch and any additional parameters

## Local Testing

To test locally before pushing:

```bash
# Test individual engine build
cd rust && docker build -t chess-rust-local .

# Test functionality
echo "help" | docker run --rm -i chess-rust-local
echo "perft 3" | docker run --rm -i chess-rust-local

# Cleanup
docker rmi chess-rust-local
```

## Troubleshooting

**Common Issues:**

1. **Docker Build Failures**: Check Dockerfile syntax and dependencies
2. **Timeout Issues**: Large builds may need timeout adjustments
3. **Memory Issues**: Some languages need more memory for compilation
4. **Interactive Test Failures**: Ensure engines accept stdin properly

**Debug Tips:**

- Check workflow logs for detailed error messages
- Test Docker builds locally first
- Verify all required files are committed
- Ensure Dockerfiles are in correct locations

## Contributing

When adding new chess engine implementations:

1. Ensure your Dockerfile builds successfully
2. Test basic commands work with stdin/stdout
3. Add your language to the workflow matrix if needed
4. Update this README with any special requirements