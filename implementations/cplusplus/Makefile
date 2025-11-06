.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile C++ binary
build:
	g++ -std=c++17 -O2 -Wall -Wextra -o chess chess.cpp

# Run basic tests
test: build
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./chess | tail -3 | head -1 | grep -q "FEN:" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running C++ static analysis..."
	g++ -std=c++17 -Wall -Wextra -Wpedantic -fsyntax-only chess.cpp
	@echo "Static analysis complete"

# Clean build artifacts
clean:
	rm -f chess *.o

# Docker targets
docker-build:
	docker build -t chess-cplusplus .

docker-test: docker-build
	@echo "Testing C++ implementation in Docker..."
	docker run --rm -i chess-cplusplus sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./chess"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
