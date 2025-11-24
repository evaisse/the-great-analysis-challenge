# Work In Progress (WIP) Implementations

This directory contains chess engine implementations that are currently not fully working or have build issues.

## Go (`go`)

**Issue:** Build structure mismatch.
- The implementation defines `package main` in both the root `chess.go` and files in `src/`.
- The `Makefile` runs `go build -o chess .`, which ignores the files in `src/` because they are in a subdirectory.
- In Go, a package cannot be split across directories in this manner without importing.
- **Fix required:** Either move all source files to the root, or restructure `src/` as a proper library package and import it in `chess.go`.

## Swift (`swift`)

**Issue:** Folder structure mismatch.
- The `Package.swift` defines an executable target `Chess` without specifying a path. By convention, Swift Package Manager looks for sources in `Sources/Chess`.
- The source files are located in `src/`.
- `swift build` fails to find the source files.
- **Fix required:** Move `src/main.swift` (and other files) to `Sources/Chess/`, or update `Package.swift` to point to `src`.
