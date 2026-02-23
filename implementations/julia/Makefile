.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - instantiate Julia packages
build:
	@echo "No build step required for Julia implementation"

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | julia --project=. chess.jl | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Julia static analysis..."
	@echo "No static analysis configured"

# Clean build artifacts
clean:
	julia --project=. -e "using Pkg; Pkg.gc()" || true
	rm -rf Manifest.toml

# Docker targets
docker-build:
	docker build -t chess-julia .

docker-test: docker-build
	@echo "Testing Julia implementation in Docker..."
	docker run --network none --rm -i chess-julia sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | julia --project=. chess.jl"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
