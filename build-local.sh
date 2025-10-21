#!/bin/bash

# Script de construction locale pour tester sans Docker
# Local build script to test without Docker

set -e

echo "🏗️  Testing local builds of chess implementations..."
echo "===================================================="

IMPLEMENTATIONS_DIR="./implementations"
BUILD_LOG="build_results.log"

# Create build results directory
mkdir -p build_results
echo "Build started at $(date)" > "$BUILD_LOG"

# Function to test build in directory
test_build() {
    local lang=$1
    local dir="$IMPLEMENTATIONS_DIR/$lang"
    
    echo "🔍 Testing $lang implementation..."
    
    if [ ! -d "$dir" ]; then
        echo "❌ Directory $dir not found"
        return 1
    fi
    
    cd "$dir"
    
    case $lang in
        go)
            if command -v go >/dev/null 2>&1; then
                go build -o chess_engine chess.go && echo "✅ Go build success" || echo "❌ Go build failed"
            else
                echo "⚠️  Go not installed"
            fi
            ;;
        python)
            if command -v python3 >/dev/null 2>&1; then
                python3 -m py_compile chess.py && echo "✅ Python syntax check success" || echo "❌ Python syntax check failed"
            else
                echo "⚠️  Python3 not installed"
            fi
            ;;
        typescript)
            if command -v npm >/dev/null 2>&1; then
                npm install && npm run build && echo "✅ TypeScript build success" || echo "❌ TypeScript build failed"
            else
                echo "⚠️  npm not installed"
            fi
            ;;
        rust)
            if command -v cargo >/dev/null 2>&1; then
                cargo build --release && echo "✅ Rust build success" || echo "❌ Rust build failed"
            else
                echo "⚠️  Cargo not installed"
            fi
            ;;
        ruby)
            if command -v ruby >/dev/null 2>&1; then
                ruby -c chess.rb && echo "✅ Ruby syntax check success" || echo "❌ Ruby syntax check failed"
            else
                echo "⚠️  Ruby not installed"
            fi
            ;;
        nim)
            if command -v nim >/dev/null 2>&1; then
                nim compile --opt:speed -o:chess_engine chess.nim && echo "✅ Nim build success" || echo "❌ Nim build failed"
            else
                echo "⚠️  Nim not installed"
            fi
            ;;
        crystal)
            if command -v crystal >/dev/null 2>&1; then
                crystal build src/chess_engine.cr --release -o chess_engine && echo "✅ Crystal build success" || echo "❌ Crystal build failed"
            else
                echo "⚠️  Crystal not installed"
            fi
            ;;
        dart)
            if command -v dart >/dev/null 2>&1; then
                dart compile exe bin/chess_engine.dart -o chess_engine && echo "✅ Dart build success" || echo "❌ Dart build failed"
            else
                echo "⚠️  Dart not installed"
            fi
            ;;
        kotlin)
            if command -v gradle >/dev/null 2>&1; then
                gradle build && echo "✅ Kotlin build success" || echo "❌ Kotlin build failed"
            else
                echo "⚠️  Gradle not installed"
            fi
            ;;
        swift)
            if command -v swift >/dev/null 2>&1; then
                swift build -c release && echo "✅ Swift build success" || echo "❌ Swift build failed"
            else
                echo "⚠️  Swift not installed"
            fi
            ;;
        haskell)
            if command -v cabal >/dev/null 2>&1; then
                cabal build && echo "✅ Haskell build success" || echo "❌ Haskell build failed"
            else
                echo "⚠️  Cabal not installed"
            fi
            ;;
        julia)
            if command -v julia >/dev/null 2>&1; then
                julia -e 'using Pkg; Pkg.instantiate()' && echo "✅ Julia deps success" || echo "❌ Julia deps failed"
            else
                echo "⚠️  Julia not installed"
            fi
            ;;
        zig)
            if command -v zig >/dev/null 2>&1; then
                zig build && echo "✅ Zig build success" || echo "❌ Zig build failed"
            else
                echo "⚠️  Zig not installed"
            fi
            ;;
        gleam)
            if command -v gleam >/dev/null 2>&1; then
                gleam build && echo "✅ Gleam build success" || echo "❌ Gleam build failed"
            else
                echo "⚠️  Gleam not installed"
            fi
            ;;
        elm)
            if command -v elm >/dev/null 2>&1; then
                elm make src/ChessEngine.elm --output=chess_engine.js && echo "✅ Elm build success" || echo "❌ Elm build failed"
            else
                echo "⚠️  Elm not installed"
            fi
            ;;
        *)
            echo "❓ Unknown language: $lang"
            ;;
    esac
    
    cd - >/dev/null
    echo ""
}

# Test all available implementations
echo "Scanning for implementations..."

LANGUAGES=(
    crystal dart elm gleam go haskell julia kotlin
    mojo nim python rescript ruby rust swift typescript zig
)

for lang in "${LANGUAGES[@]}"; do
    test_build "$lang" 2>&1 | tee -a "$BUILD_LOG"
done

echo "🏁 Build testing complete!"
echo "📊 Results logged to: $BUILD_LOG"
echo ""
echo "💡 To use the unified Docker container:"
echo "   docker build -t chess-engines ."
echo "   docker run --rm chess-engines"
echo ""
echo "💡 To test individual implementations:"
echo "   docker-compose up crystal-chess"
echo "   docker-compose up go-chess"
echo "   etc..."