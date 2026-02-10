#!/bin/bash

# Script de construction locale pour tester sans Docker
# Local build script to test without Docker
# Convention over Configuration: Uses chess.meta for build commands

set -e

echo "🏗️  Testing local builds of chess implementations..."
echo "===================================================="

IMPLEMENTATIONS_DIR="./implementations"
BUILD_LOG="build_results.log"

# Create build results directory
mkdir -p build_results
echo "Build started at $(date)" >"$BUILD_LOG"

# Function to test build in directory
test_build() {
	local lang=$1
	local dir="$IMPLEMENTATIONS_DIR/$lang"
	local abs_dir=$(pwd)/$IMPLEMENTATIONS_DIR/$lang

	echo "🔍 Testing $lang implementation..."

	if [ ! -d "$dir" ]; then
		echo "❌ Directory $dir not found"
		return 1
	fi

	# Extract build command using our metadata script
	BUILD_CMD=$(./scripts/get_metadata.py "$dir" --field build)

	cd "$dir"

	if [ -n "$BUILD_CMD" ]; then
		echo "🛠️  Running: $BUILD_CMD"
		if eval "$BUILD_CMD"; then
			echo "✅ $lang build success"
		else
			echo "❌ $lang build failed"
		fi
	else
		echo "⚠️  No build command found"
	fi

	cd - >/dev/null
	echo ""
}

# Function to test build in directory
test_build() {
	local lang=$1
	local dir="$IMPLEMENTATIONS_DIR/$lang"

	echo "🔍 Testing $lang implementation..."

	if [ ! -d "$dir" ]; then
		echo "❌ Directory $dir not found"
		return 1
	fi

	cd "$dir"

	# Check if chess.meta exists
	if [ -f "chess.meta" ]; then
		echo "📋 Using chess.meta for build instructions"
		BUILD_CMD=$(get_meta_field "chess.meta" "build")

		if [ -n "$BUILD_CMD" ]; then
			echo "🛠️  Running: $BUILD_CMD"
			# NOTE: Using eval here for simplicity. In production, consider validating commands
			# or using jq for safer JSON parsing. This assumes chess.meta is trusted content.
			if eval "$BUILD_CMD"; then
				echo "✅ $lang build success"
			else
				echo "❌ $lang build failed"
			fi
		else
			echo "⚠️  No build command found in chess.meta"
		fi
	elif [ -f "Makefile" ]; then
		echo "📋 Using Makefile build target"
		if make build; then
			echo "✅ $lang build success"
		else
			echo "❌ $lang build failed"
		fi
	else
		echo "⚠️  No chess.meta or Makefile found"
	fi

	cd - >/dev/null
	echo ""
}

# Auto-discover all implementations
echo "Scanning for implementations..."

IMPLEMENTATIONS=()
for dir in "$IMPLEMENTATIONS_DIR"/*/; do
	if [ -d "$dir" ]; then
		lang=$(basename "$dir")
		IMPLEMENTATIONS+=("$lang")
	fi
done

echo "Found ${#IMPLEMENTATIONS[@]} implementations: ${IMPLEMENTATIONS[*]}"
echo ""

for lang in "${IMPLEMENTATIONS[@]}"; do
	test_build "$lang" 2>&1 | tee -a "$BUILD_LOG"
done

echo "🏁 Build testing complete!"
echo "📊 Results logged to: $BUILD_LOG"
echo ""
echo "💡 To use Docker (recommended):"
echo "   make build DIR=<language>"
echo "   make test DIR=<language>"
echo ""
echo "💡 Examples:"
echo "   make build DIR=go"
echo "   make test DIR=ruby"
echo "   make build-all  # Build all implementations"
