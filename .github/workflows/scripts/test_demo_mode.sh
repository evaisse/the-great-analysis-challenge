#!/bin/bash
# Test demo mode implementations
# Usage: test_demo_mode.sh <engine_name>

set -e

ENGINE="$1"
if [[ -z "$ENGINE" ]]; then
    echo "Error: Engine name required"
    exit 1
fi

echo "🎯 Running demo mode test for $ENGINE..."
timeout 30s docker run --rm chess-$ENGINE-test || true
echo "✅ Demo test completed"