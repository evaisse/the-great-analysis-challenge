# Contributing to The Great Analysis Challenge

Thank you for your interest in contributing to The Great Analysis Challenge! This document provides guidelines and instructions for contributing to this polyglot chess engine project.

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Types of Contributions](#types-of-contributions)
- [Getting Started](#getting-started)
- [Adding a New Language Implementation](#adding-a-new-language-implementation)
- [Improving Existing Implementations](#improving-existing-implementations)
- [Documentation Contributions](#documentation-contributions)
- [Reporting Issues](#reporting-issues)
- [Pull Request Process](#pull-request-process)
- [Code of Conduct](#code-of-conduct)
- [Questions and Support](#questions-and-support)

## 🎯 Project Overview

The Great Analysis Challenge is a project that implements the same chess engine specification across multiple programming languages. The goal is to:

1. **Compare Languages**: Demonstrate how different programming languages approach the same problem
2. **Fair Benchmarking**: Provide consistent specifications for fair comparison
3. **Educational Value**: Showcase language-specific features and paradigms
4. **Performance Analysis**: Compare compilation times, execution speed, and resource usage
5. **Developer Experience**: Document development workflow, tooling, and debugging approaches

## 🤝 Types of Contributions

We welcome the following types of contributions:

### 1. New Language Implementations

Add a chess engine implementation in a new programming language.

**Requirements:**
- Follow the [Chess Engine Specification](./CHESS_ENGINE_SPECS.md)
- Complete all required features
- Pass all automated tests
- Include comprehensive documentation

### 2. Bug Fixes

Fix bugs in existing implementations or infrastructure.

**Guidelines:**
- Include clear description of the bug
- Add tests if applicable
- Don't modify working code unnecessarily
- Follow the language's coding conventions

### 3. Performance Optimizations

Improve the performance of existing implementations.

**Guidelines:**
- Benchmark before and after changes
- Document the optimization approach
- Maintain code readability
- Don't sacrifice correctness for speed

### 4. Documentation Improvements

Enhance project documentation.

**Areas:**
- Implementation READMEs
- Usage examples
- Architecture explanations
- Setup instructions

### 5. Testing Enhancements

Improve test coverage and test infrastructure.

**Guidelines:**
- Follow existing test patterns
- Document test cases
- Ensure tests are reproducible

## 🚀 Getting Started

### Prerequisites

- **Docker**: All builds and tests run in Docker containers
- **Git**: Version control
- **Make**: Build automation (optional but recommended)
- **Language-specific tools**: Only if developing outside Docker

### Initial Setup

1. **Fork the repository:**
   ```bash
   # Via GitHub UI or gh CLI
   gh repo fork evaisse/the-great-analysis-challenge --clone
   ```

2. **Clone your fork:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/the-great-analysis-challenge.git
   cd the-great-analysis-challenge
   ```

3. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   # or for new implementations:
   git checkout -b implementation/language-name
   ```

4. **Verify the setup:**
   ```bash
   # Test an existing implementation
   cd implementations/python
   make docker-build
   make docker-test
   ```

## 🔧 Adding a New Language Implementation

Follow these steps to add a new language implementation:

### Phase 1: Planning (5-10 minutes)

1. **Check if the language already exists:**
   ```bash
   ls implementations/
   ```

2. **Review the specifications:**
   - Read [CHESS_ENGINE_SPECS.md](./CHESS_ENGINE_SPECS.md) thoroughly
   - Review [README_IMPLEMENTATION_GUIDELINES.md](./README_IMPLEMENTATION_GUIDELINES.md)
   - Check [AGENTS.md](./AGENTS.md) for detailed workflow

3. **Study existing implementations:**
   - Look at similar languages for reference
   - Ruby, Python, and TypeScript are well-documented starting points

### Phase 2: Setup (15-30 minutes)

1. **Create the language directory:**
   ```bash
   mkdir implementations/<language>
   cd implementations/<language>
   ```

2. **Create required files:**

   **`Dockerfile`** - Build and runtime environment
   ```dockerfile
   FROM <base-image>
   WORKDIR /app
   COPY . .
   # Build commands here
   CMD ["<run-command>"]
   ```

   **`chess.meta`** - Metadata JSON
   ```json
   {
     "language": "<language_name>",
     "version": "<language_version>",
     "author": "Your Name",
     "build": "<build_command>",
     "run": "<run_command>",
     "analyze": "<analysis_command>",
     "test": "<test_command>",
     "features": ["perft", "fen", "ai", "castling", "en_passant", "promotion"],
     "max_ai_depth": 5,
     "estimated_perft4_ms": 1000
   }
   ```

   **`Makefile`** - Build automation
   ```makefile
   .PHONY: all test analyze clean docker-build docker-test

   all: build

   build:
       # Language-specific build commands

   test:
       # Language-specific test commands

   analyze:
       # Linters, type checkers, etc.

   clean:
       # Remove build artifacts

   docker-build:
       docker build -t chess-$(shell basename $(PWD)) .

   docker-test: docker-build
       # Replace <run_command> with your language's executable, e.g. 'python main.py', './chess', etc.
       docker run --rm -i chess-$(shell basename $(PWD)) sh -c "echo -e 'new\\nmove e2e4\\nmove e7e5\\nexport\\nquit' | <run_command>"
   ```

   **`README.md`** - Implementation documentation (see existing implementations for template)

### Phase 3: Implementation (2-8 hours)

Implement the chess engine components in this order:

1. **Board Representation** (30-60 min)
   - 8x8 board structure
   - Piece representation
   - Position state

2. **Move Generator** (60-120 min)
   - Pseudo-legal move generation
   - Move validation
   - Special moves (castling, en passant, promotion)

3. **FEN Parser** (30-45 min)
   - Parse FEN strings
   - Export to FEN format

4. **Game State Manager** (45-90 min)
   - Execute/undo moves
   - Game history
   - Checkmate/stalemate detection

5. **Command Interface** (30-45 min)
   - stdin/stdout protocol
   - Command parsing
   - Board display

6. **AI Engine** (90-180 min)
   - Minimax with alpha-beta pruning
   - Position evaluation
   - Move ordering

### Phase 4: Testing (1-2 hours)

1. **Test locally:**
   ```bash
   # Build
   make docker-build

   # Basic test
   echo -e "new\nmove e2e4\nmove e7e5\nexport\nquit" | docker run -i chess-<language>

   # AI test
   echo -e "new\nai 3\nquit" | docker run -i chess-<language>

   # Perft test (should return 197281)
   echo -e "new\nperft 4\nquit" | docker run -i chess-<language>
   ```

2. **Run automated tests:**
   ```bash
   make test
   make docker-test
   ```

3. **Verify compliance:**
   ```bash
   # From project root
   python3 test/verify_implementations.py
   ```

### Phase 5: Documentation (30-45 minutes)

1. **Complete your implementation README.md** with:
   - Overview and features
   - Build instructions
   - Usage examples
   - Performance characteristics
   - Language-specific notes

2. **Update root README.md:**
   - Add your language to the implementation status table
   - Include build time, analysis time, and features
   - Update the language list section

3. **Test documentation accuracy:**
   - Follow your own instructions from scratch
   - Verify all commands work as documented

### Phase 6: Submission

1. **Commit your changes:**
   ```bash
   git add implementations/<language>/
   git add README.md  # If you updated it
   git commit -m "Add <language> implementation"
   ```

2. **Push to your fork:**
   ```bash
   git push origin implementation/<language>
   ```

3. **Create a Pull Request:**
   - Use the PR template
   - Fill in all relevant sections
   - Link to any related issues

## 🔄 Improving Existing Implementations

### Guidelines

1. **Discuss first:** For significant changes, open an issue to discuss the approach
2. **Test thoroughly:** Ensure all tests pass before and after your changes
3. **Document changes:** Update README if behavior or performance changes
4. **Maintain compatibility:** Don't break the chess engine specification
5. **Follow conventions:** Use the language's idiomatic style

### Process

1. Create a feature branch from `main`
2. Make your changes
3. Test locally with Docker
4. Run automated tests
5. Update documentation if needed
6. Submit a Pull Request

## 📝 Documentation Contributions

Documentation improvements are always welcome!

### Areas to Improve

- README clarifications
- Tutorial additions
- Example enhancements
- API documentation
- Architecture diagrams
- Performance guides

### Process

1. Identify documentation gaps or issues
2. Make your improvements
3. Test any code examples
4. Submit a PR with clear description of changes

## 🐛 Reporting Issues

### Before Reporting

1. Check existing issues to avoid duplicates
2. Test with the latest version
3. Verify the issue in Docker (not just local environment)

### Issue Template

**For bugs:**
- Language/implementation affected
- Expected behavior
- Actual behavior
- Steps to reproduce
- Environment details (Docker version, OS)
- Relevant logs or error messages

**For feature requests:**
- Clear description of the feature
- Use cases and benefits
- Possible implementation approach

**For new language suggestions:**
- Language name and version
- Why it would be a good addition
- Your willingness to implement it

## 📥 Pull Request Process

### Before Submitting

1. **Test thoroughly:**
   - Build succeeds in Docker
   - All tests pass
   - No regressions introduced

2. **Code quality:**
   - Follow language conventions
   - Use linters/formatters
   - Add comments where needed
   - Keep changes focused

3. **Documentation:**
   - Update relevant README files
   - Add/update code comments
   - Document breaking changes

### PR Submission

1. **Use the PR template:** Fill in all applicable sections
2. **Write clear title:** Use conventional commit format if possible
3. **Describe changes:** Explain what, why, and how
4. **Link issues:** Reference any related issues
5. **Request review:** Tag relevant maintainers if needed

### PR Review Process

1. **Automated checks:** CI/CD will run tests and checks
2. **Code review:** Maintainers will review your code
3. **Feedback:** Address any requested changes
4. **Approval:** Once approved, maintainers will merge

### After Merge

- Your contribution will be included in the next release
- Update your fork to stay in sync
- Celebrate! 🎉

## 📜 Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the project
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Personal or political attacks
- Publishing others' private information
- Other unprofessional conduct

### Enforcement

Violations should be reported to the project maintainers. All complaints will be reviewed and investigated promptly and fairly.

## ❓ Questions and Support

### Getting Help

1. **Documentation:** Check the README files and specifications first
2. **Examples:** Review existing implementations for reference
3. **Issues:** Search existing issues for similar questions
4. **Discussions:** Open a GitHub Discussion for general questions
5. **Issues:** Create an issue for specific problems

### Community

- Be patient with responses
- Help others when you can
- Share your learnings
- Provide feedback on the process

## 🙏 Acknowledgments

Thank you for contributing to The Great Analysis Challenge! Every contribution, no matter how small, helps make this project better.

### Recognition

- All contributors will be recognized in the project
- Significant contributions may be highlighted in release notes
- New language implementations are especially celebrated

---

**Happy coding! ♟️**

For detailed technical specifications, please refer to:
- [Chess Engine Specification](./CHESS_ENGINE_SPECS.md)
- [Implementation Guidelines](./README_IMPLEMENTATION_GUIDELINES.md)
- [Agent Instructions](./AGENTS.md)
