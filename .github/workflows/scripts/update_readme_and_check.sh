#!/bin/bash
# Update README status table and check if it was modified
# Usage: update_readme_and_check.sh

set -e

echo "=== Updating README Status Table ==="

# Update README using existing script
python3 .github/workflows/scripts/update_readme_status.py

# Check if README was modified
if git diff --quiet README.md; then
    echo "changed=false" >> $GITHUB_OUTPUT
    echo "⚠️ README.md was not modified"
else
    echo "changed=true" >> $GITHUB_OUTPUT
    echo "✅ README.md has been updated"
fi