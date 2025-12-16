.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Dart to native executable
build:
	@echo "⏱️  Build started..."
	@START_TIME=$$(date +%s); \
	dart pub get && \
	dart compile exe bin/main.dart -o bin/chess_engine; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Build duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Run basic tests
test:
	@echo "⏱️  Test started..."
	@START_TIME=$$(date +%s); \
	dart test && \
	echo "Running basic functionality test..." && \
	echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./bin/chess_engine | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || (echo "❌ Basic test failed" && exit 1); \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Test duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Static analysis and code quality
analyze:
	@echo "⏱️  Analyze started..."
	@START_TIME=$$(date +%s); \
	echo "Running Dart static analysis..." && \
	dart analyze && \
	dart format --set-exit-if-changed .; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Analyze duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Clean build artifacts
clean:
	@echo "Cleaning Dart build artifacts..."
	rm -f bin/chess_engine
	rm -rf build/

# Docker targets
docker-build:
	docker build -t chess-dart .

docker-test: docker-build
	@echo "Testing Dart implementation in Docker..."
	docker run --rm -i chess-dart sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./bin/chess_engine"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
