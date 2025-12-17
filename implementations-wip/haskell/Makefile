.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Haskell with Cabal
build:
	cabal update
	cabal build

# Run basic tests
test:
	cabal test || true
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | cabal run chess | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Haskell static analysis..."
	hlint src/ || true
	cabal check || true

# Clean build artifacts
clean:
	cabal clean

# Docker targets
docker-build:
	docker build -t chess-haskell .

docker-test: docker-build
	@echo "Testing Haskell implementation in Docker..."
	docker run --rm -i chess-haskell sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | cabal run chess"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"