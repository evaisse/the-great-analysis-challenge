.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - check PHP syntax
build:
	@echo "⏱️  Build started..."
	@START_TIME=$$(date +%s); \
	echo "Building PHP chess engine..." && \
	php -l chess.php && \
	for file in lib/*.php; do \
		php -l $$file; \
	done && \
	echo "✅ Build complete"; \
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
	echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | php chess.php | grep "FEN:" | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Test duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Static analysis and code quality
analyze:
	@echo "⏱️  Analyze started..."
	@START_TIME=$$(date +%s); \
	echo "Running PHP static analysis..." && \
	php -l chess.php && \
	find lib -name "*.php" -print0 | xargs -0 -n1 php -l && \
	echo "✅ Syntax check complete"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Analyze duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@# PHP doesn't typically create build artifacts, but clean vendor if exists
	@rm -rf vendor/
	@echo "✅ Clean complete"

# Docker targets
docker-build:
	docker build -t chess-php .

docker-test: docker-build
	@echo "Testing PHP implementation in Docker..."
	docker run --rm -i chess-php sh -c "printf 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit\\n' | php chess.php"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
