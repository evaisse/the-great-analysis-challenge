# Build stage
FROM rust:1.84-slim AS builder

WORKDIR /app
COPY . .

# Build the application
RUN cargo build --release

# Runtime stage
FROM rust:1.84-slim

WORKDIR /app

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary and source code from the builder stage
COPY --from=builder /app /app

# Default command

LABEL org.chess.language="rust"
LABEL org.chess.version="1.70"
LABEL org.chess.author="Rust Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=600

CMD ["./target/release/chess"]
