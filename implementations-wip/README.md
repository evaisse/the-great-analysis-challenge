# Work In Progress (WIP) Implementations

This directory contains chess engine implementations that are currently not fully working or have build issues that prevent them from producing benchmark timing results.

## Testing Requirements

The benchmark testing infrastructure runs `make analyze`, `make build`, and `make test` directly on the host machine (not in Docker) to measure compilation times and performance. Implementations in this directory fail to produce timing results because they cannot build/test on the host environment.

## Implementations

### Crystal (`crystal`)

**Issue:** Compiler not available on host machine.
- The Crystal compiler is not installed on the GitHub Actions runner or typical development machines.
- Build fails with: `make: crystal: No such file or directory`
- **Fix required:** Either install Crystal on the host, or modify the testing infrastructure to support Docker-only implementations.

### Gleam (`gleam`)

**Issue:** Compiler not available on host machine.
- The Gleam compiler is not installed on the GitHub Actions runner.
- Build fails with: `make: gleam: command not found`
- **Fix required:** Either install Gleam on the host, or modify the testing infrastructure to support Docker-only implementations.

### Elm (`elm`)

**Issue:** Compiler not available on host machine + type errors in code.
- The Elm compiler is not installed on the GitHub Actions runner.
- Additionally, the code has type mismatch errors in `src/MoveGenerator.elm` (line 477).
- Build fails with type error: `The 2nd argument to setPiece is not what I expect`
- **Fix required:** Install Elm on the host and fix the type mismatch in the setPiece function call.

### Haskell (`haskell`)

**Issue:** Network connectivity issues downloading packages.
- While `cabal` is installed on the host, it fails to download packages from Hackage.
- Build fails with: `Error: cabal: curl: (6) Could not resolve host: objects-us-east-1.dream.io`
- **Fix required:** Fix network configuration or use a different package mirror, or test in Docker where network is more reliable.

### Julia (`julia`)

**Issue:** Slow package installation prevents timing measurement.
- Julia is installed on the host, but `Pkg.instantiate()` takes a very long time to download and precompile packages.
- This makes it difficult to measure accurate build timings.
- **Fix required:** Pre-install Julia packages or use a local package cache, or test in Docker with packages pre-baked in the image.

### Kotlin (`kotlin`)

**Issue:** Gradle wrapper issue with macOS-specific JVM options.
- Java and Kotlin are installed on the host.
- The `gradlew` script contains macOS-specific JVM options (`-Xdock:name`) that fail on Linux.
- Build fails with: `Error: Could not find or load main class "-Xdock:name=Gradle"`
- **Fix required:** Make the gradlew script detect the OS and only set macOS-specific options on macOS, or use a standard Gradle wrapper.

### Mojo (`mojo`)

**Issue:** Compiler not available on host machine + Docker test failures.
- The Mojo compiler is not installed on the GitHub Actions runner.
- Even in Docker, tests fail with: `timeout: failed to run command 'make': No such file or directory`
- **Fix required:** Install Mojo on the host and fix the Docker container to include make and other required tools.

### Nim (`nim`)

**Issue:** Compiler not available on host machine.
- The Nim compiler is not installed on the GitHub Actions runner.
- Build fails with: `make: nim: No such file or directory`
- **Fix required:** Either install Nim on the host, or modify the testing infrastructure to support Docker-only implementations.

### ReScript (`rescript`)

**Issue:** Compiler not available on host machine + deprecated config.
- The ReScript compiler is not installed on the GitHub Actions runner.
- Additionally, the `bsconfig.json` uses deprecated "es6" module format (should be "esmodule").
- Build fails with: `sh: rescript: command not found` and deprecated config warning.
- **Fix required:** Install ReScript on the host (via npm) and update bsconfig.json to use "esmodule" instead of "es6".

### Zig (`zig`)

**Issue:** Compiler not available on host machine.
- The Zig compiler is not installed on the GitHub Actions runner.
- Build fails with: `make: zig: No such file or directory`
- **Fix required:** Either install Zig on the host, or modify the testing infrastructure to support Docker-only implementations.

### Go (`go`)

**Issue:** Build structure mismatch.
- The implementation defines `package main` in both the root `chess.go` and files in `src/`.
- The `Makefile` runs `go build -o chess .`, which ignores the files in `src/` because they are in a subdirectory.
- In Go, a package cannot be split across directories in this manner without importing.
- **Fix required:** Either move all source files to the root, or restructure `src/` as a proper library package and import it in `chess.go`.

### Swift (`swift`)

**Issue:** Folder structure mismatch.
- The `Package.swift` defines an executable target `Chess` without specifying a path. By convention, Swift Package Manager looks for sources in `Sources/Chess`.
- The source files are located in `src/`.
- `swift build` fails to find the source files.
- **Fix required:** Move `src/main.swift` (and other files) to `Sources/Chess/`, or update `Package.swift` to point to `src`.

## Contributing

To move an implementation back to the main `implementations/` directory:

1. Fix the identified issues
2. Verify that `make analyze`, `make build`, and `make test` work on the host machine
3. Verify that timing results are produced correctly
4. Run the performance test: `python3 test/performance_test.py --impl implementations-wip/<language>`
5. If all tests pass and timing results are generated, move it back to `implementations/`
