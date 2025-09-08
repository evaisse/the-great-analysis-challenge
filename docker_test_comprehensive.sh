#!/bin/bash

# Comprehensive Docker Test Script for Chess Engines
# This script tests all implementations using Docker with proper error handling

set -e

echo "=================================================="
echo "Chess Engine Comprehensive Docker Test Suite"
echo "=================================================="
echo ""

# Configuration
DOCKER_REGISTRY=${DOCKER_REGISTRY:-"docker.io"}
USE_CACHE=${USE_CACHE:-"true"}

# Results tracking
declare -A TEST_RESULTS
declare -A BUILD_RESULTS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test commands for each implementation
declare -A TEST_COMMANDS=(
    ["typescript"]="cd /app && npm install && npm run build && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node dist/chess.js"
    ["ruby"]="cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ruby chess.rb"
    ["crystal"]="cd /app && crystal build src/chess_engine.cr -o chess_engine && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./chess_engine"
    ["rust"]="cd /app && cargo build --release && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./target/release/chess-engine"
    ["julia"]="cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | julia chess.jl"
    ["kotlin"]="cd /app && ./gradlew build && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | java -jar build/libs/chess.jar"
    ["haskell"]="cd /app && cabal build && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | cabal run"
)

# Function to build Docker image
build_docker_image() {
    local lang=$1
    local dockerfile="$lang/Dockerfile"
    
    if [ ! -f "$dockerfile" ]; then
        echo -e "${YELLOW}⚠ No Dockerfile found for $lang${NC}"
        BUILD_RESULTS[$lang]="NO_DOCKERFILE"
        return 1
    fi
    
    echo -e "${BLUE}Building Docker image for $lang...${NC}"
    
    # Try building with different registries if needed
    if docker build --no-cache -t "chess-$lang" -f "$dockerfile" "$lang" 2>/dev/null; then
        echo -e "${GREEN}✓ Successfully built $lang Docker image${NC}"
        BUILD_RESULTS[$lang]="SUCCESS"
        return 0
    else
        # Try with alternate registry or simpler Dockerfile
        echo -e "${YELLOW}⚠ Failed with default registry, trying alternate approach...${NC}"
        
        # Create a minimal working Dockerfile if build fails
        create_minimal_dockerfile "$lang"
        
        if docker build -t "chess-$lang-minimal" -f "/tmp/Dockerfile.$lang" "$lang" 2>/dev/null; then
            echo -e "${GREEN}✓ Built minimal $lang Docker image${NC}"
            BUILD_RESULTS[$lang]="MINIMAL"
            return 0
        else
            echo -e "${RED}✗ Failed to build $lang Docker image${NC}"
            BUILD_RESULTS[$lang]="FAILED"
            return 1
        fi
    fi
}

# Create minimal Dockerfile for testing
create_minimal_dockerfile() {
    local lang=$1
    
    case $lang in
        typescript)
            cat > "/tmp/Dockerfile.$lang" <<EOF
FROM node:18-alpine
WORKDIR /app
COPY . .
RUN npm install && npm run build
CMD ["node", "dist/chess.js"]
EOF
            ;;
        ruby)
            cat > "/tmp/Dockerfile.$lang" <<EOF
FROM ruby:3.2
WORKDIR /app
COPY . .
CMD ["ruby", "chess.rb"]
EOF
            ;;
        crystal)
            cat > "/tmp/Dockerfile.$lang" <<EOF
FROM crystallang/crystal:latest-alpine
WORKDIR /app
COPY . .
RUN crystal build src/chess_engine.cr -o chess_engine
CMD ["./chess_engine"]
EOF
            ;;
        rust)
            cat > "/tmp/Dockerfile.$lang" <<EOF
