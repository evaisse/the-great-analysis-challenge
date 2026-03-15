# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers
# Convention over Configuration: This Makefile is 100% implementation-agnostic

.PHONY: all image test-chess-engine test-unit-contract test build analyze bugit fix benchmark-analysis-error clean help website analyze-tools list-implementations verify workflow validate-website-metadata install-hooks benchmark-stress benchmark-concurrency

# Auto-discover all implementations with Dockerfiles
IMPLEMENTATIONS := $(shell find implementations -mindepth 1 -maxdepth 1 -type d -exec test -f {}/Dockerfile \; -exec basename {} \; 2>/dev/null | sort)
TRACK ?= v1
PROFILE ?= quick
TIMEOUT ?= 1800
STRICT ?= 0

# Default target
all: image build test test-chess-engine

# Help command
help:
	@echo "Chess Engine Docker Makefile"
	@echo "============================"
	@echo "ALL COMMANDS RUN INSIDE DOCKER CONTAINERS"
	@echo ""
	@echo "Convention-based commands (use DIR parameter):"
	@echo "  make image [DIR=<impl>]             - Build Docker image(s) only"
	@echo "  make build [DIR=<impl>]             - Run compilation command(s) only"
	@echo "  make analyze [DIR=<impl>]           - Run static analysis/lint command(s) only"
	@echo "  make bugit DIR=<impl>               - Inject a reproducible static-analysis bug in a benchmark workspace"
	@echo "  make fix DIR=<impl>                 - Restore the injected benchmark bug in that workspace"
	@echo "  make test [DIR=<impl>]              - Run internal implementation test command(s) only"
	@echo "  make test-unit-contract [DIR=<impl>] [STRICT=1]"
	@echo "                                     - Run shared unit-contract parity suite (STRICT=1 fails on missing adapters)"
	@echo "  make test-chess-engine [DIR=<impl>] [TRACK=v1|v2-foundation|v2-functional|v2-system|v2-full|v3-book]"
	@echo "                                     - Run shared chess engine suite only"
	@echo "  make benchmark-stress [DIR=<impl>] [TRACK=...] [PROFILE=quick|full] [TIMEOUT=<s>]"
	@echo "                                     - Run performance benchmark suite with normalized metrics"
	@echo "  make benchmark-concurrency [DIR=<impl>] [PROFILE=quick|full]"
	@echo "                                     - Run concurrency safety harness"
	@echo "  make benchmark-analysis-error DIR=<impl>"
	@echo "                                     - Benchmark analyzer behavior before/after a reproducible injected bug"
	@echo "  make verify [DIR=<impl>]            - Verify implementation structure"
	@echo "  make workflow [DIR=<impl>]          - Run full workflow (verify, image, build, analyze, test, test-chess-engine)"
	@echo "  make clean [DIR=<impl>]             - Clean implementation image(s)"
	@echo ""
	@echo "If DIR is omitted, the command runs for ALL implementations."
	@echo ""
	@echo "Other commands:"
	@echo "  make list-implementations - List all available implementations"
	@echo "  make analyze-tools        - Static analysis for Python tooling (outside implementations)"
	@echo "  make help                 - Show this help message"
	@echo ""
	@echo "Available implementations: $(IMPLEMENTATIONS)"

# List all available implementations
list-implementations:
	@for impl in $(IMPLEMENTATIONS); do \
		echo "  - $$impl"; \
	done

# Build docker image target
image:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@echo "Building image for $(DIR) implementation in Docker..."
	@docker build -t chess-$(DIR) -f implementations/$(DIR)/Dockerfile implementations/$(DIR)
else
	@echo "Building images for all implementations in Docker..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Building image $$impl ===================="; \
		if ! $(MAKE) image DIR=$$impl; then \
			echo "Image build failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Image build complete for all implementations"
endif

# Build (compilation only) target
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
	@python3 scripts/run_metadata_phase.py --impl implementations/$(DIR) --phase build --image chess-$(DIR)
else
	@echo "Running build phase for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Build $$impl ===================="; \
		if ! $(MAKE) build DIR=$$impl; then \
			echo "Build failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Build phase complete for all implementations"
endif

# Analyze (lint/static checks only) target
analyze:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@python3 scripts/run_metadata_phase.py --impl implementations/$(DIR) --phase analyze --image chess-$(DIR)
else
	@echo "Running analysis phase for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Analyze $$impl ===================="; \
		if ! $(MAKE) analyze DIR=$$impl; then \
			echo "Analyze failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Analysis phase complete for all implementations"
endif

# Inject a reproducible analyzer-facing bug in an extracted Docker workspace
bugit:
ifndef DIR
	@echo "ERROR: DIR is required (e.g. make bugit DIR=python)"
	@exit 1
else
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@python3 scripts/error_analysis_benchmark.py bugit --impl implementations/$(DIR) --image chess-$(DIR)
endif

# Restore the reproducible benchmark bug in the extracted Docker workspace
fix:
ifndef DIR
	@echo "ERROR: DIR is required (e.g. make fix DIR=python)"
	@exit 1
