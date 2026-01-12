.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - install dependencies and compile Elm project
build:
	npm install
	elm make src/ChessEngine.elm --output=src/chess.js

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@printf "help\ndisplay\nquit\n" | node chess-bridge.js > /tmp/elm_test_output 2>&1
	@grep -q "Available commands:" /tmp/elm_test_output && grep -q "Chess Engine - Elm Implementation" /tmp/elm_test_output && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Elm static analysis..."
	elm make src/ChessEngine.elm --output=/dev/null
	@echo "Elm compilation check complete"

# Clean build artifacts
clean:
	rm -rf elm-stuff/
	rm -rf node_modules/
	rm -f src/chess.js

# Docker targets
docker-build:
	docker build -t chess-elm .

docker-test: docker-build
	@echo "Testing Elm implementation in Docker..."
	docker run --rm -i chess-elm sh -c "printf 'help\\ndisplay\\nfen\\nperft 1\\nquit\\n' | node chess-bridge.js"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"



# New targets for error analysis
bugit:
	# Check if backup exists, if not create it
	@if [ ! -f src/ChessEngine.elm.bak ]; then cp src/ChessEngine.elm src/ChessEngine.elm.bak; fi
	# Append bug
	@printf "\n\ninjectedBugForAnalysis : Int\ninjectedBugForAnalysis = \"string\"\n" >> src/ChessEngine.elm

fix:
	# Restore from backup
	@if [ -f src/ChessEngine.elm.bak ]; then mv src/ChessEngine.elm.bak src/ChessEngine.elm; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
