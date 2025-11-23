# Chess Implementation Status

## Working Implementations ✅

The following implementations successfully build in Docker and pass basic tests (`new`, `move e2e4`, `move e7e5`, `export`, `quit`):

1. **TypeScript** - Fixed shallow copy issue in Board.getState()
2. **Go** - Fixed Dockerfile and command handling
3. **Rust** - Changed to official Rust Docker image
4. **Ruby** - Fixed user creation syntax in Dockerfile
5. **Nim** - Fixed EOF handling for piped input
6. **PHP** - Already working
7. **Python** - Already working
8. **Lua** - Already working
9. **Swift** - Fixed command handlers and board display

## Implementations with Issues 🔧

### Crystal
- **Issue**: Stack overflow during board display after "new" command
- **Root Cause**: Infinite recursion in GameState.dup or display logic
- **Status**: Needs further investigation

### Zig
- **Issue**: Cannot build, no official Zig Docker image available
- **Error**: Network issues when trying to download Zig
- **Status**: Blocked on Docker image availability

### Julia, Kotlin, Haskell, Gleam, Dart, Elm, ReScript, Mojo
- **Issue**: Network connectivity issues during Docker build
- **Error**: Cannot download language/tooling dependencies via wget/curl
- **Status**: Blocked on network/proxy configuration

## Changes Made

### Makefile
- Changed all `echo -e` commands to `printf` for better portability
- All test targets now use: `printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n'`

### Dockerfiles
- **Ruby**: Changed `addgroup`/`adduser` to `groupadd`/`useradd` for Ubuntu compatibility
- **ReScript**: Same user creation fix
- **Rust**: Changed from Ubuntu base to `rust:latest` image
- **Swift**: Changed from Ubuntu base to `swift:5.9` image
- **Zig**: Attempted to use Alpine and official images (both failed)

### Code Fixes
- **TypeScript**: Fixed `Board.getState()` to create deep copies of board, castling rights, and move history
- **Nim**: Added `try-except` block for `EOFError` when reading stdin  
- **Swift**: Added board display after `new` and `move` commands; removed broken `undo` handler
- **Crystal**: Modified `GameState.dup` and `Board.display` (still has stack overflow)

## Test Summary

**Passing**: 9/18 implementations tested
**Network Issues**: 9 implementations
**Code Issues**: 1 implementation (Crystal)
**Build Issues**: 1 implementation (Zig)
