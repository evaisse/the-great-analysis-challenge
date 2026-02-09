# AGENTS.md - AI Agent Instructions

**ALWAYS** read `./README.md`, `CONTRIBUTING.md` and `llms.txt` before making any edit.

## Project Overview

**The Great Analysis Challenge** is a polyglot chess engine implementation project. The goal is to implement the same chess engine specification across multiple programming languages to compare their approaches, paradigms, performance characteristics, and developer experiences.

## Project Goals

1. **Language Comparison**: Demonstrate how different programming languages approach the same problem
2. **Fair Benchmarking**: Provide consistent specifications so implementations can be fairly compared
3. **Educational Value**: Showcase language-specific features and paradigms
4. **Performance Analysis**: Compare compilation times, execution speed, and resource usage
5. **Developer Experience**: Document development workflow, tooling, and debugging approaches

## Core Constraints

### Universal Requirements

1. **Specification Compliance**: All implementations MUST follow `CHESS_ENGINE_SPECS.md`
2. **Docker-Mandatory**: ALL operations for language implementations (build, test, lint, format, validate) MUST run inside Docker containers.
   - **DO NOT** use local toolchains (e.g., local `python`, `cargo`, `go`, `npm`) to modify or verify implementations.
   - **ALWAYS** use `make build DIR=<lang>`, `make test DIR=<lang>`, and `make analyze DIR=<lang>` from the project root.
   - This ensures a consistent environment and avoids "it works on my machine" issues.
3. **Standardized I/O**: Command-line interface via stdin/stdout with defined protocol
4. **Consistent Testing**: Pass automated test suite defined in `test/test_suite.json`
5. **Performance Targets**: Meet specified benchmarks (perft, AI depth timing)

### Implementation Rules

- Each language gets its own directory: `<language>/`
- Required files per implementation:
  - `Dockerfile` - Complete build and runtime environment
  - `chess.meta` - JSON metadata about the implementation
  - `README.md` - Language-specific documentation
  - Main source files following language conventions
- No cross-language dependencies
- No modification of other language implementations without explicit approval
- Focus on idiomatic code for each language

## Workflow to Add a New Chess Implementation

### Phase 1: Setup (15-30 minutes)

1. **Create Language Directory**

   ```bash
   mkdir <language>
   cd <language>
   ```

2. **Create Dockerfile**

   - Base image for the language (official images preferred)
   - Install language runtime/compiler and dependencies
   - Copy source files to `/app`
   - Build/compile if needed
   - Set default command to run the chess engine
   - Keep image size reasonable (multi-stage builds recommended)

3. **Create chess.meta**
   ```json
   {
     "language": "<language_name>",
     "version": "<language_version>",
     "author": "Your Name",
     "build": "<build_command>",
     "run": "<run_command>",
     "features": ["perft", "fen", "ai", "castling", "en_passant", "promotion"],
     "max_ai_depth": 5,
     "estimated_perft4_ms": 1000
   }
   ```

### Phase 2: Core Implementation (2-8 hours)

4. **Implement Core Components** (in order of priority)

   a. **Board Representation** (30-60 min)

   - 8x8 board structure
   - Piece representation (K/Q/R/B/N/P and k/q/r/b/n/p)
   - Position state (whose turn, castling rights, en passant)

   b. **Move Generator** (60-120 min)

   - Generate all pseudo-legal moves for each piece type
   - Validate moves don't leave king in check
   - Special moves: castling, en passant, promotion

   c. **FEN Parser** (30-45 min)

   - Parse FEN string to board state
   - Serialize board state to FEN string
   - Test with standard positions from `CHESS_ENGINE_SPECS.md`

   d. **Game State Manager** (45-90 min)

   - Execute/undo moves
   - Track game history
   - Detect checkmate, stalemate
   - Handle turn order

   e. **Command Interface** (30-45 min)

   - Read commands from stdin
   - Parse and dispatch commands
   - Display board in ASCII format (with coordinates)
   - Output status messages in spec format

   f. **AI Engine** (90-180 min)

   - Minimax algorithm with alpha-beta pruning
   - Position evaluation function (material + positional bonuses)
   - Depth-limited search (1-5 ply)
   - Move ordering for better pruning

### Phase 3: Testing & Validation (1-2 hours)

5. **Test Locally with Docker**

   ```bash
   # Build image
   docker build -t chess-<language> .

   # Basic test
   echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<language>

   # AI test
   echo -e "new\nai 3\nquit" | docker run -i chess-<language>

   # Perft test
   echo -e "new\nperft 4\nquit" | docker run -i chess-<language>
   ```

6. **Verify Test Suite Compliance**

   - Run automated tests: `make test-<language>`
   - Check all test categories pass (basic, special_moves, game_end, ai, fen)
   - Validate perft(4) returns 197281
   - Ensure AI makes legal moves at all depths

