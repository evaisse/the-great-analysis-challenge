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
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./target/release/chess | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

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



# New targets for error analysis
bugit:
	# Check if backup exists, if not create it
	@if [ ! -f src/main.rs.bak ]; then cp src/main.rs src/main.rs.bak; fi
	# Append bug
	@printf "\n\nfn injected_bug_for_analysis() {\n    let x: i32 = \"string\";\n}\n" >> src/main.rs

fix:
	# Restore from backup
	@if [ -f src/main.rs.bak ]; then mv src/main.rs.bak src/main.rs; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
