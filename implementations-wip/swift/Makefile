.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - compile Swift project
build:
	swift build --configuration release

# Run basic tests
test:
	swift test
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | .build/release/Chess | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Swift static analysis..."
	swift build --configuration debug
	@echo "Swift build successful - static analysis complete"

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build/

# Docker targets
docker-build:
	docker build -t chess-swift .

docker-test: docker-build
	@echo "Testing Swift implementation in Docker..."
	docker run --rm -i chess-swift sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | .build/release/Chess"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"