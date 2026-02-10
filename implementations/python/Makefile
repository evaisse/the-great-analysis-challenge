.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Python bytecode for faster execution
build:
	python3 -m py_compile chess.py
	python3 -m py_compile lib/*.py

# Run basic tests
test:
	python3 test_engine.py
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | python3 chess.py | grep "FEN: " | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Python static analysis..."
	python3 -m pylint chess.py lib/*.py --disable=C0114,C0115,C0116 || true
	python3 -m mypy chess.py lib/*.py || true
	python3 -m flake8 chess.py lib/*.py --max-line-length=100 --ignore=E203,W503 || true
	python3 -m black --check --diff chess.py lib/*.py || true
	python3 -m bandit -r . -f txt || true

# Clean build artifacts
clean:
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyo" -delete

# Docker targets
docker-build:
	docker build -t chess-python .

docker-test: docker-build
	@echo "Testing Python implementation in Docker..."
	docker run --rm -i chess-python sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | python3 chess.py"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"