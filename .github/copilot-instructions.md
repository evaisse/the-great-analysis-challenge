# GitHub Copilot Instructions

## Project Overview

**The Great Analysis Challenge** is a polyglot chess engine implementation project that implements identical chess engines across multiple programming languages to compare their approaches, performance, and paradigms.

### Key Goals
- Compare how different programming languages solve the same problem
- Provide fair benchmarking with consistent specifications
- Showcase language-specific features and paradigms
- Analyze compilation times, execution speed, and resource usage
- Document developer experience across different ecosystems

## Project Constraints

### Universal Rules
1. **Specification Compliance**: All implementations MUST follow `CHESS_ENGINE_SPECS.md`
2. **Docker-First Development**: All builds and tests MUST run inside Docker containers
3. **Standardized I/O**: Command-line interface via stdin/stdout with defined protocol
4. **Automated Testing**: Must pass test suite defined in `test/test_suite.json`
5. **Performance Targets**: Meet specified benchmarks (perft, AI depth timing)
6. **No External Chess Libraries**: Implementations must be from scratch to fairly compare languages

### Implementation Structure
- Each language gets its own directory: `implementations/<language>/`
- Required files per implementation:
  - `Dockerfile` - Complete build and runtime environment
  - `Makefile` - Build automation with standard targets
  - `chess.meta` - JSON metadata about the implementation
  - `README.md` - Language-specific documentation
  - Source files following language conventions
- No cross-language dependencies
- Focus on idiomatic code for each language

## Coding Standards

### Language-Specific Best Practices
When implementing in a specific language:
- Use the language's standard formatting tools (rustfmt, black, prettier, etc.)
- Follow the language's naming conventions and idioms
- Showcase unique language features (pattern matching, type systems, etc.)
- Use appropriate data structures for the language
- Implement error handling in the language's idiomatic way

### Code Quality Requirements
- Write readable, maintainable code
- Add comments only for complex chess logic (not obvious code)
- Keep functions focused and single-purpose
- Use meaningful variable and function names
- Avoid premature optimization - correctness first

### What NOT to Do
- Don't use external chess libraries or engines
- Don't modify other language implementations without approval
- Don't break the standardized command protocol
- Don't sacrifice correctness for performance
- Don't commit build artifacts or compiled binaries (dependency lock files like package-lock.json, Gemfile.lock are acceptable for reproducibility)

## Build and Test Procedures

### Standard Makefile Targets
Every implementation must support:
```bash
make              # Default target (aliases to 'all' which builds the chess engine)
make all          # Build the chess engine (same as make)
make test         # Run tests
make analyze      # Run linters/type checkers
make clean        # Remove build artifacts
make docker-build # Build Docker image
make docker-test  # Test in Docker container
```

### Testing Workflow
1. **Build**: Always build in Docker for consistency
   ```bash
   cd implementations/<language>
   make docker-build
   ```

2. **Basic Test**: Test core functionality
   ```bash
   echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<language>
   ```

3. **Automated Tests**: Run full test suite
   ```bash
   make docker-test
   ```

4. **Performance Test**: Verify perft(4) returns 197281
   ```bash
   echo -e "new\nperft 4\nquit" | docker run -i chess-<language>
   ```

### Docker Requirements
- Use official language base images
- Keep image sizes reasonable (use multi-stage builds)
- Set working directory to `/app`
- Ensure executable permissions are set correctly
- Flush stdout after each output (critical for stdin/stdout protocol)

## Implementation Workflow

### Adding a New Language Implementation

**Phase 1: Setup (15-30 minutes)**
1. Create directory: `implementations/<language>/`
2. Create `implementations/<language>/Dockerfile` with language runtime and dependencies
3. Create `implementations/<language>/chess.meta` with metadata (see existing implementations)
4. Create `implementations/<language>/Makefile` with standard targets
5. Create initial `implementations/<language>/README.md`

