.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Dart to native executable
build:
	dart pub get
	dart compile exe bin/main.dart -o bin/chess_engine

# Run basic tests
test:
	dart test
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./bin/chess_engine | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || (echo "❌ Basic test failed" && exit 1)

# Static analysis and code quality
analyze:
	@echo "Running Dart static analysis..."
	dart analyze
	dart format --set-exit-if-changed .

# Clean build artifacts
clean:
	@echo "Cleaning Dart build artifacts..."
	rm -f bin/chess_engine
	rm -rf build/

# Docker targets
docker-build:
	docker build -t chess-dart .

docker-test: docker-build
	@echo "Testing Dart implementation in Docker..."
	docker run --rm -i chess-dart sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./bin/chess_engine"

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
	@if [ ! -f bin/main.dart.bak ]; then cp bin/main.dart bin/main.dart.bak; fi
	# Append bug
	@printf "\n\nvoid injectedBugForAnalysis() {\n  int x = \"string\";\n}\n" >> bin/main.dart

fix:
	# Restore from backup
	@if [ -f bin/main.dart.bak ]; then mv bin/main.dart.bak bin/main.dart; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
