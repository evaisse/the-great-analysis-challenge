.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - compile Gleam project
build:
	gleam build

# Run basic tests
test:
	gleam test
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | gleam run | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Gleam static analysis..."
	gleam format --check || true
	gleam check

# Clean build artifacts
clean:
	gleam clean
	rm -rf build/

# Docker targets
docker-build:
	docker build -t chess-gleam .

docker-test: docker-build
	@echo "Testing Gleam implementation in Docker..."
	docker run --rm -i chess-gleam sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | gleam run"

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
	@if [ ! -f src/chess_engine.gleam.bak ]; then cp src/chess_engine.gleam src/chess_engine.gleam.bak; fi
	# Append bug
	@printf "\n\npub fn injected_bug_for_analysis() {\n  let x: Int = \"string\"\n}\n" >> src/chess_engine.gleam

fix:
	# Restore from backup
	@if [ -f src/chess_engine.gleam.bak ]; then mv src/chess_engine.gleam.bak src/chess_engine.gleam; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
