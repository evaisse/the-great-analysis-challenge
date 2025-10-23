# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers

.PHONY: all test build clean help test-all build-all bugit-all fix-all analyze-with-bug-all

# Default target
all: build-all test-all

# Help command
help:
	@echo "Chess Engine Docker Makefile"
	@echo "============================"
	@echo "ALL COMMANDS RUN INSIDE DOCKER CONTAINERS"
	@echo ""
	@echo "Available targets:"
	@echo "  make test-all         - Run all tests in Docker containers"
	@echo "  make build-all        - Build all implementations in Docker"
	@echo "  make test             - Alias for test-all"
	@echo "  make build            - Alias for build-all"
	@echo "  make test-<lang>      - Test specific implementation (e.g., make test-ruby)"
	@echo "  make build-<lang>     - Build specific implementation (e.g., make build-typescript)"
	@echo "  make bugit-<lang>     - Inject bug for static analysis testing"
	@echo "  make fix-<lang>       - Fix injected bug"
	@echo "  make analyze-with-bug-<lang> - Run static analysis with bug"
	@echo "  make bugit-all        - Inject bugs in all implementations"
	@echo "  make fix-all          - Fix all injected bugs"
	@echo "  make analyze-with-bug-all - Run analysis with bugs on all implementations"
	@echo "  make clean            - Remove Docker images and build artifacts"
	@echo "  make help             - Show this help message"

# Main test target - runs all tests in Docker
test: test-all

# Main build target - builds all implementations in Docker
build: build-all

# Define list of languages
LANGUAGES := typescript ruby crystal rust julia kotlin haskell gleam dart elm rescript mojo

# Run all tests using Docker - pure Makefile implementation
test-all:
	@echo "Running all tests in Docker containers..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ] && [ -f "implementations/$$lang/Dockerfile" ]; then \
			echo "Testing $$lang implementation..."; \
			$(MAKE) test-$$lang || true; \
		fi; \
	done

# Build all Docker images - pure Makefile implementation
build-all:
	@echo "Building all Docker images..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ] && [ -f "implementations/$$lang/Dockerfile" ]; then \
			echo "Building $$lang Docker image..."; \
			$(MAKE) build-$$lang || true; \
		fi; \
	done

# Individual language targets
test-typescript:
	@echo "Testing TypeScript implementation in Docker..."
	@docker build -t chess-typescript -f implementations/typescript/Dockerfile implementations/typescript
	@docker run --rm chess-typescript sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node dist/chess.js"

test-ruby:
	@echo "Testing Ruby implementation in Docker..."
	@docker build -t chess-ruby -f implementations/ruby/Dockerfile implementations/ruby
	@docker run --rm chess-ruby sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ruby chess.rb"

test-crystal:
	@echo "Testing Crystal implementation in Docker..."
	@docker build -t chess-crystal -f implementations/crystal/Dockerfile implementations/crystal
	@docker run --rm chess-crystal sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./chess_engine"

test-rust:
	@echo "Testing Rust implementation in Docker..."
	@docker build -t chess-rust -f implementations/rust/Dockerfile implementations/rust
	@docker run --rm chess-rust sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./target/release/chess-engine"

test-julia:
	@echo "Testing Julia implementation in Docker..."
	@docker build -t chess-julia -f implementations/julia/Dockerfile implementations/julia
	@docker run --rm chess-julia sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | julia chess.jl"

test-kotlin:
	@echo "Testing Kotlin implementation in Docker..."
	@docker build -t chess-kotlin -f implementations/kotlin/Dockerfile implementations/kotlin
	@docker run --rm chess-kotlin sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | java -jar build/libs/chess.jar"

test-haskell:
	@echo "Testing Haskell implementation in Docker..."
	@docker build -t chess-haskell -f implementations/haskell/Dockerfile implementations/haskell
	@docker run --rm chess-haskell sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./chess"

test-gleam:
	@echo "Testing Gleam implementation in Docker..."
	@docker build -t chess-gleam -f implementations/gleam/Dockerfile implementations/gleam
	@docker run --rm chess-gleam sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | gleam run"

test-dart:
	@echo "Testing Dart implementation in Docker..."
	@docker build -t chess-dart -f implementations/dart/Dockerfile implementations/dart
	@docker run --rm chess-dart sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | dart run"

test-elm:
	@echo "Testing Elm implementation in Docker..."
	@docker build -t chess-elm -f implementations/elm/Dockerfile implementations/elm
	@docker run --rm chess-elm sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node src/cli.js"

