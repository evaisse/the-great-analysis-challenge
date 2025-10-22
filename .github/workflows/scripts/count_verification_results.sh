#!/bin/bash
# Count verification results and set GitHub outputs
# Usage: count_verification_results.sh

set -e

echo "=== Running Implementation Structure Verification ==="
python3 test/verify_implementations.py > verification_results.txt 2>&1

# Count implementations by status
EXCELLENT=$(grep -c "🟢.*excellent" verification_results.txt || echo "0")
GOOD=$(grep -c "🟡.*good" verification_results.txt || echo "0")
NEEDS_WORK=$(grep -c "🔴.*needs_work" verification_results.txt || echo "0")
TOTAL=$((EXCELLENT + GOOD + NEEDS_WORK))

echo "excellent_count=$EXCELLENT" >> $GITHUB_OUTPUT
echo "good_count=$GOOD" >> $GITHUB_OUTPUT
echo "needs_work_count=$NEEDS_WORK" >> $GITHUB_OUTPUT
echo "total_count=$TOTAL" >> $GITHUB_OUTPUT

echo "=== Verification Summary ==="
echo "Total implementations: $TOTAL"
echo "🟢 Excellent: $EXCELLENT"
echo "🟡 Good: $GOOD"
echo "🔴 Needs work: $NEEDS_WORK"

cat verification_results.txt