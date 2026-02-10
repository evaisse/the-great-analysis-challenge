.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Rust binary
build:
	cargo build --release

# Run basic tests
test:
	cargo test
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./target/release/chess | grep "FEN: " | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Rust static analysis..."
	cargo fmt --check || true
	cargo clippy -- -D warnings || true
	cargo audit || true

# Clean build artifacts
clean:
	cargo clean

# Docker targets
docker-build:
	docker build -t chess-rust .

docker-test: docker-build
	@echo "Testing Rust implementation in Docker..."
	docker run --rm -i chess-rust sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./target/release/chess"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"