---
applyTo: ".github/workflows/**"
---

# CI/CD Workflow Instructions

- Workflows are language-agnostic — they auto-discover implementations via `chess.meta`
- Never add hardcoded language-specific logic
- All builds and tests run inside Docker
- Reference [.github/workflows/README.md](../workflows/README.md) if it exists
- Main workflows: `test.yaml` (test harness), `bench.yaml` (benchmarking)