**Phase 2: Core Implementation (2-8 hours)**
Implement components in this order:
1. Board representation (8x8 grid, piece tracking, game state)
2. Move generator (pseudo-legal moves for each piece type)
3. Move validation (ensure moves don't leave king in check)
4. FEN parser (import/export positions)
5. Game state manager (execute/undo moves, detect checkmate/stalemate)
6. Command interface (stdin/stdout protocol)
7. AI engine (minimax with alpha-beta pruning, depth 1-5)

**Phase 3: Testing (1-2 hours)**
1. Test locally with Docker
2. Verify all commands work correctly
3. Validate special moves (castling, en passant, promotion)
4. Run automated test suite
5. Verify performance targets

**Phase 4: Documentation (30-45 minutes)**
1. Complete implementation README.md
2. Update root README.md with new language
3. Document unique language features showcased
4. Add build/test instructions
5. Note performance characteristics

### Chess Rules Implementation Priority

**Must Have (Core Compliance):**
- Standard piece movement (pawn, knight, bishop, rook, queen, king)
- Capture mechanics
- Check detection
- Checkmate detection
- Stalemate detection
- Castling (kingside and queenside)
- En passant
- Pawn promotion
- FEN import/export

**Performance Requirements:**
- AI depth 3 completes in < 2 seconds
- AI depth 5 completes in < 10 seconds
- perft(4) returns 197281 (correctness validation)

## Common Pitfalls

### Chess Logic Errors
- **Castling**: Verify ALL conditions (no prior moves, no pieces between, king not in/through check)
- **En Passant**: Only valid immediately after opponent's two-square pawn move
- **Promotion**: Handle auto-promotion to Queen if not specified
- **Check Detection**: Must prevent moves that leave own king in check
- **Coordinates**: `a1` is bottom-left for White (row indexing matters)

### Implementation Issues
- **Input Buffering**: MUST flush stdout after each output for stdin/stdout protocol
- **FEN Parsing**: Handle all 6 FEN fields correctly (position, turn, castling, en passant, halfmove, fullmove)
- **Move Notation**: Use algebraic notation (e2e4, e7e8Q) not descriptive (e4, Nf3)
- **Error Recovery**: Invalid commands should print ERROR and continue, not crash
- **Case Sensitivity**: White pieces uppercase (K,Q,R,B,N,P), black lowercase (k,q,r,b,n,p)

### Docker/Testing Issues
- **Working Directory**: Ensure commands run in `/app` directory
- **Executable Permissions**: Make scripts executable in Dockerfile (`chmod +x`)
- **Build Artifacts**: Don't commit them, use `.dockerignore`
- **Dependencies**: Lock versions for reproducibility
- **Image Size**: Use multi-stage builds when possible

## AI and Code Review Guidance

### For AI Assistants
When working on this project:
1. **Read specifications first**: Don't assume chess rules, read `CHESS_ENGINE_SPECS.md`
2. **Use existing implementations as templates**: Study Ruby, TypeScript, or Rust implementations
3. **Test incrementally**: Build and test each component before moving to the next
4. **Follow language conventions**: Use standard project layouts and idioms
5. **Don't modify other languages**: Each implementation is independent
6. **Keep Docker images working**: All testing is Docker-based
7. **Flush output properly**: Critical for stdin/stdout protocol to work
8. **Validate with perft**: This is the ultimate correctness check

### Code Review Checklist
Before considering an implementation complete:
- [ ] Dockerfile builds successfully
- [ ] All required commands implemented
- [ ] Board displays correctly with coordinates
- [ ] All special moves work (castling, en passant, promotion)
- [ ] Checkmate and stalemate detected correctly
- [ ] AI makes legal moves at depths 1-5
- [ ] perft(4) returns exactly 197281
- [ ] FEN import/export works correctly
- [ ] Error handling is graceful (no crashes)
- [ ] chess.meta file is accurate
- [ ] README.md is comprehensive
- [ ] Makefile targets work as expected
- [ ] Added to root README.md
- [ ] Passes automated test suite
- [ ] Performance targets met

## File Structure Reference

```
the-great-analysis-challenge/
├── README.md                              # Main documentation
├── CHESS_ENGINE_SPECS.md                 # Complete specification (PRIMARY REFERENCE)
├── README_IMPLEMENTATION_GUIDELINES.md   # Quick reference guide
├── CONTRIBUTING.md                        # Contribution guidelines
├── AGENTS.md                             # Detailed agent instructions
├── Makefile                              # Root-level build automation
│
├── implementations/<language>/           # One directory per language
│   ├── Dockerfile                        # Complete build environment
│   ├── Makefile                          # Standard build targets
│   ├── chess.meta                        # Metadata JSON
│   ├── README.md                         # Language-specific docs
│   └── <source files>                    # Implementation files
│
├── test/                                 # Test infrastructure
│   ├── test_suite.json                   # Automated test definitions
│   ├── test_harness.py                   # Test runner
│   └── verify_implementations.py         # Verification script
│
├── .github/
│   ├── workflows/                        # CI/CD automation
│   └── copilot-instructions.md           # This file
│
└── docs/                                 # Additional documentation
```

## Command Protocol Specification

### Input Format
Commands are read from stdin, one per line:
```
new              # Start new game
move e2e4        # Execute a move
move e7e8Q       # Move with promotion
undo             # Undo last move
ai 3             # AI makes move at depth 3
fen <string>     # Load position from FEN
export           # Export current position as FEN
eval             # Show position evaluation
perft 4          # Performance test at depth 4
help             # Show available commands
quit             # Exit program
```

### Output Format
All output goes to stdout:
```
# Board display (after new, move, undo)
  a b c d e f g h
8 r n b q k b n r 8
7 p p p p p p p p 7
6 . . . . . . . . 6
5 . . . . . . . . 5
4 . . . . . . . . 4
3 . . . . . . . . 3
2 P P P P P P P P 2
1 R N B Q K B N R 1
  a b c d e f g h

White to move

# Status messages
OK: move e2e4
ERROR: Invalid move
CHECKMATE: White wins
STALEMATE: Draw
AI: move e7e5 (depth=3, eval=-15, time=250ms)
FEN: rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1
```

## Performance Expectations

### Build Times
- Compiled languages: 5-60 seconds acceptable
- Interpreted languages: < 5 seconds typical
- Document actual build times in README.md

### Runtime Performance
- AI depth 3: Should complete in < 2 seconds
- AI depth 5: Should complete in < 10 seconds
- perft(4): Target < 1 second (nice to have, not required)

### Optimization Strategies
- Use appropriate data structures (arrays for boards, bitboards if suitable)
- Implement move ordering for better alpha-beta pruning
- Cache evaluation results if beneficial
- Profile before optimizing
- Balance readability vs performance

## Getting Help

### Documentation Resources
1. `CHESS_ENGINE_SPECS.md` - Complete technical specification
2. `README_IMPLEMENTATION_GUIDELINES.md` - Quick reference
3. `AGENTS.md` - Detailed workflow for implementations
4. `CONTRIBUTING.md` - Contribution process
5. Existing implementations - Ruby, TypeScript, Rust are well-documented

### Reference Implementations

The project has 19+ language implementations. Recommended starting points for study:
- **Ruby**: Clean OOP design, easy to understand
- **TypeScript**: Modern JavaScript with types, good structure
- **Rust**: High performance, showcases ownership system
- **Kotlin**: JVM integration, null safety features

All implementations can be found in `implementations/` directory including: Crystal, Dart, Elm, Gleam, Go, Haskell, Julia, Lua, Mojo, Nim, PHP, Python, Rescript, Swift, Zig, and more.

### Debugging Tips
1. Test incrementally - one feature at a time
2. Use FEN positions to test specific scenarios
3. Print board state to visualize positions
4. Validate moves manually with online chess tools
5. Compare output format exactly with specification
6. Log AI decisions to debug evaluation

## Success Criteria

An implementation is successful when it:
1. ✅ Builds in Docker without errors
2. ✅ Passes all automated tests
3. ✅ Meets performance targets
4. ✅ Demonstrates language features effectively
5. ✅ Has clear, comprehensive documentation
6. ✅ Follows project conventions
7. ✅ Can be maintained by others

---

**Remember**: The goal is not just a working chess engine, but to showcase how each programming language approaches the same problem differently. Code quality, documentation, and adherence to language idioms are as important as functionality.
