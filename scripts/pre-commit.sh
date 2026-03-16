#!/bin/bash
# Pre-commit hook for The Great Analysis Challenge
# This hook ensures that implementation structure and repository tools are valid before committing.

# Allow skipping hooks with SKIP_HOOKS=1
if [ "$SKIP_HOOKS" = "1" ]; then
    exit 0
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Running pre-commit validations...${NC}"

# 1. Verify implementations structure (fast)
echo -e "${YELLOW}Step 1/2: Verifying implementation structures...${NC}"
if ! make verify; then
    echo -e "${RED}❌ Structure verification failed!${NC}"
    echo -e "${YELLOW}If you want to commit anyway, use: SKIP_HOOKS=1 git commit ...${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Structure OK${NC}"

# 2. Analyze repository tools (fast)
echo -e "${YELLOW}Step 2/2: Analyzing repository tools...${NC}"
if ! make analyze-tools; then
    echo -e "${RED}❌ Tool analysis failed!${NC}"
    echo -e "${YELLOW}Check the Bun shared tooling under tooling/ for issues.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Tools OK${NC}"

echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
exit 0
