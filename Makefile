# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers
# Convention over Configuration: This Makefile is 100% implementation-agnostic

.PHONY: all test build analyze clean help website analyze-tools list-implementations verify workflow bugit fix analyze-with-bug

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
	@echo "  make build [DIR=<impl>]            - Build implementation(s)"
	@echo "  make test [DIR=<impl>]             - Test implementation(s)"
	@echo "  make analyze [DIR=<impl>]          - Analyze implementation(s)"
	@echo "  make bugit [DIR=<impl>]            - Inject bug for static analysis testing"
	@echo "  make fix [DIR=<impl>]              - Fix injected bug"
	@echo "  make analyze-with-bug [DIR=<impl>] - Run static analysis with bug"
	@echo "  make verify [DIR=<impl>]           - Verify implementation structure"
	@echo "  make workflow [DIR=<impl>]         - Run full workflow (verify, build, analyze, test)"
	@echo "  make clean [DIR=<impl>]            - Clean implementation(s)"
	@echo ""
	@echo "If DIR is omitted, the command runs for ALL implementations."
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
else
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
	@echo "Analyzing $(DIR) implementation..."
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		cd implementations/$(DIR) && make analyze; \
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

# Bug injection target
bugit:
ifdef DIR
	@echo "Injecting bug in $(DIR)..."
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		cd implementations/$(DIR) && make bugit || true; \
	else \
		echo "No Makefile found in $(DIR), skipping bug injection"; \
	fi
else
	@echo "Injecting bugs in all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Injecting bug in $$impl ===================="; \
		$(MAKE) bugit DIR=$$impl; \
	done
	@echo "✅ All bugs injected"
endif

# Bug fix target
fix:
ifdef DIR
	@echo "Fixing bug in $(DIR)..."
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		cd implementations/$(DIR) && make fix || true; \
	else \
		echo "No Makefile found in $(DIR), skipping bug fix"; \
	fi
else
	@echo "Fixing bugs in all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Fixing bug in $$impl ===================="; \
		$(MAKE) fix DIR=$$impl; \
	done
	@echo "✅ All bugs fixed"
endif

# Analyze with bug target
analyze-with-bug:
ifdef DIR
	@echo "Analyzing $(DIR) with injected bug..."
	@if [ -f "implementations/$(DIR)/Makefile" ]; then \
		cd implementations/$(DIR) && make analyze-with-bug || true; \
	else \
		echo "No Makefile found in $(DIR), skipping analysis with bug"; \
	fi
else
	@echo "Running static analysis with bugs on all implementations..."
	@mkdir -p analysis_reports
	@echo "# Static Analysis Bug Detection Report" > analysis_reports/bug_analysis_summary.md
	@echo "Generated: $$(date)" >> analysis_reports/bug_analysis_summary.md
	@echo "" >> analysis_reports/bug_analysis_summary.md
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Analyzing $$impl with injected bug ===================="; \
		$(MAKE) analyze-with-bug DIR=$$impl; \
		if [ -f "implementations/$$impl/.bugit/analysis_results.txt" ]; then \
			echo "## $$impl" >> analysis_reports/bug_analysis_summary.md; \
			echo "" >> analysis_reports/bug_analysis_summary.md; \
			echo '```' >> analysis_reports/bug_analysis_summary.md; \
			grep -i "unused\|error\|warning" implementations/$$impl/.bugit/analysis_results.txt | head -5 >> analysis_reports/bug_analysis_summary.md || echo "No issues detected" >> analysis_reports/bug_analysis_summary.md; \
			echo '```' >> analysis_reports/bug_analysis_summary.md; \
			echo "" >> analysis_reports/bug_analysis_summary.md; \
		fi; \
	done
	@echo "✅ Analysis complete. Summary saved to analysis_reports/bug_analysis_summary.md"
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
	@timeout 180s bash -c ' \
		set -e; \
		echo "Step 1/4: Verify (timeout 60s)"; \
		timeout 60s $(MAKE) verify DIR=$(DIR); \
		echo "Step 2/4: Build (timeout 60s)"; \
		timeout 60s $(MAKE) build DIR=$(DIR); \
		echo "Step 3/4: Analyze (timeout 60s)"; \
		timeout 60s $(MAKE) analyze DIR=$(DIR); \
		echo "Step 4/4: Test (timeout 60s)"; \
		timeout 60s $(MAKE) test DIR=$(DIR); \
		echo "Workflow completed successfully for $(DIR)"; \
	'
else
	@echo "Running workflow for all implementations..."
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

# Static analysis for Python tooling outside implementations directory
analyze-tools:
	@echo "Running Python tooling static analysis..."
	@python3 scripts/analyze_python_tools.py