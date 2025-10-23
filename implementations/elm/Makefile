.PHONY: all build test analyze clean docker-build docker-test help bugit fix analyze-with-bug

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


# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		cp src/Board.elm .bugit/Board.elm.backup; \
		sed -i '2a unusedDebugVariable : String\nunusedDebugVariable = \"This should be detected\"' src/Board.elm; \
		touch .bugit/BUGGED; \
		echo "✅ Bug injected in src/Board.elm"; \
	else \
		echo "⚠️  Bug already injected. Run 'make fix' first."; \
	fi

# Fix the injected bug
fix:
	@echo "Fixing injected bug..."
	@if [ -f .bugit/BUGGED ]; then \
		cp .bugit/Board.elm.backup src/Board.elm; \
		rm -f .bugit/BUGGED; \
		echo "✅ Bug fixed, original file restored"; \
	else \
		echo "⚠️  No bug to fix. Run 'make bugit' first."; \
	fi

# Run static analysis with bug and measure performance
analyze-with-bug: bugit
	@echo "Running static analysis with injected bug..."
	@mkdir -p .bugit
	@echo "=== Analysis Results ===" > .bugit/analysis_results.txt
	@echo "Timestamp: $$(date)" >> .bugit/analysis_results.txt
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Static Analysis Output ---" >> .bugit/analysis_results.txt
	@(time $(MAKE) analyze 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

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
	@echo "  make bugit   - Inject bug for testing static analysis"
	@echo "  make fix     - Fix injected bug"
	@echo "  make analyze-with-bug - Run analysis with bug and save results"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"