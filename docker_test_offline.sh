#!/bin/bash

# Offline Docker test script - uses existing local images
echo "======================================="
echo "Docker Test Runner (Offline Mode)"
echo "======================================="
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Error: Docker is not running"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test function using existing images
test_with_existing_image() {
    local lang=$1
    local base_image=$2
    local build_cmd=$3
    local test_cmd=$4
    
    echo -e "${YELLOW}Testing $lang...${NC}"
    
    # Check if we have the base image locally
    if docker image inspect "$base_image" >/dev/null 2>&1; then
        echo "Using local image: $base_image"
        
        # Create and run container with the implementation
        docker run --rm -v "$(pwd)/$lang:/app" -w /app "$base_image" sh -c "$build_cmd && $test_cmd" 2>&1 | tee "/tmp/test_$lang.log"
        
        if grep -q "FEN:" "/tmp/test_$lang.log" || grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR" "/tmp/test_$lang.log"; then
            echo -e "${GREEN}✓ $lang test completed${NC}"
        else
            echo -e "${RED}✗ $lang test failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Base image $base_image not found locally${NC}"
    fi
    echo ""
}

# Test implementations with common base images that might be cached locally
test_with_existing_image "typescript" "node:18-alpine" \
    "npm install && npm run build" \
    "echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node dist/chess.js"

test_with_existing_image "ruby" "ruby:3.2-alpine" \
    "true" \
    "echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ruby chess.rb"

# Alternative: Use alpine with language packages
echo -e "${YELLOW}Trying with alpine base image...${NC}"
if docker image inspect "alpine:latest" >/dev/null 2>&1; then
    echo "Testing with alpine + packages..."
    
    # Ruby with alpine
    docker run --rm -v "$(pwd)/ruby:/app" -w /app alpine:latest sh -c \
        "apk add --no-cache ruby && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ruby chess.rb" 2>&1 | \
        tee "/tmp/test_ruby_alpine.log"
    
    if grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR" "/tmp/test_ruby_alpine.log"; then
        echo -e "${GREEN}✓ Ruby (alpine) test passed${NC}"
    fi
fi

echo ""
echo "======================================="
echo "Summary"
echo "======================================="
echo "Tests run using locally available Docker images."
echo "For full testing, ensure Docker Hub access is available."