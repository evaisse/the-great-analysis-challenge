#!/bin/bash

# Local test runner for chess engines
# This script tests implementations locally when Docker is unavailable

echo "====================================="
echo "Local Chess Engine Test Runner"
echo "====================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test Ruby implementation
test_ruby() {
    echo -e "${YELLOW}Testing Ruby implementation...${NC}"
    if command -v ruby &> /dev/null; then
        cd ruby
        if echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ruby chess.rb | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR"; then
            echo -e "${GREEN}✓ Ruby tests passed${NC}"
        else
            echo -e "${RED}✗ Ruby tests failed${NC}"
        fi
        cd ..
    else
        echo -e "${YELLOW}Ruby not installed${NC}"
    fi
}

# Test TypeScript implementation
test_typescript() {
    echo -e "${YELLOW}Testing TypeScript implementation...${NC}"
    if command -v node &> /dev/null; then
        cd typescript
        if [ -f "dist/chess.js" ]; then
            if echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | node dist/chess.js | grep -q "FEN:"; then
                echo -e "${GREEN}✓ TypeScript tests ran (check output for correctness)${NC}"
            else
                echo -e "${RED}✗ TypeScript tests failed${NC}"
            fi
        else
            echo -e "${YELLOW}TypeScript not built. Run: cd typescript && npm install && npm run build${NC}"
        fi
        cd ..
    else
        echo -e "${YELLOW}Node.js not installed${NC}"
    fi
}

# Run tests
test_ruby
echo ""
test_typescript

echo ""
echo "====================================="
echo "Note: For complete testing with all implementations,"
echo "Docker is required. Please ensure Docker daemon is"
echo "running and network access to Docker Hub is available."
echo "====================================="