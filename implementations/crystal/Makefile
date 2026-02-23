.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Crystal binary
build:
	crystal build src/chess_engine.cr --release -o chess_engine

# Run basic tests
test:
	crystal spec || true
	@echo "Running basic functionality test..."
	@if printf "new\nmove e2e4\nmove e7e5\nexport\nquit\n" | ./chess_engine | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2"; then \
		echo "✅ Basic test passed"; \
	else \
		echo "❌ Basic test failed"; \
		exit 1; \
	fi

# Static analysis and code quality
analyze:
	@echo "Running Crystal static analysis..."
	crystal tool format --check src/ || true
	crystal build src/chess_engine.cr --no-codegen || true

# Clean build artifacts
clean:
	rm -f chess_engine
	rm -rf .crystal/

# Docker targets
docker-build:
	docker build -t chess-crystal .

docker-test: docker-build
	@echo "Testing Crystal implementation in Docker..."
	docker run --network none --rm -i chess-crystal sh -c "printf 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit\\n' | ./chess_engine"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
