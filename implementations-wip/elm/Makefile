.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - install dependencies and compile Elm project
build:
	@echo "⏱️  Build started..."
	@START_TIME=$$(date +%s); \
	npm install && \
	elm make src/ChessEngine.elm --output=src/chess.js; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Build duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Run basic tests
test:
	@echo "⏱️  Test started..."
	@START_TIME=$$(date +%s); \
	echo "Running basic functionality test..." && \
	printf "help\ndisplay\nquit\n" | node chess-bridge.js > /tmp/elm_test_output 2>&1 && \
	grep -q "Available commands:" /tmp/elm_test_output && grep -q "Chess Engine - Elm Implementation" /tmp/elm_test_output && echo "✅ Basic test passed" || echo "❌ Basic test failed"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Test duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Static analysis and code quality
analyze:
	@echo "⏱️  Analyze started..."
	@START_TIME=$$(date +%s); \
	echo "Running Elm static analysis..." && \
	elm make src/ChessEngine.elm --output=/dev/null && \
	echo "Elm compilation check complete"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Analyze duration: $${DURATION}s"; \
	exit $$EXIT_CODE

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