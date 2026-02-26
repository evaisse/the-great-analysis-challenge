#!/bin/bash
# Setup script to install git hooks for the project.

HOOKS_DIR=$(git rev-parse --show-toplevel)/.git/hooks
PRE_COMMIT_HOOK=$HOOKS_DIR/pre-commit
SOURCE_HOOK=$(git rev-parse --show-toplevel)/scripts/pre-commit.sh

echo "Installing git hooks..."

# Ensure the scripts directory exists and the hook source is executable
chmod +x "$SOURCE_HOOK"

# Create a symlink for the pre-commit hook
if [ -L "$PRE_COMMIT_HOOK" ]; then
    rm "$PRE_COMMIT_HOOK"
fi

ln -s "../../scripts/pre-commit.sh" "$PRE_COMMIT_HOOK"

echo "✅ Pre-commit hook installed successfully at $PRE_COMMIT_HOOK"
echo "   It will run 'make verify' and 'make analyze-tools' on every commit."