7. **Performance Validation**
   - Measure compilation time
   - Check AI depth 3 < 2 seconds
   - Check AI depth 5 < 10 seconds
   - Verify perft(4) < 1 second (optional, nice to have)

### Phase 4: Documentation (30-45 minutes)

8. **Write README.md**

   - Overview of implementation
   - Language features showcased
   - Build and run instructions
   - Performance characteristics
   - Dependencies
   - Development workflow
   - Example usage

9. **Add to Main README**

   - Add language section to root `README.md`
   - Include paradigm description
   - Note key features
   - Add build command and timing
   - Update language list

10. **Update Makefile** (if not already present)
    - Add `test-<language>` target
    - Add `build-<language>` target
    - Add to `LANGUAGES` list
    - Follow existing patterns

### Phase 5: Integration (15-30 minutes)

11. **CI/CD Integration** (optional but recommended)

    - Workflow files in `.github/workflows/` should auto-detect
    - Verify build runs in CI
    - Check test results

12. **Final Validation**
    - Clean build: `docker rmi chess-<language>; make build-<language>`
    - Full test: `make test-<language>`
    - Check output format matches spec
    - Verify error handling

## Common Pitfalls to Avoid

### Chess Logic Errors

- **Castling**: Verify ALL conditions (no prior moves, no pieces between, king not in/through check)
- **En Passant**: Only valid immediately after opponent's two-square pawn move
- **Promotion**: Handle auto-promotion to Queen if not specified
- **Check Detection**: Must prevent moves that leave own king in check
- **Coordinates**: a1 is bottom-left for White (row 0/7 depending on indexing)

### Implementation Issues

- **Input Buffering**: Flush stdout after each output (critical for stdin/stdout protocol)
- **FEN Parsing**: Handle all 6 FEN fields correctly (especially castling rights and en passant)
- **Move Notation**: Use algebraic notation (e2e4, not e4 or Nf3)
- **Error Recovery**: Invalid commands should not crash the program
- **Case Sensitivity**: White pieces uppercase, black lowercase

### Docker/Testing Issues

- **Working Directory**: Ensure commands run in correct directory (`/app`)
- **Executable Permissions**: Make scripts executable in Dockerfile
- **Build Artifacts**: Don't commit build artifacts (use .dockerignore)
- **Dependencies**: Lock dependency versions for reproducibility
- **Image Size**: Use multi-stage builds to reduce final image size

## Development Best Practices

### Language-Specific Showcases

When implementing, demonstrate the language's unique strengths:

