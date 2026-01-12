.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - check syntax
build:
	lua5.4 -l chess.lua 2>&1 > /dev/null || lua5.4 -e "assert(loadfile('chess.lua'))"

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | lua5.4 chess.lua | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Lua static analysis..."
	lua5.4 -l chess.lua 2>&1 || lua5.4 -e "assert(loadfile('chess.lua'))"

# Clean build artifacts
clean:
	rm -f *.o *.so luac.out

# Docker targets
docker-build:
	docker build -t chess-lua .

docker-test: docker-build
	@echo "Testing Lua implementation in Docker..."
	docker run --rm -i chess-lua sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | lua5.4 chess.lua"

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
	@if [ ! -f chess.lua.bak ]; then cp chess.lua chess.lua.bak; fi
	# Append bug
	@printf "\n\nlocal function injected_bug_for_analysis()\n  local x = 1\nend\n" >> chess.lua

fix:
	# Restore from backup
	@if [ -f chess.lua.bak ]; then mv chess.lua.bak chess.lua; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
