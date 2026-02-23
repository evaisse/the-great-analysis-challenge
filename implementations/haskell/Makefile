.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Haskell with GHC
build:
	ghc -O2 --make src/Main.hs -o chess_engine -isrc

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@if [ -f "./chess_engine" ]; then \
		echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./chess_engine | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"; \
	else \
		ghc -O2 --make src/Main.hs -o chess_engine -isrc && \
		echo -e "new\\nmove e2e4\\nmove e7e5\\nexport\\nquit" | ./chess_engine | tail -1 | grep -q 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2' && echo "✅ Basic test passed" || echo "❌ Basic test failed"; \
	fi

# Static analysis and code quality
analyze:
	@echo "Running Haskell static analysis..."
	hlint src/ || true

# Clean build artifacts
clean:
	rm -f src/*.o src/*.hi chess_engine

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