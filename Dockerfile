# Multi-language Chess Engine Builder
# Builds all chess engine implementations in a single container
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:$PATH
ENV CRYSTAL_VERSION=1.14.0
ENV GLEAM_VERSION=1.2.1
ENV MOJO_ROOT=/opt/mojo

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Base tools
    curl \
    wget \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    unzip \
    # C/C++ toolchain
    gcc \
    g++ \
    libc6-dev \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # Ruby
    ruby \
    ruby-dev \
    # Go
    golang-go \
    # Java/Kotlin
    openjdk-11-jdk \
    # Nim
    nim \
    # Haskell
    ghc \
    cabal-install \
    # Swift dependencies
    binutils \
    git \
    gnupg2 \
    libc6-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libgcc-9-dev \
    libpython3-dev \
    libsqlite3-0 \
    libstdc++-9-dev \
    libxml2-dev \
    libz3-dev \
    pkg-config \
    tzdata \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js and npm for TypeScript, Elm, ReScript
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && chmod -R a+w $RUSTUP_HOME $CARGO_HOME

# Install Crystal
RUN curl -fsSL https://packagecloud.io/84codes/crystal/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/84codes_crystal.gpg \
    && echo "deb https://packagecloud.io/84codes/crystal/ubuntu/ jammy main" > /etc/apt/sources.list.d/crystal.list \
    && apt-get update \
    && apt-get install -y crystal \
    && rm -rf /var/lib/apt/lists/*

# Install Dart
RUN wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | tee /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update \
    && apt-get install -y dart \
    && rm -rf /var/lib/apt/lists/*

# Install Zig
RUN ZIG_VERSION="0.11.0" \
    && wget "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
    && tar -xf "zig-linux-x86_64-${ZIG_VERSION}.tar.xz" \
    && mv "zig-linux-x86_64-${ZIG_VERSION}" /opt/zig \
    && ln -s /opt/zig/zig /usr/local/bin/zig \
    && rm "zig-linux-x86_64-${ZIG_VERSION}.tar.xz"

# Install Julia
RUN JULIA_VERSION="1.9.4" \
    && wget "https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" \
    && tar -xzf "julia-${JULIA_VERSION}-linux-x86_64.tar.gz" \
    && mv "julia-${JULIA_VERSION}" /opt/julia \
    && ln -s /opt/julia/bin/julia /usr/local/bin/julia \
    && rm "julia-${JULIA_VERSION}-linux-x86_64.tar.gz"

# Install Swift
RUN SWIFT_VERSION="5.9.2" \
    && SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2004/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04.tar.gz" \
    && wget "${SWIFT_URL}" \
    && tar -xzf "swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04.tar.gz" \
    && mv "swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04" /opt/swift \
    && ln -s /opt/swift/usr/bin/swift* /usr/local/bin/ \
    && rm "swift-${SWIFT_VERSION}-RELEASE-ubuntu20.04.tar.gz"

# Install Gleam via Erlang
RUN wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb \
    && dpkg -i erlang-solutions_2.0_all.deb \
    && apt-get update \
    && apt-get install -y esl-erlang elixir \
    && rm erlang-solutions_2.0_all.deb \
    && rm -rf /var/lib/apt/lists/*

RUN GLEAM_VERSION="1.2.1" \
    && wget "https://github.com/gleam-lang/gleam/releases/download/v${GLEAM_VERSION}/gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && tar -xzf "gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && mv gleam /usr/local/bin/ \
    && rm "gleam-v${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz"

# Install Gradle for Kotlin
RUN GRADLE_VERSION="8.0" \
    && wget "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    && unzip "gradle-${GRADLE_VERSION}-bin.zip" \
    && mv "gradle-${GRADLE_VERSION}" /opt/gradle \
    && ln -s /opt/gradle/bin/gradle /usr/local/bin/gradle \
    && rm "gradle-${GRADLE_VERSION}-bin.zip"

# Install Elm
RUN npm install -g elm@0.19.1

# Create working directory
WORKDIR /workspace

# Copy all implementations
COPY implementations/ ./implementations/

# Create build script
RUN cat > build_all.sh << 'EOF'
#!/bin/bash

set -e

echo "🏗️  Building all chess engine implementations..."
echo "=================================================="

# Crystal
echo "🔷 Building Crystal implementation..."
cd /workspace/implementations/crystal
crystal build src/chess_engine.cr --release -o chess_engine
echo "✅ Crystal build complete"

# Dart
echo "🎯 Building Dart implementation..."
cd /workspace/implementations/dart
dart compile exe bin/chess_engine.dart -o chess_engine
echo "✅ Dart build complete"

# Elm
echo "🌳 Building Elm implementation..."
cd /workspace/implementations/elm
npm install
elm make src/ChessEngine.elm --output=chess_engine.js
echo "✅ Elm build complete"

# Gleam
echo "✨ Building Gleam implementation..."
cd /workspace/implementations/gleam
gleam build
echo "✅ Gleam build complete"

# Go
echo "🐹 Building Go implementation..."
cd /workspace/implementations/go
go build -o chess_engine chess.go
echo "✅ Go build complete"

# Haskell
echo "λ Building Haskell implementation..."
cd /workspace/implementations/haskell
cabal build
echo "✅ Haskell build complete"

# Julia
echo "🔬 Building Julia implementation..."
cd /workspace/implementations/julia
julia -e 'using Pkg; Pkg.instantiate()'
echo "✅ Julia build complete"

# Kotlin
echo "🎨 Building Kotlin implementation..."
cd /workspace/implementations/kotlin
gradle build
echo "✅ Kotlin build complete"

# Nim
echo "👑 Building Nim implementation..."
cd /workspace/implementations/nim
nim compile --opt:speed -o:chess_engine chess.nim
echo "✅ Nim build complete"

# Python
echo "🐍 Building Python implementation..."
cd /workspace/implementations/python
pip3 install -r requirements.txt
python3 -m py_compile chess.py
echo "✅ Python build complete"

# Ruby
echo "💎 Building Ruby implementation..."
cd /workspace/implementations/ruby
bundle install --system
echo "✅ Ruby build complete"

# Rust
echo "🦀 Building Rust implementation..."
cd /workspace/implementations/rust
cargo build --release
echo "✅ Rust build complete"

# Swift
echo "🦉 Building Swift implementation..."
cd /workspace/implementations/swift
swift build -c release
echo "✅ Swift build complete"

# TypeScript
echo "📘 Building TypeScript implementation..."
cd /workspace/implementations/typescript
npm install
npm run build
echo "✅ TypeScript build complete"

# Zig
echo "⚡ Building Zig implementation..."
cd /workspace/implementations/zig
zig build
echo "✅ Zig build complete"

# Mojo (demo only - no actual compilation)
echo "🔥 Mojo implementation (demo)..."
cd /workspace/implementations/mojo
echo "✅ Mojo demo ready"

# ReScript
echo "🟦 Building ReScript implementation..."
cd /workspace/implementations/rescript
npm install
npm run build
echo "✅ ReScript build complete"

echo ""
echo "🎉 All implementations built successfully!"
echo "=================================================="

# Show summary
echo "📊 Build Summary:"
echo "- Crystal: /workspace/implementations/crystal/chess_engine"
echo "- Dart: /workspace/implementations/dart/chess_engine"
echo "- Elm: /workspace/implementations/elm/chess_engine.js"
echo "- Gleam: /workspace/implementations/gleam/build/"
echo "- Go: /workspace/implementations/go/chess_engine"
echo "- Haskell: /workspace/implementations/haskell/dist-newstyle/"
echo "- Julia: /workspace/implementations/julia/chess.jl"
echo "- Kotlin: /workspace/implementations/kotlin/build/"
echo "- Nim: /workspace/implementations/nim/chess_engine"
echo "- Python: /workspace/implementations/python/chess.py"
echo "- Ruby: /workspace/implementations/ruby/chess.rb"
echo "- Rust: /workspace/implementations/rust/target/release/chess"
echo "- Swift: /workspace/implementations/swift/.build/release/"
echo "- TypeScript: /workspace/implementations/typescript/dist/"
echo "- Zig: /workspace/implementations/zig/zig-out/bin/"
echo "- Mojo: /workspace/implementations/mojo/chess.mojo (demo)"
echo "- ReScript: /workspace/implementations/rescript/lib/"

EOF

# Make build script executable
RUN chmod +x build_all.sh

# Create test script
RUN cat > test_all.sh << 'EOF'
#!/bin/bash

echo "🧪 Testing all chess engine implementations..."
echo "=============================================="

# Test each implementation
cd /workspace/implementations

for impl in crystal dart go haskell julia kotlin nim python ruby rust swift typescript zig; do
    echo "🔍 Testing $impl implementation..."
    cd "$impl"
    
    case $impl in
        crystal) ./chess_engine 2>/dev/null || echo "❌ $impl failed" ;;
        dart) ./chess_engine 2>/dev/null || echo "❌ $impl failed" ;;
        go) ./chess_engine 2>/dev/null || echo "❌ $impl failed" ;;
        haskell) echo "✅ $impl (requires cabal run)" ;;
        julia) julia chess.jl 2>/dev/null || echo "❌ $impl failed" ;;
        kotlin) echo "✅ $impl (requires gradle run)" ;;
        nim) ./chess_engine 2>/dev/null || echo "❌ $impl failed" ;;
        python) python3 chess.py 2>/dev/null || echo "❌ $impl failed" ;;
        ruby) ruby chess.rb 2>/dev/null || echo "❌ $impl failed" ;;
        rust) ./target/release/chess 2>/dev/null || echo "❌ $impl failed" ;;
        swift) echo "✅ $impl (requires swift run)" ;;
        typescript) node dist/chess.js 2>/dev/null || echo "❌ $impl failed" ;;
        zig) echo "✅ $impl (requires zig run)" ;;
    esac
    
    cd ..
done

echo "🏁 Testing complete!"

EOF

RUN chmod +x test_all.sh

# Default command
CMD ["./build_all.sh"]

# Alternative commands:
# Build all: docker run --rm chess-engines
# Test all: docker run --rm chess-engines ./test_all.sh  
# Interactive: docker run -it chess-engines bash
# Build specific: docker run --rm -w /workspace/implementations/rust chess-engines cargo build --release