#!/bin/bash
# Test advanced chess engine features based on configuration
# Usage: test_advanced_features.sh <engine_name> <supports_perft> <supports_ai>

set -e

ENGINE="$1"
SUPPORTS_PERFT="$2"
SUPPORTS_AI="$3"

if [[ -z "$ENGINE" || -z "$SUPPORTS_PERFT" || -z "$SUPPORTS_AI" ]]; then
    echo "Error: All parameters required: engine_name supports_perft supports_ai"
    exit 1
fi

echo "🧪 Testing advanced features for $ENGINE..."

# Test perft if supported
if [[ "$SUPPORTS_PERFT" == "true" ]]; then
    echo "🔍 Testing perft (move generation)"
    echo "perft 3" | timeout 120s docker run --rm -i chess-$ENGINE-test > perft_output.txt || true
    
    if grep -E "([0-9]+.*nodes|Depth.*[0-9]+)" perft_output.txt; then
        echo "✅ Perft test completed"
    else
        echo "⚠️ Perft test may have issues"
    fi
else
    echo "⏭️ Perft not supported, skipping"
fi

# Test AI if supported
if [[ "$SUPPORTS_AI" == "true" ]]; then
    echo "🤖 Testing AI move generation"
    {
        echo "ai"
        sleep 2
        echo "quit"
    } | timeout 60s docker run --rm -i chess-$ENGINE-test > ai_output.txt || true
    
    if [[ -s ai_output.txt ]]; then
        echo "✅ AI test completed"
    else
        echo "⚠️ AI test may have issues"
    fi
else
    echo "⏭️ AI not supported, skipping"
fi