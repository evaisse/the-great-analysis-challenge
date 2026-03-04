# PRD Next Level - Track V2

## Summary
This document defines a progressive `v2` track that stresses implementations with broader engine features, larger codebases, and stronger runtime robustness checks while preserving strict `v1` compatibility.

Core rollout constraints:
- `v2` starts non-blocking, then becomes blocking in phases.
- Initial mandatory core set: `dart`, `lua`, `php`, `python`, `go`.
- Measurements are published as **raw metrics tables**, including normalized values (`ms/KLOC`).
- Existing `v1` behavior and test expectations remain required.

## Goals
1. Force implementation of a broad feature set (PRD-01 -> PRD-10).
2. Increase per-language code surface in a controlled and comparable way.
3. Benchmark build/analyze/runtime cost both absolute and normalized by source size.
4. Add stress and safety checks (including concurrency safety invariants).
5. Keep deterministic and backwards-compatible `v1` behavior.

## Non-Goals
1. Replacing `v1` immediately.
2. Removing existing custom CLI protocol.
3. Introducing third-party chess logic libraries.
4. Publishing a single weighted score.

## Hard Constraints
1. Docker-only build/test/analyze workflows.
2. Standard-library-only chess logic.
3. Strict `v1` CLI and output compatibility.
4. No regression on canonical baseline (`perft(4)=197281` in classic mode).
5. Progressive CI enforcement.

## Track Levels
| Level | Scope | Initial CI mode |
|---|---|---|
| `v1-base` | Existing suite (`test/test_suite.json`) | Blocking |
| `v2-foundation` | PRD-07 + PRD-01 + PRD-03 | Non-blocking |
| `v2-full` | PRD-01 -> PRD-10 | Non-blocking (then blocking by rollout phase) |

## Required Public Interface Additions
### CLI Commands
- `hash`
- `draws`
- `history`
- `go movetime <ms>`
- `go wtime <ms> btime <ms> winc <ms> binc <ms> [movestogo <n>]`
- `go infinite`
- `stop`
- `pgn load <filename>`
- `pgn save <filename>`
- `pgn show`
- `pgn moves`
- `pgn variation enter`
- `pgn variation exit`
- `pgn comment "text"`
- UCI mode commands (`uci`, `isready`, `setoption`, `position`, `go`, `stop`, `quit`)
- `new960`
- `new960 <n>`
- `position960`
- `trace on|off`
- `trace level <level>`
- `trace export <file>`
- `trace report`
- `trace chrome <file>`
- `trace reset`
- `concurrency quick`
- `concurrency full`

### Standard Output Contracts
- `HASH: <hex64>`
- `DRAWS: repetition=<n>; halfmove=<n>; draw=<true|false>; reason=<none|repetition|fifty_moves>`
- `CONCURRENCY: <json>`

## Concurrency JSON Contract
```json
{
  "profile": "quick|full",
  "seed": 12345,
  "workers": 1,
  "runs": 10,
  "checksums": ["..."],
  "deterministic": true,
  "invariant_errors": 0,
  "deadlocks": 0,
  "timeouts": 0,
  "elapsed_ms": 1234,
  "ops_total": 100000
}
```

## Repository-Level Implementation
### Specifications
- Extend `CHESS_ENGINE_SPECS.md` with track definitions and output contracts.
- Keep `AI_ALGORITHM_SPEC.md` as deterministic v1 reference.

### Test Assets
- Keep `test/test_suite.json` frozen for `v1`.
- Add:
  - `test/suites/v2_foundation.json`
  - `test/suites/v2_functional.json`
  - `test/suites/v2_system.json`
  - `test/suites/v2_full.json`
  - `test/concurrency_harness.py`
  - `test/code_size_metrics.py`

### Harness and Bench
- `test/test_harness.py` accepts `--suite`, `--track`, and docker-backed execution.
- `test/performance_test.py` includes LOC/file metrics and normalized ratios.

