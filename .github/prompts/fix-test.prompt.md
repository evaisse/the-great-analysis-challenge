# Fix Failing Test

Debug and fix a failing test in a chess engine implementation.

## Diagnostic Steps

1. **Read the test output** carefully — identify which test category failed
2. **Test categories**: basic, special_moves, game_end, ai, fen
3. **Reproduce locally**:
   ```bash
   cd implementations/<language>
   make docker-build
   make docker-test
   ```
4. **Test specific commands**:
   ```bash
   echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<lang>
   echo -e "new\nai 3\nquit" | docker run -i chess-<lang>
   echo -e "new\nperft 4\nquit" | docker run -i chess-<lang>
   ```

## Reference
- [Chess Engine Specs](../../CHESS_ENGINE_SPECS.md) — expected output format
- [Test Suite](../../test/test_suite.json) — exact test definitions
- [AI Algorithm Spec](../../AI_ALGORITHM_SPEC.md) — AI behavior requirements
