.PHONY: all build test analyze clean docker-build docker-test

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
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"




# New targets for error analysis
bugit:
	# Check if backup exists, if not create it
	@if [ ! -f src/chess.ts.bak ]; then cp src/chess.ts src/chess.ts.bak; fi
	# Append bug
	@printf "\n\nfunction injectedBugForAnalysis() {\n    const x: number = \"string\";\n}\n" >> src/chess.ts

fix:
	# Restore from backup
	@if [ -f src/chess.ts.bak ]; then mv src/chess.ts.bak src/chess.ts; fi

analyze-with-bug:
	$(MAKE) bugit
	@echo "Running analysis with bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'analyze'], stdout=open('analysis_bug.log', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('analysis_time.log', 'w'))"
	@echo "Analysis complete. Output in analysis_bug.log. Time in analysis_time.log."
	@echo "Fixing bug..."
	@python3 -c "import time, subprocess; start = time.time(); subprocess.run(['make', 'fix'], stdout=open('fix_log.txt', 'w'), stderr=subprocess.STDOUT); print(f'{time.time() - start:.4f}', file=open('fix_time.log', 'w'))"
	@echo "Fix complete. Time in fix_time.log."
