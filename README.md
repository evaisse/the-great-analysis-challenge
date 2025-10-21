This is a project that builds a sample chess engine in many different languages to implement the exact same application and compare their approaches.

# The Game

The game specs are defined in [./CHESS_ENGINE_SPECS.md](./CHESS_ENGINE_SPECS.md)

# Language Implementations

Each application is implemented in a different language, showcasing their unique strengths and paradigms:

## Available Languages

### 🦀 **Rust** (`./implementations/rust/`)
**Paradigm**: Systems programming with memory safety  
**Key Features**: Zero-cost abstractions, ownership system, pattern matching  
**Compile Command**: `cd implementations/rust && cargo build --release`  
**Build Time**: ~30-60 seconds (first build), ~5-10 seconds (incremental)

### 💎 **Ruby** (`./implementations/ruby/`)
**Paradigm**: Object-oriented with dynamic typing  
**Key Features**: Duck typing, blocks/iterators, metaprogramming, elegant syntax  
**Run Command**: `cd implementations/ruby && ruby chess.rb`  
**Build Time**: Interpreted (no compilation), ~100-200ms startup
**Static Analysis**: RuboCop with performance checks

### 🐹 **Go** (`./implementations/go/`)  
**Paradigm**: Simple, concurrent, compiled  
**Key Features**: Goroutines, channels, fast compilation  
**Compile Command**: `cd implementations/go && go build ./cmd/chess`  
**Build Time**: ~2-5 seconds

### 🎯 **Dart** (`./implementations/dart/`)
**Paradigm**: Object-oriented, null-safe  
**Key Features**: Strong typing, async/await, Flutter ecosystem  
**Compile Command**: `cd implementations/dart && dart compile exe bin/main.dart`  
**Build Time**: ~5-10 seconds

### 🟦 **TypeScript** (`./implementations/typescript/`)
**Paradigm**: JavaScript with static typing  
**Key Features**: Type safety, modern ES features, large ecosystem  
**Compile Command**: `cd implementations/typescript && npm run build`  
**Build Time**: ~10-15 seconds

### 🔥 **Gleam** (`./implementations/gleam/`)
**Paradigm**: Functional programming on the BEAM VM  
**Key Features**: Type safety, immutability, pattern matching, fault tolerance  
**Compile Command**: `cd implementations/gleam && gleam build`  
**Build Time**: ~5-10 seconds

### 🏗️ **Kotlin** (`./implementations/kotlin/`)
**Paradigm**: Modern JVM language combining OOP and functional  
**Key Features**: Null safety, data classes, coroutines, Java interop  
**Compile Command**: `cd implementations/kotlin && ./gradlew build`  
**Build Time**: ~15-30 seconds (first build), ~5-10 seconds (incremental)

### 💎 **Crystal** (`./implementations/crystal/`)
**Paradigm**: Ruby-like syntax with compile-time type safety  
**Key Features**: Zero-cost abstractions, type inference, union types, static compilation  
**Compile Command**: `cd implementations/crystal && crystal build src/chess_engine.cr --release`  
**Build Time**: ~10-20 seconds

### ⚡ **Zig** (`./implementations/zig/`)
**Paradigm**: Systems programming with simplicity and performance focus  
**Key Features**: Comptime execution, manual memory management with safety, cross-compilation  
**Compile Command**: `cd implementations/zig && zig build -Doptimize=ReleaseFast`  
**Build Time**: ~5-15 seconds

### 🔥 **Mojo** (`./implementations/mojo/`)
**Paradigm**: Python-compatible systems programming with performance focus  
**Key Features**: Zero-cost abstractions, value semantics, compile-time safety, Python interop  
**Compile Command**: `cd implementations/mojo && mojo chess.mojo`  
**Build Time**: ~2-5 seconds (when Mojo runtime available)
**Status**: Demo implementation (full source ready for Mojo runtime)

## Compilation Speed Comparison

To benchmark compilation speeds across all implementations:

```bash
# Rust (systems programming)
time (cd implementations/rust && cargo build --release)

# Ruby (interpreted, dynamic)
time (cd implementations/ruby && ruby -c chess.rb)

# Go (fast compilation focus)  
time (cd implementations/go && go build ./cmd/chess)

# Dart (compiled native executables)
time (cd implementations/dart && dart compile exe bin/main.dart)

# TypeScript (transpiled to JavaScript)
time (cd implementations/typescript && npm run build)

# Gleam (functional on BEAM VM)
time (cd implementations/gleam && gleam build)

# Ruby (interpreted language)
time (cd implementations/ruby && ruby -c chess.rb && echo "Syntax check passed - no compilation needed")

# Kotlin (JVM compilation)
time (cd implementations/kotlin && ./gradlew build --no-daemon)

# Crystal (compiled with type safety)
time (cd implementations/crystal && crystal build src/chess_engine.cr --release)

# Zig (systems programming with simplicity)
time (cd implementations/zig && zig build -Doptimize=ReleaseFast)

# Mojo (Python-compatible systems programming)
time (cd implementations/mojo && mojo chess.mojo)  # When Mojo runtime is available
```

## Docker Build & Run

Each implementation includes Docker support for consistent builds:

```bash
# Build and run any implementation
cd <language-directory>
docker build -t chess-<language> .
docker run -it chess-<language>
```

## Performance Notes

- **Go**: Fastest compilation, designed for rapid development cycles
- **Ruby**: No compilation needed (interpreted), fastest development iteration
- **Dart**: Fast compilation with native code generation  
- **Gleam**: Quick builds with excellent error messages
- **Crystal**: Fast compilation with Ruby-like syntax and native performance
- **Zig**: Very fast compilation with excellent performance and cross-compilation support
- **Mojo**: Very fast compilation with Python compatibility and native performance
- **TypeScript**: Moderate speed, depends on project size and dependencies
- **Kotlin**: Moderate speed, benefits from Gradle's incremental compilation
- **Rust**: Slowest compilation but produces highly optimized binaries

For each folder, you get a Dockerfile that allows you to analyze and build these projects from scratch without struggling with dependencies.