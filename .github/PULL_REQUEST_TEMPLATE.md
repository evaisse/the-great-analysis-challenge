# Pull Request

## Type of Change

Please check the type(s) that apply to this PR:

- [ ] 🆕 New language implementation
- [ ] 🐛 Bug fix (non-breaking change that fixes an issue)
- [ ] ✨ Enhancement (improvement to existing implementation)
- [ ] 🔧 Build/CI configuration update
- [ ] 📝 Documentation update
- [ ] 🧪 Test improvements
- [ ] ♻️ Refactoring (no functional changes)
- [ ] ⚡ Performance optimization

## Description

<!-- Provide a clear and concise description of what this PR does -->

## Implementation Details (for new language implementations)

**Language:** <!-- e.g., Python, Rust, Go -->
**Language Version:** <!-- e.g., 3.11, 1.70, 1.21 -->

### Checklist for New Implementations

- [ ] Created `<language>/` directory with all required files
- [ ] `Dockerfile` builds successfully
- [ ] `chess.meta` file is complete and accurate
- [ ] `README.md` documents the implementation
- [ ] `Makefile` with all standard targets (`all`, `test`, `analyze`, `clean`, `docker-build`, `docker-test`)
- [ ] All required commands implemented (`new`, `move`, `undo`, `ai`, `fen`, `export`, `help`, `quit`)
- [ ] Board displays correctly with coordinates
- [ ] All special moves work (castling, en passant, promotion)
- [ ] Checkmate and stalemate detection working
- [ ] AI makes legal moves at depths 1-5
- [ ] Perft(4) returns 197281
- [ ] FEN import/export works correctly
- [ ] Error handling is graceful
- [ ] Updated root `README.md` with implementation status
- [ ] Performance targets met (or documented if not)

## Testing

### How has this been tested?

<!-- Describe the tests you ran to verify your changes -->

- [ ] Built and ran locally with Docker
- [ ] Passed automated test suite
- [ ] Tested basic move sequences
- [ ] Tested AI at multiple depths
- [ ] Verified perft accuracy
- [ ] Tested FEN import/export

### Test commands run:

```bash
# Add the commands you used to test, for example:
# make docker-build
# make docker-test
# echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<language>
```

## Performance Metrics (for implementations)

<!-- If applicable, provide performance benchmarks -->

- **Build Time:** <!-- e.g., ~5-10 seconds -->
- **Analysis Time:** <!-- e.g., ~2-4 seconds -->
- **AI Depth 3:** <!-- e.g., < 2 seconds -->
- **Perft(4):** <!-- e.g., < 1 second -->

## Breaking Changes

- [ ] This PR introduces breaking changes

<!-- If yes, please describe the breaking changes and migration path -->

## Additional Context

<!-- Add any other context, screenshots, or information about the PR here -->

## Related Issues

<!-- Link any related issues using #issue_number -->

Fixes #
Relates to #

## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on? -->

---

**Please ensure you have read and followed the [Contributing Guidelines](../CONTRIBUTING.md) and [Implementation Guidelines](../README_IMPLEMENTATION_GUIDELINES.md) before submitting this PR.**
