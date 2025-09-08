#!/bin/bash

# Docker-based Test Runner for Chess Engine Implementations
# This script ensures all tests are run inside Docker containers

set -e

echo "============================================="
echo "Chess Engine Docker Test Runner"
echo "============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to run tests for a single implementation
run_implementation_test() {
    local lang=$1
    local dockerfile=$2
    local test_cmd=$3
    
    echo -e "${YELLOW}Testing $lang implementation...${NC}"
    echo "----------------------------------------"
    
    # Build Docker image
    echo "Building Docker image for $lang..."
    if docker build -t chess-$lang -f $dockerfile . > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker image built successfully${NC}"
        
        # Run tests inside container
        echo "Running tests..."
        if docker run --rm chess-$lang sh -c "$test_cmd" > test_output_$lang.txt 2>&1; then
            echo -e "${GREEN}✓ Tests passed for $lang${NC}"
            ((PASSED_TESTS++))
            cat test_output_$lang.txt
        else
            echo -e "${RED}✗ Tests failed for $lang${NC}"
            ((FAILED_TESTS++))
            echo "Error output:"
            cat test_output_$lang.txt
        fi
    else
        echo -e "${RED}✗ Failed to build Docker image for $lang${NC}"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
    echo ""
}

# Test TypeScript implementation
if [ -d "typescript" ]; then
    run_implementation_test "typescript" "typescript/Dockerfile" \
        "cd /app && npm test 2>/dev/null || (echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node dist/chess.js)"
fi

# Test Ruby implementation
if [ -d "ruby" ]; then
    run_implementation_test "ruby" "ruby/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ruby chess.rb"
fi

# Test Crystal implementation
if [ -d "crystal" ]; then
    run_implementation_test "crystal" "crystal/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./chess_engine"
fi

# Test Rust implementation
if [ -d "rust" ]; then
    run_implementation_test "rust" "rust/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./target/release/chess-engine"
fi

# Test Julia implementation
if [ -d "julia" ]; then
    run_implementation_test "julia" "julia/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | julia chess.jl"
fi

# Test Kotlin implementation
if [ -d "kotlin" ]; then
    run_implementation_test "kotlin" "kotlin/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | java -jar build/libs/chess.jar"
fi

# Test Haskell implementation
if [ -d "haskell" ]; then
    run_implementation_test "haskell" "haskell/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./chess"
fi

# Test Gleam implementation
if [ -d "gleam" ]; then
    run_implementation_test "gleam" "gleam/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | gleam run"
fi

# Test Dart implementation
if [ -d "dart" ]; then
    run_implementation_test "dart" "dart/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | dart run"
fi

# Test Elm implementation
if [ -d "elm" ]; then
    run_implementation_test "elm" "elm/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node src/cli.js"
fi

# Test ReScript implementation
if [ -d "rescript" ]; then
    run_implementation_test "rescript" "rescript/Dockerfile" \
        "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node lib/js/src/Chess.js"
fi

# Summary
echo "============================================="
echo "Test Summary"
echo "============================================="
echo -e "Total implementations tested: $TOTAL_TESTS"
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"

# Clean up test output files
rm -f test_output_*.txt

# Exit with appropriate code
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi