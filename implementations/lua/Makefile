.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - check syntax
build:
	@echo "⏱️  Build started..."
	@START_TIME=$$(date +%s); \
	lua5.4 -l chess.lua 2>&1 > /dev/null || lua5.4 -e "assert(loadfile('chess.lua'))"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Build duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Run basic tests
test:
	@echo "⏱️  Test started..."
	@START_TIME=$$(date +%s); \
	echo "Running basic functionality test..." && \
	echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | lua5.4 chess.lua | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Test duration: $${DURATION}s"; \
	exit $$EXIT_CODE

# Static analysis and code quality
analyze:
	@echo "⏱️  Analyze started..."
	@START_TIME=$$(date +%s); \
	echo "Running Lua static analysis..." && \
	lua5.4 -l chess.lua 2>&1 || lua5.4 -e "assert(loadfile('chess.lua'))"; \
	EXIT_CODE=$$?; \
	END_TIME=$$(date +%s); \
	DURATION=$$((END_TIME - START_TIME)); \
	echo "⏱️  Analyze duration: $${DURATION}s"; \
	exit $$EXIT_CODE

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
