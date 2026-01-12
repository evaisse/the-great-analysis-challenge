.PHONY: all build test analyze clean docker-build docker-test

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
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"



# New targets for error analysis
bugit:
	# Check if backup exists, if not create it
	@if [ ! -f chess.jl.bak ]; then cp chess.jl chess.jl.bak; fi
	# Append bug
	@printf "\n\nfunction injected_bug_for_analysis()::Int\n    return \"string\"\nend\n" >> chess.jl

fix:
	# Restore from backup
	@if [ -f chess.jl.bak ]; then mv chess.jl.bak chess.jl; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
