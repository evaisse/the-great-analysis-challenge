# Code Review — Chess Implementation

Review a chess engine implementation for correctness, idiomacy, and spec compliance.

## Review Checklist

### Specification Compliance
- [ ] All commands from CHESS_ENGINE_SPECS.md implemented
- [ ] Output format matches spec exactly
- [ ] AI follows AI_ALGORITHM_SPEC.md (minimax + alpha-beta, piece-square tables)
- [ ] perft(4) = 197281

### Chess Correctness
- [ ] All piece movements correct (including edge cases at board boundaries)
- [ ] Castling: all FIDE conditions checked
- [ ] En passant: only after opponent two-square pawn advance, captures correctly
- [ ] Promotion: default Queen, all pieces available
- [ ] Check detection: moves leaving king in check filtered
- [ ] Checkmate and stalemate correctly detected

### Code Quality
- [ ] Idiomatic for the target language
- [ ] No external chess libraries used
- [ ] stdout flushed after each output
- [ ] Error handling is graceful (no crashes on invalid input)
- [ ] Docker build works and image is reasonably sized

### Documentation
- [ ] chess.meta is accurate
- [ ] README.md is comprehensive
- [ ] Makefile has all standard targets

## Reference
- [Chess Engine Specs](../../CHESS_ENGINE_SPECS.md)
- [AI Algorithm Spec](../../AI_ALGORITHM_SPEC.md)
- [Contributing Guide](../../CONTRIBUTING.md)
