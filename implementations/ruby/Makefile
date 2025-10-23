.PHONY: all build test analyze clean docker-build docker-test bugit fix analyze-with-bug

# Default target - build the chess engine
all: build

# Build target - install dependencies
build:
	bundle install

# Run basic tests
test:
	ruby -c chess.rb
	@echo "Running basic functionality test..."
	@echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | ruby chess.rb | tail -1 | grep -q "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2" && echo "✅ Basic test passed" || echo "❌ Basic test failed"

# Static analysis and code quality
analyze:
	@echo "Running Ruby static analysis..."
	bundle exec rubocop chess.rb lib/*.rb || true
	ruby -w chess.rb -c 2>/dev/null || true

# Inject a bug for static analysis testing
bugit:
	@echo "Injecting bug for static analysis testing..."
	@mkdir -p .bugit
	@if [ ! -f .bugit/BUGGED ]; then \
		if [ -f lib/board.rb ]; then \
			cp lib/board.rb .bugit/board.rb.backup; \
			sed -i '2a UNUSED_DEBUG_VARIABLE = "This should be detected by rubocop"' lib/board.rb; \
		else \
			cp chess.rb .bugit/chess.rb.backup; \
			sed -i '2a UNUSED_DEBUG_VARIABLE = "This should be detected by rubocop"' chess.rb; \
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
		if [ -f .bugit/board.rb.backup ]; then \
			cp .bugit/board.rb.backup lib/board.rb; \
		elif [ -f .bugit/chess.rb.backup ]; then \
			cp .bugit/chess.rb.backup chess.rb; \
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
	@echo "--- Rubocop Analysis ---" >> .bugit/analysis_results.txt
	@(time bundle exec rubocop chess.rb lib/*.rb 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo "" >> .bugit/analysis_results.txt
	@echo "--- Ruby Warnings Analysis ---" >> .bugit/analysis_results.txt
	@(time ruby -w chess.rb -c 2>&1) >> .bugit/analysis_results.txt 2>&1 || true
	@echo ""
	@echo "✅ Analysis complete. Results saved to .bugit/analysis_results.txt"
	@echo ""
	@echo "Summary of detected issues:"
	@grep -i "unused\|error\|warning" .bugit/analysis_results.txt | head -10 || echo "No issues found in summary"

# Clean build artifacts
clean:
	bundle clean || true
	rm -rf .bundle/

# Docker targets
docker-build:
	docker build -t chess-ruby .

docker-test: docker-build
	@echo "Testing Ruby implementation in Docker..."
	docker run --rm -i chess-ruby sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | ruby chess.rb"

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