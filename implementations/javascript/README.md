# JavaScript Chess Engine

A Node.js implementation of the polyglot chess engine specification.

## Features
- Full move generation (pseudo-legal moves)
- FEN import/export
- Basic AI (minimax)
- JSDoc type hinting verified with `tsc`

## Development
This implementation uses pure JavaScript but leverages TypeScript's `tsc` for type checking via JSDoc comments.

### Commands
- `make build`: Install dependencies
- `make test`: Run test suite
- `make analyze`: Run `tsc` for type checking
