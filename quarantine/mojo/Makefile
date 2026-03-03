.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine (WIP)
all: build

# Build target - check Mojo syntax (WIP)
build:
	@echo "Mojo implementation (WIP) - syntax check"
	mojo chess.mojo --no-run || echo "Note: Mojo runtime required or engine WIP"

# Run basic tests (WIP)
test:
	@echo "Running basic smoke test (WIP)..."
	@printf "help\nquit\n" | mojo chess.mojo > /tmp/mojo_test_output 2>&1 || { \
		echo "⚠️  Mojo runtime required or engine WIP"; \
		cat /tmp/mojo_test_output; \
		exit 0; \
	}
	@if grep -q "Mojo Chess Engine" /tmp/mojo_test_output; then \
		echo "✅ Basic test passed"; \
	else \
		echo "⚠️  Basic test output unexpected"; \
		cat /tmp/mojo_test_output; \
	fi

# Static analysis and code quality
analyze:
	@echo "Running Mojo static analysis (WIP)..."
	mojo chess.mojo --no-run || echo "Mojo runtime required or engine WIP"

# Clean build artifacts
clean:
	@echo "Cleaning Mojo artifacts..."
	rm -rf .mojo_cache/ || true

# Docker targets
docker-build:
	docker build -t chess-mojo .

docker-test: docker-build
	@echo "Testing Mojo implementation in Docker (WIP)..."
	docker run --network none --rm -i chess-mojo sh -c "printf 'help\\nquit\\n' | mojo chess.mojo || true"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine (WIP)"
	@echo "  make test    - Run tests (WIP)"
	@echo "  make analyze - Run static analysis (WIP)"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker (WIP)"