test-rescript:
	@echo "Testing ReScript implementation in Docker..."
	@docker build -t chess-rescript -f implementations/rescript/Dockerfile implementations/rescript
	@docker run --rm chess-rescript sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | node lib/js/src/Chess.js"

test-mojo:
	@echo "Testing Mojo implementation in Docker..."
	@docker build -t chess-mojo -f implementations/mojo/Dockerfile implementations/mojo
	@docker run --rm chess-mojo sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | ./run_chess.sh"

# Build individual implementations
build-typescript:
	@docker build -t chess-typescript -f implementations/typescript/Dockerfile implementations/typescript

build-ruby:
	@docker build -t chess-ruby -f implementations/ruby/Dockerfile implementations/ruby

build-crystal:
	@docker build -t chess-crystal -f implementations/crystal/Dockerfile implementations/crystal

build-rust:
	@docker build -t chess-rust -f implementations/rust/Dockerfile implementations/rust

build-julia:
	@docker build -t chess-julia -f implementations/julia/Dockerfile implementations/julia

build-kotlin:
	@docker build -t chess-kotlin -f implementations/kotlin/Dockerfile implementations/kotlin

build-haskell:
	@docker build -t chess-haskell -f implementations/haskell/Dockerfile implementations/haskell

build-gleam:
	@docker build -t chess-gleam -f implementations/gleam/Dockerfile implementations/gleam

build-dart:
	@docker build -t chess-dart -f implementations/dart/Dockerfile implementations/dart

build-elm:
	@docker build -t chess-elm -f implementations/elm/Dockerfile implementations/elm

build-rescript:
	@docker build -t chess-rescript -f implementations/rescript/Dockerfile implementations/rescript

build-mojo:
	@docker build -t chess-mojo -f implementations/mojo/Dockerfile implementations/mojo

# Clean up Docker images and containers
clean:
	@echo "Cleaning up Docker images..."
	@for lang in $(LANGUAGES); do \
		docker rmi chess-$$lang 2>/dev/null || true; \
	done
	@echo "Cleaned up successfully"

# Bulk bug injection - inject bugs in all implementations
bugit-all:
	@echo "Injecting bugs in all implementations..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ]; then \
			echo "Injecting bug in $$lang..."; \
			cd implementations/$$lang && $(MAKE) bugit || true; \
			cd ../..; \
		fi; \
	done
	@echo "✅ All bugs injected"

# Bulk bug fix - fix all injected bugs
fix-all:
	@echo "Fixing all injected bugs..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ]; then \
			echo "Fixing bug in $$lang..."; \
			cd implementations/$$lang && $(MAKE) fix || true; \
			cd ../..; \
		fi; \
	done
	@echo "✅ All bugs fixed"

# Bulk analysis with bugs - run static analysis with bugs on all implementations
analyze-with-bug-all:
	@echo "Running static analysis with bugs on all implementations..."
	@mkdir -p analysis_reports
	@echo "# Static Analysis Bug Detection Report" > analysis_reports/bug_analysis_summary.md
	@echo "Generated: $$(date)" >> analysis_reports/bug_analysis_summary.md
	@echo "" >> analysis_reports/bug_analysis_summary.md
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ]; then \
			echo "Analyzing $$lang with injected bug..."; \
			cd implementations/$$lang && $(MAKE) analyze-with-bug || true; \
			cd ../..; \
			if [ -f "implementations/$$lang/.bugit/analysis_results.txt" ]; then \
				echo "## $$lang" >> analysis_reports/bug_analysis_summary.md; \
				echo "" >> analysis_reports/bug_analysis_summary.md; \
				echo '```' >> analysis_reports/bug_analysis_summary.md; \
				grep -i "unused\|error\|warning" implementations/$$lang/.bugit/analysis_results.txt | head -5 >> analysis_reports/bug_analysis_summary.md || echo "No issues detected" >> analysis_reports/bug_analysis_summary.md; \
				echo '```' >> analysis_reports/bug_analysis_summary.md; \
				echo "" >> analysis_reports/bug_analysis_summary.md; \
			fi; \
		fi; \
	done
	@echo "✅ Analysis complete. Summary saved to analysis_reports/bug_analysis_summary.md"

# Individual language bug injection targets
bugit-typescript:
	@cd implementations/typescript && $(MAKE) bugit

bugit-ruby:
	@cd implementations/ruby && $(MAKE) bugit

