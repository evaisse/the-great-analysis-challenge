#!/bin/bash
# Parse test configuration from chess.meta and set GitHub outputs
# Usage: parse_test_config.sh <engine_name>

set -e

ENGINE="$1"
if [[ -z "$ENGINE" ]]; then
    echo "Error: Engine name required"
    exit 1
fi

echo "🔧 Reading test configuration from chess.meta..."
CONFIG=$(python3 .github/workflows/scripts/get_test_config.py "$ENGINE")
echo "Configuration: $CONFIG"

# Parse configuration using Python one-liners
SUPPORTS_INTERACTIVE=$(echo "$CONFIG" | python3 -c "import sys, json; print(json.load(sys.stdin)['supports_interactive'])")
SUPPORTS_PERFT=$(echo "$CONFIG" | python3 -c "import sys, json; print(json.load(sys.stdin)['supports_perft'])")
SUPPORTS_AI=$(echo "$CONFIG" | python3 -c "import sys, json; print(json.load(sys.stdin)['supports_ai'])")
TEST_MODE=$(echo "$CONFIG" | python3 -c "import sys, json; print(json.load(sys.stdin)['test_mode'])")

# Set GitHub outputs
echo "supports_interactive=$SUPPORTS_INTERACTIVE" >> $GITHUB_OUTPUT
echo "supports_perft=$SUPPORTS_PERFT" >> $GITHUB_OUTPUT
echo "supports_ai=$SUPPORTS_AI" >> $GITHUB_OUTPUT
echo "test_mode=$TEST_MODE" >> $GITHUB_OUTPUT