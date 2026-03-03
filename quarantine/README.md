# Quarantine

Implementations in this directory are **temporarily quarantined** — they fail `make workflow` and need further fixes before being moved back to `implementations/`.

## Quarantined Implementations

### `rescript`
**Status**: Test failure  
**Reason**: The toolchain image ships ReScript 12, but the committed pre-compiled JS output (`lib/es6/src/`) was generated with ReScript 11 and references the rescript 11 runtime path `rescript/lib/es6/`. Node.js cannot resolve `rescript/lib/es6/belt_Int.js` etc. because they no longer exist in rescript 12's package layout.  
**Fix needed**: Recompile all source files inside the rescript 12 toolchain container and recommit the generated JS output.

### `elm`
**Status**: Build failure  
**Reason**: The Dockerfile runs `elm make src/ChessEngine.elm --output=src/chess.js` at build time, which requires network connectivity to resolve Elm package dependencies. The pre-compiled output (`src/chess.js`) is not committed to the repository, so the Docker build fails in restricted-network environments.  
**Fix needed**: Either commit the pre-compiled `src/chess.js` to the repo, or add an `elm.json` with `direct` deps that can be cached, or restructure to ship the compiled output.

### `julia`
**Status**: Analyze failure  
**Reason**: The `org.chess.analyze` Dockerfile LABEL contains single-quotes inside a shell command (`julia --project=. -e 'include("chess.jl"); println("Syntax OK")'`), which breaks shell parsing when the value is extracted from the LABEL and passed to `sh -c "…"`.  
**Fix needed**: Replace the analyze command with one that doesn't require single-quotes inside double-quotes — e.g. use a wrapper script or rewrite the Julia invocation to avoid embedded quotes.

### `mojo`
**Status**: Build timeout  
**Reason**: The base Docker image is ~5.4 GB and exceeds the time budget in the restricted-network sandbox environment used for workflow execution.  
**Fix needed**: Either use a lighter-weight Mojo base image (e.g. a pre-built community image with only the Mojo runtime), or split the build into a multi-stage Dockerfile to reduce final image size.

## How to Re-admit an Implementation

Once the fix is applied:

1. Verify the fix locally:
   ```bash
   make workflow DIR=<language>   # from the implementations/ directory
   ```
2. Move it back:
   ```bash
   mv quarantine/<language> implementations/<language>
   ```
3. Run the full workflow again to confirm.
