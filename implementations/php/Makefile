.PHONY: all build test analyze clean docker-build docker-test help

# Default target - build the chess engine
all: build

# Build target - check PHP syntax
build:
	@echo "Building PHP chess engine..."
	php -l chess.php
	@for file in lib/*.php; do \
		php -l $$file; \
	done
	@echo "✅ Build complete"

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | php chess.php | grep "FEN:" | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running PHP static analysis..."
	@php -l chess.php
	@find lib -name "*.php" -print0 | xargs -0 -n1 php -l
	@echo "✅ Syntax check complete"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@# PHP doesn't typically create build artifacts, but clean vendor if exists
	@rm -rf vendor/
	@echo "✅ Clean complete"

# Docker targets
docker-build:
	docker build -t chess-php .

docker-test: docker-build
	@echo "Testing PHP implementation in Docker..."
	docker run --rm -i chess-php sh -c "printf 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit\\n' | php chess.php"

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
	@if [ ! -f chess.php.bak ]; then cp chess.php chess.php.bak; fi
	# Append bug
	@printf "\n\nfunction injected_bug_for_analysis(): int {\n    return \"string\";\n}\n" >> chess.php

fix:
	# Restore from backup
	@if [ -f chess.php.bak ]; then mv chess.php.bak chess.php; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
