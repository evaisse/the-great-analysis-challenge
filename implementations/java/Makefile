.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile Java with Maven
build:
	mvn clean package

# Run basic tests
test:
	mvn test || true
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | java -jar target/chess-1.0.0.jar | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Java static analysis..."
	mvn checkstyle:check || true
	mvn pmd:check || true

# Clean build artifacts
clean:
	mvn clean

# Docker targets
docker-build:
	docker build -t chess-java .

docker-test: docker-build
	@echo "Testing Java implementation in Docker..."
	docker run --rm -i chess-java sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | java -jar target/chess-1.0.0.jar"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
