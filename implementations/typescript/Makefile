.PHONY: all build test analyze clean docker-build docker-test bugit fix analyze-with-bug

# Default target - build the chess engine
all: build

# Build target - compile TypeScript to JavaScript
build:
	npm install
	npm run build

# Run basic tests
test:
	npm test

# Static analysis and code quality
analyze:
	@echo "Running TypeScript static analysis..."
	npm install
	npm run lint
	npx tsc --noEmit
	npx prettier --check src/*.ts

# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		cp src/board.ts .bugit/board.ts.backup; \
		sed -i '1a const unusedDebugVariable: string = "This should be detected by TSLint";' src/board.ts; \
		touch .bugit/BUGGED; \
		echo "✅ Bug injected in src/board.ts"; \
	else \
		echo "⚠️  Bug already injected. Run 'make fix' first."; \
	fi

# Fix the injected bug
fix:
	@echo "Fixing injected bug..."
	@if [ -f .bugit/BUGGED ]; then \
		cp .bugit/board.ts.backup src/board.ts; \
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
	@echo "--- ESLint Analysis ---" >> .bugit/analysis_results.txt
	@(time npm run lint 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- TypeScript Compiler Analysis ---" >> .bugit/analysis_results.txt
	@(time npx tsc --noEmit 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Prettier Check ---" >> .bugit/analysis_results.txt
	@(time npx prettier --check src/*.ts 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

# Clean build artifacts
clean:
	rm -rf dist/
	rm -rf node_modules/
	npm cache clean --force || true

# Docker targets
docker-build:
	docker build -t chess-typescript .

docker-test: docker-build
	@echo "Testing TypeScript implementation in Docker..."
	docker run --rm -i chess-typescript sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | node dist/chess.js"

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
