.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - compile Nim project
build:
	nim compile --opt:speed chess.nim

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./chess | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Nim static analysis..."
	nim check chess.nim
	@echo "Nim code check complete"

# Clean build artifacts
clean:
	rm -f chess
	rm -rf nimcache/

# Docker targets
docker-build:
	docker build -t chess-nim .

docker-test: docker-build
	@echo "Testing Nim implementation in Docker..."
	docker run --network none --rm -i chess-nim sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./chess"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"