else
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@python3 scripts/error_analysis_benchmark.py fix --impl implementations/$(DIR) --image chess-$(DIR)
endif

# Benchmark analyzer output with an injected bug and a repaired workspace
benchmark-analysis-error:
ifndef DIR
	@echo "ERROR: DIR is required (e.g. make benchmark-analysis-error DIR=python)"
	@exit 1
else
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@python3 scripts/error_analysis_benchmark.py benchmark --impl implementations/$(DIR) --image chess-$(DIR)
endif

# Test (implementation internal tests only) target
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
	@python3 scripts/run_metadata_phase.py --impl implementations/$(DIR) --phase test --image chess-$(DIR)
else
	@echo "Running internal tests for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Test $$impl ===================="; \
		if ! $(MAKE) test DIR=$$impl; then \
			echo "Internal tests failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Internal tests complete for all implementations"
endif

# Shared unit-level contract tests target
test-unit-contract:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@echo "Running unit contract suite for $(DIR)..."
	@STRICT_FLAG=""; \
	if [ "$(STRICT)" = "1" ]; then STRICT_FLAG="--require-contract"; fi; \
	python3 test/unit_contract_harness.py \
		--impl implementations/$(DIR) \
		--docker-image chess-$(DIR) \
		$$STRICT_FLAG
else
	@echo "Running shared unit contract suite for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Unit Contract Suite $$impl ===================="; \
		if ! $(MAKE) test-unit-contract DIR=$$impl STRICT=$(STRICT); then \
			echo "Unit contract suite failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Shared unit contract suite complete for all implementations"
endif

# Shared chess engine protocol + behavior tests target
test-chess-engine:
ifdef DIR
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@if [ ! -f "implementations/$(DIR)/Dockerfile" ]; then \
		echo "ERROR: No Dockerfile found for '$(DIR)'"; \
		exit 1; \
	fi
	@echo "Running chess engine harness for $(DIR) (track=$(TRACK))..."
	@python3 test/test_harness.py \
		--impl implementations/$(DIR) \
		--track $(TRACK) \
		--docker-image chess-$(DIR)
else
	@echo "Running shared chess engine suite for all implementations..."
	@for impl in $(IMPLEMENTATIONS); do \
		echo ""; \
		echo "==================== Chess Engine Suite $$impl ===================="; \
		if ! $(MAKE) test-chess-engine DIR=$$impl; then \
			echo "Chess engine suite failed for $$impl. Stopping."; \
			exit 1; \
		fi; \
	done
	@echo ""
	@echo "Shared chess engine suite complete for all implementations"
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
		echo "Step 1/6: Verify"; \
		run_with_timeout 60s $(MAKE) verify DIR=$(DIR); \
		echo "Step 2/6: Image"; \
		run_with_timeout 600s $(MAKE) image DIR=$(DIR); \
		echo "Step 3/6: Build"; \
		run_with_timeout 300s $(MAKE) build DIR=$(DIR); \
		echo "Step 4/6: Analyze"; \
		run_with_timeout 300s $(MAKE) analyze DIR=$(DIR); \
		echo "Step 5/6: Internal tests"; \
		run_with_timeout 300s $(MAKE) test DIR=$(DIR); \
		echo "Step 6/6: Chess engine suite"; \
		run_with_timeout 600s $(MAKE) test-chess-engine DIR=$(DIR); \
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

# Static analysis for Python tooling outside implementations directory
analyze-tools:
	@echo "Running Python tooling static analysis..."
	@python3 scripts/analyze_python_tools.py

# Install git hooks
install-hooks:
	@chmod +x scripts/setup-hooks.sh scripts/pre-commit.sh
	@./scripts/setup-hooks.sh

# Performance benchmark suite with optional track/profile
benchmark-stress:
ifndef DIR
	@echo "ERROR: DIR is required (e.g. make benchmark-stress DIR=python TRACK=v2-foundation PROFILE=quick)"
	@exit 1
endif
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@$(MAKE) build DIR=$(DIR)
	@mkdir -p reports
	@echo "Running stress benchmark for $(DIR) (track=$(TRACK), profile=$(PROFILE), timeout=$(TIMEOUT)s)..."
	@python3 test/performance_test.py \
		--impl implementations/$(DIR) \
		--track $(TRACK) \
		--profile $(PROFILE) \
		--timeout $(TIMEOUT) \
		--json reports/$(DIR).json

# Concurrency safety harness
benchmark-concurrency:
ifndef DIR
	@echo "ERROR: DIR is required (e.g. make benchmark-concurrency DIR=python PROFILE=quick)"
	@exit 1
endif
	@if [ ! -d "implementations/$(DIR)" ]; then \
		echo "ERROR: Implementation '$(DIR)' not found"; \
		exit 1; \
	fi
	@$(MAKE) build DIR=$(DIR)
	@mkdir -p reports
	@echo "Running concurrency harness for $(DIR) (profile=$(PROFILE))..."
	@python3 test/concurrency_harness.py \
		--impl implementations/$(DIR) \
		--profile $(PROFILE) \
		--skip-build \
		--output reports/$(DIR)-concurrency.json
