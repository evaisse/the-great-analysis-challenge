# Makefile for Chess Engine Implementations
# IMPORTANT: All tests and builds MUST run inside Docker containers

.PHONY: all test build clean help website analyze analyze-tools

# Default target
all: build test

# Define list of languages
LANGUAGES := typescript ruby crystal rust julia kotlin haskell gleam dart elm rescript mojo lua nim php python swift zig go

# Macros for build, test, and analyze logic
define BUILD_IMPL
	@echo "Building $(1) implementation in Docker..."
	@docker build -t chess-$(1) -f implementations/$(1)/Dockerfile implementations/$(1)
endef

define TEST_IMPL
	@echo "Testing $(1) implementation in Docker..."
	@$(MAKE) build DIR=$(1)
	@# We rely on the Dockerfile to define the correct CMD/ENTRYPOINT
	@# We pipe the test commands to stdin
	@docker run -i --rm chess-$(1) sh -c "cd /app && printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | /bin/sh -c \"\$$(grep -E '^(CMD|ENTRYPOINT)' implementations/$(1)/Dockerfile | sed 's/.*\[//;s/\].*//;s/\"//g;s/,/ /g')\"" || \
	 docker run -i --rm chess-$(1)
endef

# Wait, the previous TEST_IMPL logic in the plan was simpler:
# @docker run -i --rm chess-$(1)
# But wait, if the ENTRYPOINT is set, `docker run -i` works.
# If CMD is set, `docker run -i` works.
# The only issue is if the Dockerfile has NO CMD/ENTRYPOINT (which I verified they do).
# AND if the CMD requires arguments that are not in the Dockerfile (e.g. `node dist/chess.js` vs just `node`).
# But I verified that the Dockerfiles contain the full command.

# However, there is a catch: `docker run -i` connects stdin.
# The previous command was: `docker run ... sh -c "printf ... | <CMD>"`
# If I just do `printf ... | docker run -i ...`, it pipes to the container's PID 1 stdin.
# This is EXACTLY what we want if the container runs the engine directly.
# So `printf ... | docker run -i --rm chess-$(1)` should work.

# Let's stick to the simple plan.

define TEST_IMPL
	@echo "Testing $(1) implementation in Docker..."
	@$(MAKE) build DIR=$(1)
	@printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | docker run -i --rm chess-$(1)
endef

define ANALYZE_IMPL
	@echo "Analyzing $(1) implementation..."
	@# Placeholder for future language-specific analysis tools
	@echo "No specific analysis tool configured for $(1) yet."
endef

# Help command
help:
	@echo "Chess Engine Docker Makefile"
	@echo "============================"
	@echo "ALL COMMANDS RUN INSIDE DOCKER CONTAINERS"
	@echo ""
	@echo "Usage:"
	@echo "  make test [DIR=<lang>]    - Run tests (all or specific language)"
	@echo "  make build [DIR=<lang>]   - Build images (all or specific language)"
	@echo "  make analyze [DIR=<lang>] - Run static analysis (all or specific language)"
	@echo "  make clean                - Remove Docker images"
	@echo "  make website              - Generate static website"
	@echo ""
	@echo "Examples:"
	@echo "  make test                 - Test all languages"
	@echo "  make test DIR=go          - Test only Go implementation"
	@echo "  make build DIR=rust       - Build only Rust implementation"

# Main test target
test:
ifdef DIR
	$(call TEST_IMPL,$(DIR))
else
	@echo "Running all tests in Docker containers..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ] && [ -f "implementations/$$lang/Dockerfile" ]; then \
			$(MAKE) test DIR=$$lang || true; \
		fi; \
	done
endif

# Main build target
build:
ifdef DIR
	$(call BUILD_IMPL,$(DIR))
else
	@echo "Building all Docker images..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ] && [ -f "implementations/$$lang/Dockerfile" ]; then \
			$(MAKE) build DIR=$$lang || true; \
		fi; \
	done
endif

# Main analyze target
analyze:
ifdef DIR
	$(call ANALYZE_IMPL,$(DIR))
else
	@echo "Analyzing all implementations..."
	@for lang in $(LANGUAGES); do \
		if [ -d "implementations/$$lang" ]; then \
			$(MAKE) analyze DIR=$$lang || true; \
		fi; \
	done
endif

# Clean up Docker images
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

# Static analysis for Python tooling
analyze-tools:
	@echo "Running Python tooling static analysis..."
	@python3 scripts/analyze_python_tools.py

# Docker requirement enforcement
.DEFAULT:
	@echo "ERROR: Direct execution not allowed!"
	@echo "All tests and builds MUST run inside Docker containers."
	@echo "Use 'make help' to see available Docker-based commands."
	@exit 1
