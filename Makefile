# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers

.PHONY: all test build clean help test-all build-all website analyze-tools

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
	@echo "  make analyze-tools    - Static analysis for Python tooling (outside implementations)"
	@echo "  make website          - Generate static website in docs/"
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

# Generate static website
website:
	@echo "Generating static website..."
	@python3 build_website.py
	@echo "Website generated in docs/"
	@echo "To preview: cd docs && python3 -m http.server 8080"

# Static analysis for Python tooling outside implementations directory
analyze-tools:
	@echo "Running Python tooling static analysis..."
	@python3 scripts/analyze_python_tools.py

# Docker requirement enforcement
.DEFAULT:
	@echo "ERROR: Direct execution not allowed!"
	@echo "All tests and builds MUST run inside Docker containers."
	@echo "Use 'make help' to see available Docker-based commands."
	@exit 1
