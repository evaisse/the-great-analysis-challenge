.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Haskell with Cabal
build:
	cabal build

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@if [ -f "./chess_engine" ]; then \
		echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./chess_engine | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"; \
	else \
		cabal run chess --verbose=0 -- sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | tail -1 | grep -q 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'" && echo "✅ Basic test passed (via cabal)" || echo "❌ Basic test failed"; \
	fi

# Static analysis and code quality
analyze:
	@echo "Running Haskell static analysis..."
	hlint src/ || true
	cabal check || true

# Clean build artifacts
clean:
	cabal clean
	rm -f chess_engine

# Docker targets
docker-build:
	docker build -t chess-haskell .

docker-test: docker-build
	@echo "Testing Haskell implementation in Docker..."
	docker run --network none --rm -i chess-haskell sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./chess_engine"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"