bugit-crystal:
	@cd implementations/crystal && $(MAKE) bugit

bugit-rust:
	@cd implementations/rust && $(MAKE) bugit

bugit-julia:
	@cd implementations/julia && $(MAKE) bugit

bugit-kotlin:
	@cd implementations/kotlin && $(MAKE) bugit

bugit-haskell:
	@cd implementations/haskell && $(MAKE) bugit

bugit-gleam:
	@cd implementations/gleam && $(MAKE) bugit

bugit-dart:
	@cd implementations/dart && $(MAKE) bugit

bugit-elm:
	@cd implementations/elm && $(MAKE) bugit

bugit-rescript:
	@cd implementations/rescript && $(MAKE) bugit

bugit-mojo:
	@cd implementations/mojo && $(MAKE) bugit

bugit-go:
	@cd implementations/go && $(MAKE) bugit

bugit-python:
	@cd implementations/python && $(MAKE) bugit

bugit-swift:
	@cd implementations/swift && $(MAKE) bugit

bugit-zig:
	@cd implementations/zig && $(MAKE) bugit

bugit-nim:
	@cd implementations/nim && $(MAKE) bugit

# Individual language bug fix targets
fix-typescript:
	@cd implementations/typescript && $(MAKE) fix

fix-ruby:
	@cd implementations/ruby && $(MAKE) fix

fix-crystal:
	@cd implementations/crystal && $(MAKE) fix

fix-rust:
	@cd implementations/rust && $(MAKE) fix

fix-julia:
	@cd implementations/julia && $(MAKE) fix

fix-kotlin:
	@cd implementations/kotlin && $(MAKE) fix

fix-haskell:
	@cd implementations/haskell && $(MAKE) fix

fix-gleam:
	@cd implementations/gleam && $(MAKE) fix

fix-dart:
	@cd implementations/dart && $(MAKE) fix

fix-elm:
	@cd implementations/elm && $(MAKE) fix

fix-rescript:
	@cd implementations/rescript && $(MAKE) fix

fix-mojo:
	@cd implementations/mojo && $(MAKE) fix

fix-go:
	@cd implementations/go && $(MAKE) fix

fix-python:
	@cd implementations/python && $(MAKE) fix

fix-swift:
	@cd implementations/swift && $(MAKE) fix

fix-zig:
	@cd implementations/zig && $(MAKE) fix

fix-nim:
	@cd implementations/nim && $(MAKE) fix

# Individual language analyze-with-bug targets
analyze-with-bug-typescript:
	@cd implementations/typescript && $(MAKE) analyze-with-bug

analyze-with-bug-ruby:
	@cd implementations/ruby && $(MAKE) analyze-with-bug

analyze-with-bug-crystal:
	@cd implementations/crystal && $(MAKE) analyze-with-bug

analyze-with-bug-rust:
	@cd implementations/rust && $(MAKE) analyze-with-bug

analyze-with-bug-julia:
	@cd implementations/julia && $(MAKE) analyze-with-bug

analyze-with-bug-kotlin:
	@cd implementations/kotlin && $(MAKE) analyze-with-bug

analyze-with-bug-haskell:
	@cd implementations/haskell && $(MAKE) analyze-with-bug

analyze-with-bug-gleam:
	@cd implementations/gleam && $(MAKE) analyze-with-bug

analyze-with-bug-dart:
	@cd implementations/dart && $(MAKE) analyze-with-bug

analyze-with-bug-elm:
	@cd implementations/elm && $(MAKE) analyze-with-bug

analyze-with-bug-rescript:
	@cd implementations/rescript && $(MAKE) analyze-with-bug

analyze-with-bug-mojo:
	@cd implementations/mojo && $(MAKE) analyze-with-bug

analyze-with-bug-go:
	@cd implementations/go && $(MAKE) analyze-with-bug

analyze-with-bug-python:
	@cd implementations/python && $(MAKE) analyze-with-bug

analyze-with-bug-swift:
	@cd implementations/swift && $(MAKE) analyze-with-bug

analyze-with-bug-zig:
	@cd implementations/zig && $(MAKE) analyze-with-bug

analyze-with-bug-nim:
	@cd implementations/nim && $(MAKE) analyze-with-bug

# Docker requirement enforcement
.DEFAULT:
	@echo "ERROR: Direct execution not allowed!"
	@echo "All tests and builds MUST run inside Docker containers."
	@echo "Use 'make help' to see available Docker-based commands."
	@exit 1