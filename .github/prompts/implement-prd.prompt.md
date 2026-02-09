# Implement PRD Feature

Implement a feature from the PRD documents across the chess engine implementations.

## Context

Read the PRD documents:
- [PRD Overview & Dependencies](../../docs/prd/README.md)
- [PRD-01: Attack Tables](../../docs/prd/01-attack-tables-codegen.md)
- [PRD-02: Rich Evaluation](../../docs/prd/02-rich-evaluation.md)
- [PRD-03: Transposition Table](../../docs/prd/03-transposition-table-iterative-deepening.md)
- [PRD-04: Type-safe Modeling](../../docs/prd/04-type-safe-modeling.md)
- [PRD-05: PGN Parser](../../docs/prd/05-pgn-parser-variant-tree.md)
- [PRD-06: UCI Protocol](../../docs/prd/06-uci-protocol.md)
- [PRD-07: Zobrist Hashing](../../docs/prd/07-zobrist-hashing-repetition.md)
- [PRD-08: Chess960](../../docs/prd/08-chess960.md)
- [PRD-09: Structured Tracing](../../docs/prd/09-structured-tracing-diagnostics.md)

## Implementation Rules

1. Check the dependency graph in the PRD README before starting
2. Implement for ALL 7 active languages: Rust, TypeScript, Python, PHP, Dart, Ruby, Lua
3. Use idiomatic code per language — showcase what stresses each toolchain
4. Write code that maximizes type-checker / compiler / linter workload
5. Maintain backward compatibility — existing tests MUST still pass
6. Measure build/analysis times before and after
7. Follow the file structure suggested in each PRD
8. Verify perft(4) = 197281 after changes (no regressions)
