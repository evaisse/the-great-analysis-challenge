# TypeScript Chess Engine Implementation

This implementation uses TypeScript/Node.js to fulfill the Great Analysis Challenge specifications.

## Structure
- `src/index.ts`: The primary entry point handling I/O and orchestration.
- `Dockerfile`: Containerization for consistent environment.
- `chess.meta`: Implementation metadata.

## Feature Showcase
This implementation showcases TypeScript's static typing applied to the tracing system for enhanced compile-time safety.

## Build and Run Instructions
Build: \`make build DIR=typescript\`
Run: \`make run DIR=typescript\` (Requires running \`npm run build\` inside the container or locally before running)

## Tracing Integration (Issue #87)
The I/O loop in \`index.ts\` implements the tracing API scaffolding, correctly responding to tracing commands by outputting structured JSON compatible with Chrome Trace Format when requested.