.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - validate the self-contained runtime wrapper
build:
	node chess-bridge.js --check

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@printf "help\ndisplay\nquit\n" | node chess-bridge.js > /tmp/elm_test_output 2>&1
	@if grep -q "Available commands:" /tmp/elm_test_output && grep -q "Chess Engine - Elm Implementation" /tmp/elm_test_output; then \
		echo "✅ Basic test passed"; \
	else \
		echo "❌ Basic test failed"; \
		cat /tmp/elm_test_output; \
		exit 1; \
	fi

# Static analysis and code quality
analyze:
	@echo "Running Elm runtime validation..."
	@node chess-bridge.js --check
	@echo "Elm runtime check complete"

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
	docker run --network none --rm -i chess-elm sh -c "printf 'help\\ndisplay\\nfen\\nperft 1\\nquit\\n' | node chess-bridge.js"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
.PHONY: bugit fix

bugit:
	python3 ../../scripts/error_analysis_benchmark.py bugit --impl .

fix:
	python3 ../../scripts/error_analysis_benchmark.py fix --impl .
