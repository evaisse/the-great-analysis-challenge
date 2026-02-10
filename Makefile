# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers
# Convention over Configuration: This Makefile is 100% implementation-agnostic

.PHONY: all test build analyze clean help website analyze-tools list-implementations verify workflow validate-website-metadata

# Auto-discover all implementations with Dockerfiles
IMPLEMENTATIONS := $(shell find implementations -mindepth 1 -maxdepth 1 -type d -exec test -f {}/Dockerfile \; -exec basename {} \; 2>/dev/null | sort)

# Default target
all: build test

# Help command
help:
	@echo "Chess Engine Docker Makefile"
	@echo "============================"
	@echo "ALL COMMANDS RUN INSIDE DOCKER CONTAINERS"
	@echo ""
	@echo "Convention-based commands (use DIR parameter):"
	@echo "  make build [DIR=<impl>]    - Build implementation(s)"
	@echo "  make test [DIR=<impl>]     - Test implementation(s)"
	@echo "  make analyze [DIR=<impl>]  - Analyze implementation(s)"
	@echo "  make verify [DIR=<impl>]   - Verify implementation structure"
	@echo "  make workflow [DIR=<impl>] - Run full workflow (verify, build, analyze, test)"
	@echo "  make clean [DIR=<impl>]    - Clean implementation(s)"
	@echo ""
	@echo "If DIR is omitted, the command runs for ALL implementations."
	@echo ""
	@echo "Other commands:"
	@echo "  make list-implementations - List all available implementations"
	@echo "  make website             - Generate static website in docs/"
	@echo "  make validate-website-metadata - Validate website metadata completeness"
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

# Build target
build:
ifdef DIR
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
else
	@echo "Building all implementations in Docker..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Building $$impl ===================="; \
		if ! $(MAKE) build DIR=$$impl; then \
			echo "Build failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Build complete for all implementations"
endif

# Test target
test:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@RUN_CMD=$$(./scripts/get_metadata.py implementations/$(DIR) --field run); \
	if [ -z "$$RUN_CMD" ]; then \
		echo "WARNING: No run command found for '$(DIR)', using basic test"; \
		$(MAKE) build DIR=$(DIR); \
		docker run --rm chess-$(DIR) sh -c "cd /app && make test || true"; \
	else \
		echo "Testing $(DIR) implementation in Docker..."; \
		$(MAKE) build DIR=$(DIR); \
		docker run --rm chess-$(DIR) sh -c "cd /app && printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | $$RUN_CMD"; \
		echo "Running internal tests for $(DIR) in Docker..."; \
		docker run --rm chess-$(DIR) make test; \
	fi
else
	@echo "Validating website metadata..."
	@./workflow validate-website-metadata
	@echo "Running all tests in Docker containers..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Testing $$impl ===================="; \
		if ! $(MAKE) test DIR=$$impl; then \
			echo "Tests failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Tests complete for all implementations"
endif

# Analyze target
analyze:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@echo "Analyzing $(DIR) implementation in Docker..."
	@$(MAKE) build DIR=$(DIR)
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		docker run --rm chess-$(DIR) make analyze; \
	else \
		echo "No Makefile found in $(DIR), skipping analysis"; \
	fi
else
	@echo "Running static analysis for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Analyzing $$impl ===================="; \
		if ! $(MAKE) analyze DIR=$$impl; then \
			echo "Analysis failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Analysis complete for all implementations"
endif

# Verify target
verify:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@echo "Verifying $(DIR) implementation..."
	@python3 test/verify_implementations.py --implementation $(DIR)
else
	@echo "Verifying all implementations..."
	@python3 test/verify_implementations.py
endif

# Workflow target
workflow:
ifdef DIR
	@echo "Starting workflow for $(DIR)..."
	@bash -c ' \
		set -e; \
		TIMEOUT_CMD=$$(command -v timeout 2>/dev/null || command -v gtimeout 2>/dev/null || true); \
		run_with_timeout() { \
			if [ -z "$$TIMEOUT_CMD" ]; then \
				shift; "$$@"; \
			else \
				"$$TIMEOUT_CMD" "$$@"; \
			fi; \
		}; \
		echo "Step 1/4: Verify"; \
		run_with_timeout 60s $(MAKE) verify DIR=$(DIR); \
		echo "Step 2/4: Build"; \
		run_with_timeout 60s $(MAKE) build DIR=$(DIR); \
		echo "Step 3/4: Analyze"; \
		run_with_timeout 60s $(MAKE) analyze DIR=$(DIR); \
		echo "Step 4/4: Test"; \
		run_with_timeout 60s $(MAKE) test DIR=$(DIR); \
		echo "Workflow completed successfully for $(DIR)"; \
	'
else
	@echo "Running workflow for all implementations..."
	@echo "Validating website metadata..."
	@./workflow validate-website-metadata
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Workflow $$impl ===================="; \
		if ! $(MAKE) workflow DIR=$$impl; then \
			echo "Workflow failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Workflow complete for all implementations"
endif

# Clean target
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

# Validate website metadata completeness
validate-website-metadata:
	@./workflow validate-website-metadata

# Static analysis for Python tooling outside implementations directory
analyze-tools:
	@echo "Running Python tooling static analysis..."
	@python3 scripts/analyze_python_tools.py
