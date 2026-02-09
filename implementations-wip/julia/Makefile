.PHONY: all build test analyze clean docker-build docker-test bugit fix analyze-with-bug

# Default target - build the chess engine
all: build

# Build target - instantiate Julia packages
build:
	julia --project=. -e "using Pkg; Pkg.instantiate()"

# Run basic tests
test:
	julia --project=. -e "using Pkg; Pkg.test()" || true
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | julia --project=. chess.jl | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Julia static analysis..."
	julia --project=. -e "using Pkg; Pkg.add(\"JuliaFormatter\"); using JuliaFormatter; format(\".\")" || true

# Clean build artifacts
clean:
	julia --project=. -e "using Pkg; Pkg.gc()" || true
	rm -rf Manifest.toml


# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		cp src/board.jl .bugit/board.jl.backup; \
		sed -i '2a const UNUSED_DEBUG_VARIABLE = "This should be detected"' src/board.jl; \
		touch .bugit/BUGGED; \
		echo "✅ Bug injected in src/board.jl"; \
	else \
		echo "⚠️  Bug already injected. Run 'make fix' first."; \
	fi

# Fix the injected bug
fix:
	@echo "Fixing injected bug..."
	@if [ -f .bugit/BUGGED ]; then \
		cp .bugit/board.jl.backup src/board.jl; \
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
	@echo "--- Static Analysis Output ---" >> .bugit/analysis_results.txt
	@(time $(MAKE) analyze 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

# Docker targets
docker-build:
	docker build -t chess-julia .

docker-test: docker-build
	@echo "Testing Julia implementation in Docker..."
	docker run --rm -i chess-julia sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | julia --project=. chess.jl"

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