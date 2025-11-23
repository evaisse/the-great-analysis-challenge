<!--
Sync Impact Report
- Version change: 0.0.0 → 1.0.0
- Modified principles: Template placeholders replaced with five binding principles
- Added sections: Benchmark Data & Reporting Requirements; Implementation Workflow Expectations
- Removed sections: None
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md (Constitution Check criteria aligned)
  - ✅ .specify/templates/spec-template.md (Reviewed, no revision required)
  - ✅ .specify/templates/tasks-template.md (Reviewed, no revision required)
  - ⚠ Pending: Create command templates under .specify/templates/ if future automation is added
- Follow-up TODOs: None
-->

# The Great Analysis Challenge Constitution

## Core Principles

### I. Specification Fidelity & Feature Parity
Implementations MUST conform to `CHESS_ENGINE_SPECS.md`, `AI_ALGORITHM_SPEC.md`, and the standardized stdin/stdout protocol. Every language variant MUST pass the automated suite in `test/test_suite.json`, return `perft 4 = 197281`, and emit mandated error strings before it is published or benchmarked. Feature flags in `chess.meta` MUST reflect actual capabilities to preserve cross-language parity.

### II. Dockerized Reproducibility
All build, analysis, test, and benchmark workflows MUST execute inside Docker containers orchestrated through the repository Makefile. Each implementation MUST ship a self-contained Dockerfile and Makefile targets (`docker-build`, `docker-test`, `analyze`, `test`) that build without host tooling, keeping images lean via multi-stage builds where available.

### III. Benchmark Integrity & Observability
Contributors MUST capture analysis, compilation, testing, and error metrics using the shared benchmarking harness (`workflow/` scripts and GitHub grid runners). Results written to `language_statistics.yaml`, `build_results.log`, or derivative reports MUST come from reproducible runs, include language/toolchain versions, and fail the pipeline if metrics are missing or malformed.

### IV. Idiomatic Isolation & Documentation
Each language lives under `implementations/<language>/` with no cross-language dependencies. Implementations MUST remain idiomatic for their ecosystems, include `chess.meta`, a language-specific `README.md`, and any auxiliary docs that explain noteworthy design choices, error handling, and performance considerations.

### V. Quality Gates & Automation Discipline
Before merge, repositories MUST demonstrate a clean `make analyze`, `make test`, `make docker-test`, and the mandated performance checks (AI depth 3 ≤ 2s, depth 5 ≤ 10s where feasible). CI jobs MUST enforce these gates, and reviewers MUST block changes that bypass standardized automation or omit regression coverage for chess logic edge cases.

## Benchmark Data & Reporting Requirements
Benchmark pipelines MUST:
- Record metrics in milliseconds for analysis, build, and test phases using consistent hardware (GitHub-hosted runners or documented equivalents).
- Surface errors, timeouts, or missing data explicitly in reports rather than silently skipping entries.
- Update the website generator (`build_website.py`) data sources whenever new implementations ship or benchmarks change.
- Retain historical data in `reports/` to enable trend analysis and regression detection.

## Implementation Workflow Expectations
Contributors SHOULD follow the project workflow phases defined in `AGENTS.md`:
- Phase 1 (Setup): scaffold Dockerfile, Makefile, metadata, and directory structure.
- Phase 2 (Core Implementation): deliver board representation, move generation, FEN parsing, game state management, CLI, and AI.
- Phase 3 (Testing & Validation): exercise Docker builds, automated suite, perft targets, and performance thresholds.
- Phase 4 (Documentation): update implementation `README.md`, root `README.md`, and `Makefile` entries.
- Phase 5 (Integration): ensure CI coverage, benchmark ingestion, and website sync.

## Governance
This constitution supersedes conflicting guidance in other docs. Amendments require:
- Opening an issue describing the proposed change, rationale, and prospective version bump.
- Approval from at least two maintainers, including the benchmark tooling maintainer.
- Updating dependent templates and tooling references within the same change set.
Semantic versioning governs updates: MAJOR for rewritten principles or removed obligations, MINOR for added principles/sections, PATCH for clarifications. Compliance is reviewed during PR checks and quarterly audits aligned with benchmark refresh cycles.

**Version**: 1.0.0 | **Ratified**: 2025-11-13 | **Last Amended**: 2025-11-13
