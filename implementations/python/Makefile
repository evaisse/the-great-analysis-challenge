.PHONY: all build test analyze clean docker-build docker-test bugit fix analyze-with-bug

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
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | python3 chess.py | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Python static analysis..."
	python3 -m pylint chess.py lib/*.py --disable=C0114,C0115,C0116 || true
	python3 -m mypy chess.py lib/*.py || true
	python3 -m flake8 chess.py lib/*.py --max-line-length=100 --ignore=E203,W503 || true
	python3 -m black --check --diff chess.py lib/*.py || true
	python3 -m bandit -r . -f txt || true

# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		cp lib/board.py .bugit/board.py.backup; \
		sed -i '7a import os  # unused import\nUNUSED_DEBUG_VARIABLE = "This should be detected by pylint"' lib/board.py; \
		touch .bugit/BUGGED; \
		echo "✅ Bug injected in lib/board.py"; \
	else \
		echo "⚠️  Bug already injected. Run 'make fix' first."; \
	fi

# Fix the injected bug
fix:
	@echo "Fixing injected bug..."
	@if [ -f .bugit/BUGGED ]; then \
		cp .bugit/board.py.backup lib/board.py; \
		rm -f .bugit/BUGGED; \
		echo "✅ Bug fixed, original file restored"; \
	else \
		echo "⚠️  No bug to fix. Run 'make bugit' first."; \
	fi

# Run static analysis with bug and measure performance
analyze-with-bug: bugit
	@echo "Running static analysis with injected bug..."
	@mkdir -p .bugit
	@echo "=== Analysis Results ===" > .bugit/analysis_results.txt
	@echo "Timestamp: $$(date)" >> .bugit/analysis_results.txt
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Pylint Analysis ---" >> .bugit/analysis_results.txt
	@(time python3 -m pylint chess.py lib/*.py --disable=C0114,C0115,C0116 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Mypy Analysis ---" >> .bugit/analysis_results.txt
	@(time python3 -m mypy chess.py lib/*.py 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Flake8 Analysis ---" >> .bugit/analysis_results.txt
	@(time python3 -m flake8 chess.py lib/*.py --max-line-length=100 --ignore=E203,W503 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Bandit Security Analysis ---" >> .bugit/analysis_results.txt
	@(time python3 -m bandit -r . -f txt 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

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
	@echo "  make bugit   - Inject bug for testing static analysis"
	@echo "  make fix     - Fix injected bug"
	@echo "  make analyze-with-bug - Run analysis with bug and save results"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"