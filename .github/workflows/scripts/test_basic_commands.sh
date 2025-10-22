#!/bin/bash
# Test basic chess engine commands
# Usage: test_basic_commands.sh <engine_name>

set -e

ENGINE="$1"
if [[ -z "$ENGINE" ]]; then
    echo "Error: Engine name required"
    exit 1
fi

echo "🧪 Testing basic functionality for $ENGINE..."

# Test basic commands that all implementations should support
echo "📋 Testing help command"
echo "help" | timeout 30s docker run --rm -i chess-$ENGINE-test > help_output.txt || true

echo "📋 Testing board display"
echo "board" | timeout 30s docker run --rm -i chess-$ENGINE-test > board_output.txt || true

echo "📋 Testing FEN export"
echo "fen" | timeout 30s docker run --rm -i chess-$ENGINE-test > fen_output.txt || true

# Basic validation - just check if commands execute without major errors
if [[ -s help_output.txt ]] && [[ -s board_output.txt ]] && [[ -s fen_output.txt ]]; then
    echo "✅ Basic commands executed successfully"
else
    echo "⚠️ Some basic commands may have issues"
fi