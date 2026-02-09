---
applyTo: "test/**"
---

# Test Infrastructure Instructions

- `test/test_suite.json` defines the automated test suite — do NOT modify test expectations
- `test/test_harness.py` is the test runner invoked by Make targets and CI
- Tests are standardized for fair cross-language comparison — no language-specific test logic
- Test categories: basic movement, special moves (castling, en passant, promotion), game end (checkmate, stalemate), AI (legal moves at all depths), FEN (import/export)
- perft(4) = 197281 is the ultimate correctness check
- All tests run via Docker: `make test DIR=<language>`
- Reference [CHESS_ENGINE_SPECS.md](../../CHESS_ENGINE_SPECS.md) for expected output format
