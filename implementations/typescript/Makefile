.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile TypeScript to JavaScript
build:
	@echo "⏱️  Build started..."
	@START_TIME=$$(date +%s); \
	npm install && \
	npm run build; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Build duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Run basic tests
test:
	@echo "⏱️  Test started..."
	@START_TIME=$$(date +%s); \
	npm test; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Test duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Static analysis and code quality
analyze:
	@echo "⏱️  Analyze started..."
	@START_TIME=$$(date +%s); \
	echo "Running TypeScript static analysis..." && \
	npm install && \
	npm run lint && \
	npx tsc --noEmit && \
	npx prettier --check src/*.ts; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Analyze duration: $${DURATION}s"; \
	exit $$EXIT_CODE

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