### Root Make Targets
- `make test-chess-engine DIR=<impl> TRACK=<track>`
- `make benchmark-stress DIR=<impl> TRACK=<track> PROFILE=<profile>`
- `make benchmark-concurrency DIR=<impl> PROFILE=<profile>`

## Measurement Method
### Source LOC Normalization
Count only implementation source files.
Exclude generated/vendor/build directories:
- `node_modules`, `vendor`, `dist`, `build`, `target`, `.dart_tool`, `elm-stuff`, `.git`, `.next`, `coverage`

### Published Metrics
- Absolute:
  - `build_s`, `analyze_s`, `test_v1_s`, `test_v2_foundation_s`, `test_v2_full_s`
  - `perft4_ms`, `ai3_ms`, `ai5_ms`, `peak_mem_mb`
- Size:
  - `source_loc`, `source_files`
- Normalized:
  - `build_ms_per_kloc`, `analyze_ms_per_kloc`, `runtime_ms_per_kloc`
- Concurrency safety:
  - `checksums_stable`, `invariant_errors`, `deadlocks`, `timeouts`

## Delivery Plan (6-8 Weeks)
### Wave 1 (Weeks 1-2): Foundation
- PRD-07 Zobrist + repetition + 50-move rule
- PRD-01 attack tables + codegen
- PRD-03 TT + iterative deepening + time management
- CI: `v2-foundation` non-blocking

### Wave 2 (Weeks 3-5): Functional Breadth
- PRD-02 rich evaluation (feature-flagged)
- PRD-05 PGN + variation tree
- PRD-06 UCI + state machine + dual-mode
- PRD-08 Chess960 + castling/FEN support
- CI: partial blocking on critical invariants for core set

### Wave 3 (Weeks 6-8): System Stress
- PRD-04 type-safe modeling
- PRD-09 structured tracing and exports
- PRD-10 concurrency benchmark + safety policy
- CI: `v2-full` blocking on core set, then progressive extension

## Dependency Order
1. PRD-07 before PRD-03
2. PRD-01 in parallel with PRD-07 (feeds eval/search perf)
3. PRD-03 before PRD-10
4. PRD-02 after PRD-01
5. PRD-05 parallelizable with PRD-06
6. PRD-08 coordinated with PRD-07 (castling hash rights)
7. PRD-04 and PRD-09 after core API stabilization

## Acceptance Criteria by Level
### v2-foundation
- Deterministic hashes
- Hash restored after move/undo
- Repetition/50-move draw detection available
- Time-managed search commands supported
- TT is integrated (observable hit usage)
- No v1 regression

### v2-functional
- PGN parse + save for real fixtures
- UCI handshake and search flow compliant
- Chess960 generation/castling/FEN validated
- No v1 regression

### v2-system
- Trace exports valid (JSON + Chrome format)
- Tracing overhead bounded when disabled
- Concurrency safety policy passes (`invariant_errors=0`, `deadlocks=0`, `timeouts=0`, deterministic checksums)
- No v1 regression

## Rollout Policy
| Phase | Core Set (`dart,lua,php,python,go`) | Other Active Implementations |
|---|---|---|
| A | v2 informative | v2 informative |
| B | v2-foundation blocking | v2 informative |
| C | v2-full blocking | v2-foundation informative |
| D | v2-full blocking | v2-full blocking by batches |

Batch extension rule:
- 1 week informative
- 1 week partial blocking
- then full blocking

## Risks and Mitigations
1. CI runtime growth -> quick/full profiles and matrix parallelism.
2. Protocol divergence (UCI/PGN) -> strict shared fixtures + contracts.
3. Uneven type-system capability -> minimum common requirements + language annexes.
4. Concurrency false positives -> fixed seeds, repeated runs, safety-first gating.
5. LOC bias -> strict normalization exclusions and published raw dimensions.

## Assumptions
1. PRD-01 through PRD-10 are the official v2 target set.
2. Custom protocol remains supported alongside UCI.
3. Rich evaluation is feature-flagged to preserve deterministic v1 behavior.
4. No external chess libraries are introduced.
5. Docker labels remain the metadata source of truth.
