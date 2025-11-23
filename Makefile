# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers
# Convention over Configuration: This Makefile is 100% implementation-agnostic

.PHONY: all test build analyze clean help test-all build-all analyze-all website analyze-tools list-implementations

# Auto-discover all implementations with Dockerfiles
IMPLEMENTATIONS := $(shell find implementations -mindepth 1 -maxdepth 1 -type d -exec test -f {}/Dockerfile \; -exec basename {} \; 2>/dev/null | sort)

# Default target
all: build-all test-all

# Help command
help:
	@echo "Chess Engine Docker Makefile"
	@echo "============================"
	@echo "ALL COMMANDS RUN INSIDE DOCKER CONTAINERS"
	@echo ""
	@echo "Convention-based commands (use DIR parameter):"
	@echo "  make build DIR=<impl>    - Build specific implementation (e.g., make build DIR=go)"
	@echo "  make test DIR=<impl>     - Test specific implementation (e.g., make test DIR=ruby)"
	@echo "  make analyze DIR=<impl>  - Analyze specific implementation (e.g., make analyze DIR=python)"
	@echo "  make clean DIR=<impl>    - Clean specific implementation"
	@echo ""
	@echo "Batch commands (process all implementations):"
	@echo "  make build-all           - Build all implementations in Docker"
	@echo "  make test-all            - Run all tests in Docker containers"
	@echo "  make analyze-all         - Run static analysis for all implementations"
	@echo "  make clean               - Remove all Docker images and build artifacts"
	@echo ""
	@echo "Other commands:"
	@echo "  make list-implementations - List all available implementations"
	@echo "  make website             - Generate static website in docs/"
	@echo "  make analyze-tools       - Static analysis for Python tooling (outside implementations)"
	@echo "  make help                - Show this help message"
	@echo ""
	@echo "Available implementations: $(IMPLEMENTATIONS)"

# List all available implementations
list-implementations:
	@echo "Available implementations:"
	@for impl in $(IMPLEMENTATIONS); do \
		echo "  - $$impl"; \
	done

# Generic build target (requires DIR parameter)
build:
ifndef DIR
	@echo "ERROR: DIR parameter required. Usage: make build DIR=<implementation>"
	@echo "Example: make build DIR=go"
	@echo "Available implementations: $(IMPLEMENTATIONS)"
	@exit 1
endif
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@echo "Building $(DIR) implementation in Docker..."
	@docker build -t chess-$(DIR) -f implementations/$(DIR)/Dockerfile implementations/$(DIR)

# Generic test target (requires DIR parameter)
test:
ifndef DIR
	@echo "ERROR: DIR parameter required. Usage: make test DIR=<implementation>"
	@echo "Example: make test DIR=ruby"
	@echo "Available implementations: $(IMPLEMENTATIONS)"
	@exit 1
endif
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/chess.meta" ]; then \
		echo "WARNING: No chess.meta found for '$(DIR)', using basic test"; \
		$(MAKE) build DIR=$(DIR); \
		docker run --rm chess-$(DIR) sh -c "cd /app && make test || true"; \
	else \
		RUN_CMD=$$(grep -o '"run"[[:space:]]*:[[:space:]]*"[^"]*"' implementations/$(DIR)/chess.meta | sed 's/"run"[[:space:]]*:[[:space:]]*"\([^"]*\)"/\1/'); \
		echo "Testing $(DIR) implementation in Docker..."; \
		$(MAKE) build DIR=$(DIR); \
		docker run --rm chess-$(DIR) sh -c "cd /app && echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | $$RUN_CMD"; \
	fi

# Generic analyze target (requires DIR parameter)
analyze:
ifndef DIR
	@echo "ERROR: DIR parameter required. Usage: make analyze DIR=<implementation>"
	@echo "Example: make analyze DIR=python"
	@echo "Available implementations: $(IMPLEMENTATIONS)"
	@exit 1
endif
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@echo "Analyzing $(DIR) implementation..."
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		cd implementations/$(DIR) && make analyze; \
	else \
		echo "No Makefile found in $(DIR), skipping analysis"; \
	fi

# Build all implementations
build-all:
	@echo "Building all implementations in Docker..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Building $$impl ===================="; \
		$(MAKE) build DIR=$$impl || true; \
	done
	@echo ""
	@echo "Build complete for all implementations"

# Test all implementations
test-all:
	@echo "Running all tests in Docker containers..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Testing $$impl ===================="; \
		$(MAKE) test DIR=$$impl || true; \
	done
	@echo ""
	@echo "Tests complete for all implementations"

# Analyze all implementations
analyze-all:
	@echo "Running static analysis for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Analyzing $$impl ===================="; \
		$(MAKE) analyze DIR=$$impl || true; \
	done
	@echo ""
	@echo "Analysis complete for all implementations"

# Clean up Docker images and containers
clean:
ifdef DIR
	@echo "Cleaning up Docker image for $(DIR)..."
	@docker rmi chess-$(DIR) 2>/dev/null || true
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		cd implementations/$(DIR) && make clean || true; \
	fi
else
	@echo "Cleaning up all Docker images..."
	@for impl in $(IMPLEMENTATIONS); do \
		docker rmi chess-$$impl 2>/dev/null || true; \
	done
	@echo "Cleaned up successfully"
endif

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
