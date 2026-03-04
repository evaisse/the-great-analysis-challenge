FROM ghcr.io/evaisse/tgac-rust-toolchain:latest

RUN apt-get update && apt-get install -y --no-install-recommends make && rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build --release

LABEL org.chess.language="rust"
LABEL org.chess.version="1.70"
LABEL org.chess.author="Rust Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=600
LABEL org.chess.test="cargo test"
LABEL org.chess.analyze="cargo clippy -- -D warnings"

CMD ["./target/release/chess"]
