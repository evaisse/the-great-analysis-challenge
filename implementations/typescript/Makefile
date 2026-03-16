.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile TypeScript to JavaScript
build:
	bun run build

# Run basic tests
test:
	bun run test

# Static analysis and code quality
analyze:
	bun run lint

# Clean build artifacts
clean:
	rm -rf dist/
	rm -rf node_modules/
	rm -f bun.lock bun.lockb

# Docker targets
docker-build:
	docker build -t chess-typescript .

docker-test: docker-build
	@echo "Testing TypeScript implementation in Docker..."
	docker run --network none --rm -i chess-typescript sh -c "printf 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit\\n' | bun run dist/chess.js"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"

.PHONY: bugit fix

bugit:
	python3 ../../scripts/error_analysis_benchmark.py bugit --impl .

fix:
	python3 ../../scripts/error_analysis_benchmark.py fix --impl .
