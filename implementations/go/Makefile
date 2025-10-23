.PHONY: all build test analyze clean docker-build docker-test bugit fix analyze-with-bug

# Default target - build the chess engine
all: build

# Build target - compile Go binary
build:
	go build -o chess .

# Run basic tests
test:
	go test ./...
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ./chess | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Go static analysis..."
	go fmt ./...
	go vet ./...
	golint ./... || true
	go mod tidy

# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		cp board.go .bugit/board.go.backup 2>/dev/null || cp main.go .bugit/main.go.backup; \
		if [ -f board.go ]; then \
			sed -i '1a var unusedDebugVariable = "This should be detected by go vet"' board.go; \
		else \
			sed -i '/^package main/a var unusedDebugVariable = "This should be detected by go vet"' main.go; \
		fi; \
		touch .bugit/BUGGED; \
		echo "✅ Bug injected"; \
	else \
		echo "⚠️  Bug already injected. Run 'make fix' first."; \
	fi

# Fix the injected bug
fix:
	@echo "Fixing injected bug..."
	@if [ -f .bugit/BUGGED ]; then \
		if [ -f .bugit/board.go.backup ]; then \
			cp .bugit/board.go.backup board.go; \
		elif [ -f .bugit/main.go.backup ]; then \
			cp .bugit/main.go.backup main.go; \
		fi; \
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
	@echo "--- Go Fmt Analysis ---" >> .bugit/analysis_results.txt
	@(time go fmt ./... 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Go Vet Analysis ---" >> .bugit/analysis_results.txt
	@(time go vet ./... 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Go Lint Analysis ---" >> .bugit/analysis_results.txt
	@(time golint ./... 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

# Clean build artifacts
clean:
	go clean
	rm -f chess

# Docker targets
docker-build:
	docker build -t chess-go .

docker-test: docker-build
	@echo "Testing Go implementation in Docker..."
	docker run --rm -i chess-go sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ./chess"

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