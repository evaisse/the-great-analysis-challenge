.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - install dependencies and compile ReScript project
build:
	npm install
	npm run build

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | node lib/es6/src/Chess.js | grep -q "FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running ReScript static analysis..."
	npm run build
	@echo "ReScript compilation check complete"

# Clean build artifacts
clean:
	rm -rf lib/
	rm -rf node_modules/

# Docker targets
docker-build:
	docker build -t chess-rescript .

docker-test: docker-build
	@echo "Testing ReScript implementation in Docker..."
	docker run --rm -i chess-rescript sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | node lib/es6/src/Chess.js"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
