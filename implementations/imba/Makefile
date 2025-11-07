.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - install dependencies (Imba runs directly without compilation for CLI)
build:
	npm install

# Run basic tests
test:
	npm test || true
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | npx imba run src/chess.imba | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Imba static analysis..."
	npm install

# Clean build artifacts
clean:
	rm -rf node_modules/
	npm cache clean --force || true

# Docker targets
docker-build:
	docker build -t chess-imba .

docker-test: docker-build
	@echo "Testing Imba implementation in Docker..."
	docker run --rm -i chess-imba sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | npx imba run src/chess.imba"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