- **Systems Languages (Rust, C++, Zig)**: Memory management, zero-cost abstractions, bitboards
- **Functional Languages (Haskell, Gleam, Elm)**: Immutable state, pure functions, type safety
- **OOP Languages (Java, Kotlin, C#)**: Design patterns, interfaces, polymorphism
- **Dynamic Languages (Python, Ruby, JavaScript)**: Rapid prototyping, metaprogramming, expressiveness
- **Concurrent Languages (Go, Erlang)**: Goroutines/actors, parallel search

### Code Quality

- Write idiomatic code for the language
- Add comments for complex chess logic only
- Use language's standard formatting tools
- Include static analysis where available
- Keep functions focused and testable
- Document public APIs

### Performance Optimization

- Use appropriate data structures (arrays for boards, bitboards if suitable)
- Implement move ordering for alpha-beta pruning
- Cache evaluation results if possible
- Profile before optimizing
- Balance readability vs performance

## Testing Strategy

### Required Tests (Automated)

All implementations must pass tests in `test/test_suite.json`:

1. **Basic Movement**: Standard piece moves and captures
2. **Special Moves**: Castling, en passant, promotion
3. **Game End**: Checkmate and stalemate detection
4. **AI**: Legal move generation at all depths
5. **FEN**: Import/export position accuracy

### Manual Testing

Test interactively:

```bash
docker run -it chess-<language>

# In the chess engine:
> help
> new
> move e2e4
> move e7e5
> ai 3
> export
> quit
```

### Performance Testing

```bash
# Compilation time
time make build-<language>

# Perft benchmark
echo -e "new\nperft 4\nquit" | time docker run -i chess-<language>

# AI performance
echo -e "new\nai 5\nquit" | time docker run -i chess-<language>
```

## Integration Checklist

Before considering an implementation complete:

- [ ] Dockerfile builds successfully
- [ ] All required commands implemented (new, move, undo, ai, fen, export, help, quit)
- [ ] Board displays correctly with coordinates
- [ ] All special moves work (castling, en passant, promotion)
- [ ] Checkmate and stalemate detected
- [ ] AI makes legal moves at depths 1-5
- [ ] Perft(4) returns 197281
- [ ] FEN import/export works correctly
- [ ] Error handling is graceful
- [ ] chess.meta file is accurate
- [ ] README.md is comprehensive
- [ ] Makefile targets added
- [ ] Added to root README.md
- [ ] Passes automated test suite
- [ ] Performance targets met

## Getting Help

### Resources

1. **Specification**: Read `CHESS_ENGINE_SPECS.md` thoroughly
2. **Guidelines**: Review `README_IMPLEMENTATION_GUIDELINES.md`
3. **Examples**: Study existing implementations (Ruby, TypeScript, Rust are well-documented)
4. **Test Suite**: Check `test/test_suite.json` for exact test requirements
5. **GitHub Actions**: See `.github/workflows/README.md` for CI/CD details

### Reference Implementations

- **Ruby**: Clean OOP design, easy to understand
- **TypeScript**: Modern JavaScript with types, good structure
- **Rust**: High performance, showcases ownership system
- **Kotlin**: JVM integration, null safety features

### Debugging Tips

1. **Test incrementally**: Implement and test one feature at a time
2. **Use FEN positions**: Test specific scenarios without playing full games
3. **Print board state**: Debug by visualizing positions
4. **Validate moves manually**: Use online chess validators
5. **Check test output**: Compare your output format exactly with specs
6. **Log AI decisions**: Output evaluation scores to debug AI behavior

## FAQ

**Q: Do I need to implement all features?**  
A: Yes, for compliance. But you can start with basic compliance and add optimizations later.

**Q: Can I use chess libraries?**  
A: No. The goal is to implement the logic to compare languages, not libraries.

**Q: What if my language is very slow?**  
A: Performance targets are guidelines. Focus on correctness first, then optimize within reason.

**Q: Can I use different algorithms than minimax?**  
A: No. The specification requires minimax with alpha-beta for fair comparison.

**Q: How important is code quality?**  
A: Very. The code should be readable and idiomatic to showcase the language properly.

**Q: Can I modify the test suite?**  
A: No. Tests are standardized for fair comparison across languages.

**Q: What about languages without mature Docker support?**  
A: All major languages have official Docker images. For experimental languages, create a working Dockerfile or skip that language.

**Q: Should I optimize for speed or readability?**  
A: Balance both. Prioritize idiomatic, readable code, then optimize hot paths if needed.

## Project Structure Reference

```
the-great-analysis-challenge/
├── README.md                           # Main project documentation
├── CHESS_ENGINE_SPECS.md              # Complete specification (YOUR BIBLE)
├── README_IMPLEMENTATION_GUIDELINES.md # Quick reference guide
├── AGENTS.md                          # This file - agent instructions
├── llms.txt                           # LLM context file list
├── Makefile                           # Docker-based build/test automation
│
├── <language>/                        # One directory per language
│   ├── Dockerfile                     # Complete build environment
│   ├── chess.meta                     # Metadata JSON
│   ├── README.md                      # Language-specific docs
│   ├── <source files>                 # Implementation
│   └── lib/ or src/                   # Additional modules
│
├── test/                              # Test infrastructure
│   ├── test_suite.json                # Automated test definitions
│   ├── test_harness.py                # Test runner
│   └── test_summary.md                # Test results
│
└── .github/workflows/                 # CI/CD automation
    ├── build-and-test.yml             # Main build pipeline
    ├── quick-build.yml                # Fast verification
    ├── chess-functionality-test.yml   # Deep testing
    └── README.md                      # Workflow documentation
```

## Contribution Workflow

1. **Fork/Clone**: Get the repository
2. **Branch**: Create a feature branch for your language. All branches MUST be linked to an issue and follow this naming format: `feat/{issue-number}-issue-slug` (e.g., `feat/85-implement-zobrist-hashing`). If an issue for the task doesn't exist, the agent SHOULD create one before starting work.
3. **Implement**: Follow the workflow above
4. **Test**: Thoroughly test with Docker
5. **Document**: Write clear README
6. **PR**: Submit pull request with:
   - Implementation in `<language>/` directory
   - Updated root README.md
   - Updated Makefile
   - Test results
7. **Review**: Address feedback
8. **Merge**: After approval, implementation is integrated

## Notes for AI Agents

- **Always read specifications first**: Don't assume chess rules, read the spec
- **Use existing implementations as templates**: Don't reinvent structure
- **Test early and often**: Build and test incrementally
- **Follow language conventions**: Use standard project layouts
- **Don't modify other languages**: Each implementation is independent
- **Docker-Mandatory Workflow**: ALL implementation-related tasks (build, test, lint, format) MUST be done via Docker. Never use local toolchains for these.
- **Flush output properly**: Critical for stdin/stdout protocol
- **Validate perft carefully**: This is the ultimate correctness check
- **Document your choices**: Explain language-specific design decisions

## Success Criteria

An implementation is successful when:

1. ✅ It builds in Docker without errors
2. ✅ It passes all automated tests
3. ✅ It meets performance targets
4. ✅ It demonstrates language features well
5. ✅ It has clear documentation
6. ✅ It follows project conventions
7. ✅ It can be maintained by others

---

**Remember**: The goal is not just to make a working chess engine, but to showcase how each programming language approaches the problem differently. Code quality, documentation, and adherence to language idioms are as important as functionality.
