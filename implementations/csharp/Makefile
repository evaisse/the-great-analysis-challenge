.PHONY: all build test analyze clean docker-build docker-test

# Default target - build the chess engine
all: build

# Build target - compile C# with dotnet
build:
	dotnet build -c Release

# Run basic tests
test:
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | dotnet run --no-build -c Release | grep -q "FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running C# static analysis..."
	dotnet format --verify-no-changes || true

# Clean build artifacts
clean:
	dotnet clean
	rm -rf bin/ obj/

# Docker targets
docker-build:
	docker build -t chess-csharp .

docker-test: docker-build
	@echo "Testing C# implementation in Docker..."
	@printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | docker run --rm -i chess-csharp dotnet bin/Release/net8.0/chess.dll | grep -q "FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Docker test passed" || echo "❌ Docker test failed"

# Help target
help:
	@echo "Available targets:"
	@echo "  make         - Build the chess engine"
	@echo "  make test    - Run tests"
	@echo "  make analyze - Run static analysis"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-test  - Test in Docker"
