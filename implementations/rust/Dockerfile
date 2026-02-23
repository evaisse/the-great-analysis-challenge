# Build stage
FROM rust:1.84-slim AS builder

WORKDIR /app
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage
FROM rust:1.84-slim

WORKDIR /app

# Copy the compiled binary and source code from the builder stage
COPY --from=builder /app /app

# Default command

LABEL org.chess.language="rust"
LABEL org.chess.version="1.70"
LABEL org.chess.author="Rust Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=600
LABEL org.chess.test="cargo test"
LABEL org.chess.analyze="cargo clippy -- -D warnings"

CMD ["./target/release/chess"]
