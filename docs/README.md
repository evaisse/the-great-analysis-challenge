# Documentation Hub

Use this page as the main entrypoint for project documentation.

## By Role

- Contributor workflow: [CONTRIBUTING.md](CONTRIBUTING.md)
- New language implementation: [IMPLEMENTATION_GUIDELINES.md](IMPLEMENTATION_GUIDELINES.md)
- AI agent operating rules: [AGENTS.md](../AGENTS.md)
- LLM file map: [llms.txt](../llms.txt)

## Core Specifications

- Engine/CLI contract: [CHESS_ENGINE_SPECS.md](../CHESS_ENGINE_SPECS.md)
- Deterministic AI contract: [AI_ALGORITHM_SPEC.md](../AI_ALGORITHM_SPEC.md)

## Operations and Automation

- Root commands: [Makefile](../Makefile)
- Shared workflow CLI: [workflow](../workflow)
- Shared test suite: [test/test_suite.json](../test/test_suite.json)
- Shared unit contract suite: [test/contracts/unit_v1.json](../test/contracts/unit_v1.json)
- Bun tooling sources: [tooling/](../tooling)
- CI triage workflow notes: [docs/ISSUE_TRIAGE_WORKFLOW.md](ISSUE_TRIAGE_WORKFLOW.md)

## Additional References

- PRD roadmap: [docs/prd/README.md](prd/README.md)
- Language statistics metadata: [reference/language-statistics.md](reference/language-statistics.md)
- Archived migration notes: [archive/quarantine-summary.md](archive/quarantine-summary.md)

## Non-Negotiable Rules

- Build/test/analyze implementations through Docker targets only.
- Follow convention over configuration: no language-specific root tooling logic.
- Use only the language standard library for chess engine logic.
- Do not add external toolchain downloads in Dockerfiles (except standard package managers where needed).
