#!/bin/bash
# Count verification results and set GitHub outputs
# Usage: count_verification_results.sh

set -e

echo "=== Running Implementation Structure Verification ==="
python3 test/verify_implementations.py > verification_results.txt 2>&1 || true

# Count implementations by status
EXCELLENT=$(grep -c "🟢.*excellent" verification_results.txt 2>/dev/null | head -1)
GOOD=$(grep -c "🟡.*good" verification_results.txt 2>/dev/null | head -1)
NEEDS_WORK=$(grep -c "🔴.*needs_work" verification_results.txt 2>/dev/null | head -1)

# Ensure we have numeric values
EXCELLENT=${EXCELLENT:-0}
GOOD=${GOOD:-0}
NEEDS_WORK=${NEEDS_WORK:-0}

TOTAL=$((EXCELLENT + GOOD + NEEDS_WORK))

# Debug output
echo "Debug: EXCELLENT=$EXCELLENT GOOD=$GOOD NEEDS_WORK=$NEEDS_WORK TOTAL=$TOTAL"

# Set GitHub outputs if GITHUB_OUTPUT is defined
if [[ -n "$GITHUB_OUTPUT" ]]; then
    echo "excellent_count=$EXCELLENT" >> $GITHUB_OUTPUT
    echo "good_count=$GOOD" >> $GITHUB_OUTPUT
    echo "needs_work_count=$NEEDS_WORK" >> $GITHUB_OUTPUT
    echo "total_count=$TOTAL" >> $GITHUB_OUTPUT
else
    echo "Warning: GITHUB_OUTPUT not defined, skipping output file writes"
fi

echo "=== Verification Summary ==="
echo "Total implementations: $TOTAL"
echo "🟢 Excellent: $EXCELLENT"
echo "🟡 Good: $GOOD"
echo "🔴 Needs work: $NEEDS_WORK"

cat verification_results.txt