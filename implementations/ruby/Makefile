.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - install dependencies
build:
	bundle install

# Run basic tests
test:
	ruby -c chess.rb
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ruby chess.rb | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Ruby static analysis..."
	bundle exec rubocop chess.rb lib/*.rb || true
	ruby -w chess.rb -c 2>/dev/null || true

# Clean build artifacts
clean:
	bundle clean || true
	rm -rf .bundle/

# Docker targets
docker-build:
	docker build -t chess-ruby .

docker-test: docker-build
	@echo "Testing Ruby implementation in Docker..."
	docker run --rm -i chess-ruby sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ruby chess.rb"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"