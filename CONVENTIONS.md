# Project Conventions

## 🌟 The Golden Rule

**Infrastructure tooling must be agnostic of implementation details.**

This means that build scripts, Makefiles, and CI/CD pipelines should **never** contain hardcoded references to specific languages or implementation details (e.g., "run `node dist/main.js` for TypeScript").

Instead, we rely on **Convention over Configuration**.

## Docker Interface

Every implementation MUST provide a `Dockerfile` that adheres to the following contract:

1.  **Self-Contained**: The image must contain all necessary dependencies and build artifacts.
2.  **Default Execution**: The `CMD` or `ENTRYPOINT` instruction must be set to run the chess engine executable.
3.  **Standard I/O**: The engine must read commands from `stdin` and write to `stdout`.

### Example

**Correct (Dockerfile):**
```dockerfile
# ... build steps ...
CMD ["./chess_engine"]
```

**Incorrect (Makefile):**
```makefile
# DO NOT DO THIS
test-go:
    docker run chess-go ./chess_engine
```

**Correct (Makefile):**
```makefile
# DO THIS
test-%:
    docker run -i chess-$*
```

## Directory Structure

Each implementation must reside in `implementations/<language>/` and contain:
- `Dockerfile`: For building and running the engine.
- `chess.meta`: Metadata file describing features.
- Source code and build files.

## Adding a New Language

1.  Create `implementations/<language>/`.
2.  Add a `Dockerfile` that builds your engine and sets `CMD` to run it.
3.  Add `chess.meta`.
4.  Run `make test DIR=<language>` to verify.

No changes to the `Makefile` or other infrastructure scripts should be required.
