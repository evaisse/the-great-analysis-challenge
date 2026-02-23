---
name: make-workflow-validation
description: Explain or run the complete implementation validation workflow in this repo using `make workflow DIR=impl`. Use when asked how to validate a single implementation end-to-end, confirm the steps (verify/build/analyze/test), troubleshoot workflow failures, or document the full validation command and required inputs.
---

# Make Workflow Validation

## Overview

Run the full Docker-based validation pipeline for one implementation using a single Make target. The workflow runs verify, build, analyze, and test in sequence with timeouts.

## Run The Workflow For One Implementation

1. Identify the implementation name (the folder under `implementations/` with a `Dockerfile`).
2. Run the workflow from the repo root: `make workflow DIR=<name>`.
3. Confirm the output shows `Step 1/4: Verify` through `Step 4/4: Test` and ends with `Workflow completed successfully for <name>`.

Example:
```bash
make workflow DIR=python
```

## What The Workflow Runs

- `make verify DIR=<name>` to validate structure and metadata.
- `make build DIR=<name>` to build the Docker image.
- `make analyze DIR=<name>` to run implementation analysis in Docker when available.
- `make test DIR=<name>` to execute the Dockerized test flow.

Each step is wrapped in a 60s timeout if `timeout` or `gtimeout` is available on the host.

## Helpful Commands

- List available implementations: `make list-implementations`.
- Validate all implementations: `make workflow` (no `DIR`).
- Rerun a single step: `make verify DIR=<name>` or `make test DIR=<name>`.

## Troubleshooting

- `ERROR: Implementation '<name>' not found`: ensure the folder exists under `implementations/`.
- `ERROR: No Dockerfile found`: ensure `implementations/<name>/Dockerfile` exists.
- Timeout failures: rerun the failing step directly to diagnose, then optimize or adjust as needed.
- Docker errors: ensure the Docker daemon is running and you can build images locally.

## Notes

- Run commands from the repo root so relative paths resolve correctly.
- The workflow enforces the Docker-only build/test policy for implementations.
