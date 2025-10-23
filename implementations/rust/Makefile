.PHONY: all build test analyze clean docker-build docker-test bugit fix analyze-with-bug

# Default target - build the chess engine
all: build

# Build target - compile Rust binary
build:
	cargo build --release

# Run basic tests
test:
	cargo test
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./target/release/chess | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Rust static analysis..."
	cargo fmt --check || true
	cargo clippy -- -D warnings || true
	cargo audit || true

# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		cp src/board.rs .bugit/board.rs.backup; \
		sed -i '/^impl Board {/a\    #[allow(dead_code)]\n    fn inject_bug() {\n        let _unused_debug_variable = "This should be detected by clippy";\n    }' src/board.rs; \
		touch .bugit/BUGGED; \
		echo "✅ Bug injected in src/board.rs"; \
	else \
		echo "⚠️  Bug already injected. Run 'make fix' first."; \
	fi

# Fix the injected bug
fix:
	@echo "Fixing injected bug..."
	@if [ -f .bugit/BUGGED ]; then \
		cp .bugit/board.rs.backup src/board.rs; \
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
	@echo "--- Cargo Fmt Analysis ---" >> .bugit/analysis_results.txt
	@(time cargo fmt --check 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Cargo Clippy Analysis ---" >> .bugit/analysis_results.txt
	@(time cargo clippy -- -D warnings 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Cargo Audit Analysis ---" >> .bugit/analysis_results.txt
	@(time cargo audit 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

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
	@echo "  make bugit   - Inject bug for testing static analysis"
	@echo "  make fix     - Fix injected bug"
	@echo "  make analyze-with-bug - Run analysis with bug and save results"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"