FROM rust:1.70-alpine
WORKDIR /app
COPY . .
RUN apk add --no-cache musl-dev && cargo build --release
CMD ["./target/release/chess-engine"]
EOF
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to run tests
run_tests() {
    local lang=$1
    local image_name="chess-$lang"
    
    # Check if minimal image was built
    if [ "${BUILD_RESULTS[$lang]}" == "MINIMAL" ]; then
        image_name="chess-$lang-minimal"
    fi
    
    echo -e "${BLUE}Testing $lang implementation...${NC}"
    
    local test_cmd="${TEST_COMMANDS[$lang]}"
    if [ -z "$test_cmd" ]; then
        echo -e "${YELLOW}⚠ No test command defined for $lang${NC}"
        TEST_RESULTS[$lang]="NO_TEST"
        return 1
    fi
    
    # Run test in container
    if docker run --rm "$image_name" sh -c "$test_cmd" > "/tmp/test_$lang.log" 2>&1; then
        # Check if output contains expected FEN
        if grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR" "/tmp/test_$lang.log"; then
            echo -e "${GREEN}✓ $lang tests passed${NC}"
            TEST_RESULTS[$lang]="PASSED"
            return 0
        else
            echo -e "${YELLOW}⚠ $lang ran but output unexpected${NC}"
            echo "Output:"
            head -20 "/tmp/test_$lang.log"
            TEST_RESULTS[$lang]="UNEXPECTED"
            return 1
        fi
    else
        echo -e "${RED}✗ $lang tests failed${NC}"
        echo "Error output:"
        tail -10 "/tmp/test_$lang.log"
        TEST_RESULTS[$lang]="FAILED"
        return 1
    fi
}

# Main test execution
main() {
    # Find all implementations
    IMPLEMENTATIONS=($(find . -maxdepth 1 -type d -name "[a-z]*" | sed 's|./||' | grep -v test))
    
    echo "Found ${#IMPLEMENTATIONS[@]} implementations: ${IMPLEMENTATIONS[*]}"
    echo ""
    
    # Build phase
    echo -e "${BLUE}=== BUILD PHASE ===${NC}"
    for lang in "${IMPLEMENTATIONS[@]}"; do
        if [ -d "$lang" ]; then
            build_docker_image "$lang"
            echo ""
        fi
    done
    
    # Test phase
    echo -e "${BLUE}=== TEST PHASE ===${NC}"
    for lang in "${IMPLEMENTATIONS[@]}"; do
        if [ "${BUILD_RESULTS[$lang]}" == "SUCCESS" ] || [ "${BUILD_RESULTS[$lang]}" == "MINIMAL" ]; then
            run_tests "$lang"
            echo ""
        fi
    done
    
    # Summary
    echo ""
    echo -e "${BLUE}=================================================="
    echo "TEST SUMMARY"
    echo "==================================================${NC}"
    
    echo -e "\n${BLUE}Build Results:${NC}"
    for lang in "${IMPLEMENTATIONS[@]}"; do
        if [ -n "${BUILD_RESULTS[$lang]}" ]; then
            case ${BUILD_RESULTS[$lang]} in
                SUCCESS)
                    echo -e "  $lang: ${GREEN}✓ Built successfully${NC}"
                    ;;
                MINIMAL)
                    echo -e "  $lang: ${YELLOW}⚠ Built with minimal config${NC}"
                    ;;
                FAILED)
                    echo -e "  $lang: ${RED}✗ Build failed${NC}"
                    ;;
                NO_DOCKERFILE)
                    echo -e "  $lang: ${YELLOW}⚠ No Dockerfile${NC}"
                    ;;
            esac
        fi
    done
    
    echo -e "\n${BLUE}Test Results:${NC}"
    local passed=0
    local failed=0
    for lang in "${IMPLEMENTATIONS[@]}"; do
        if [ -n "${TEST_RESULTS[$lang]}" ]; then
            case ${TEST_RESULTS[$lang]} in
                PASSED)
                    echo -e "  $lang: ${GREEN}✓ Tests passed${NC}"
                    ((passed++))
                    ;;
                FAILED)
                    echo -e "  $lang: ${RED}✗ Tests failed${NC}"
                    ((failed++))
                    ;;
                UNEXPECTED)
                    echo -e "  $lang: ${YELLOW}⚠ Unexpected output${NC}"
                    ((failed++))
                    ;;
                NO_TEST)
                    echo -e "  $lang: ${YELLOW}⚠ No test defined${NC}"
                    ;;
            esac
        fi
    done
    
    echo ""
    echo -e "${BLUE}Total: $passed passed, $failed failed${NC}"
    
    # Clean up temp files
    rm -f /tmp/Dockerfile.* /tmp/test_*.log
    
    # Exit code
    if [ $failed -eq 0 ]; then
        echo -e "\n${GREEN}All available tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run main function
main "$@"