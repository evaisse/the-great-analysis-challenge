#!/bin/bash
# Demo script showing the error analysis feature

set -e

echo "================================================"
echo "Error Analysis Performance Testing Demo"
echo "================================================"
echo ""

# Select a few languages for the demo
DEMO_LANGS="python typescript rust"

echo "This demo will:"
echo "1. Inject bugs in Python, TypeScript, and Rust implementations"
echo "2. Show the injected bugs"
echo "3. Fix the bugs"
echo "4. Verify the fixes"
echo ""
read -p "Press Enter to continue..."
echo ""

# Step 1: Inject bugs
echo "Step 1: Injecting bugs..."
echo "========================================"
for lang in $DEMO_LANGS; do
    echo ""
    echo "Injecting bug in $lang..."
    make bugit-$lang
done

echo ""
echo "Step 2: Showing injected bugs..."
echo "========================================"

echo ""
echo "Python - Unused import and variable:"
grep -A 1 "import os" implementations/python/lib/board.py | head -2

echo ""
echo "TypeScript - Unused variable:"
grep "unusedDebug" implementations/typescript/src/board.ts

echo ""
echo "Rust - Dead code function:"
grep -A 2 "inject_bug" implementations/rust/src/board.rs | head -3

echo ""
read -p "Press Enter to fix the bugs..."
echo ""

# Step 3: Fix bugs
echo "Step 3: Fixing bugs..."
echo "========================================"
for lang in $DEMO_LANGS; do
    echo ""
    echo "Fixing bug in $lang..."
    make fix-$lang
done

echo ""
echo "Step 4: Verifying fixes..."
echo "========================================"

echo ""
echo "Python - No unused imports:"
if grep -q "import os.*unused" implementations/python/lib/board.py; then
    echo "❌ Bug still present!"
else
    echo "✅ Bug fixed successfully!"
fi

echo ""
echo "TypeScript - No unused variables:"
if grep -q "unusedDebug" implementations/typescript/src/board.ts; then
    echo "❌ Bug still present!"
else
    echo "✅ Bug fixed successfully!"
fi

echo ""
echo "Rust - No dead code:"
if grep -q "inject_bug" implementations/rust/src/board.rs; then
    echo "❌ Bug still present!"
else
    echo "✅ Bug fixed successfully!"
fi

echo ""
echo "================================================"
echo "Demo Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  - Run 'make analyze-with-bug-python' to see static analysis output"
echo "  - Run 'make analyze-with-bug-all' to test all languages"
echo "  - Check analysis_reports/bug_analysis_summary.md for results"
echo ""
