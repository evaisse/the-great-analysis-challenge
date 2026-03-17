FROM ghcr.io/evaisse/tgac-rust-toolchain:latest

COPY . .

RUN cargo build --release

LABEL org.chess.language="rust"
LABEL org.chess.version="1.70"
LABEL org.chess.author="Rust Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=600
LABEL org.chess.source_exts=".rs"
LABEL org.chess.build="cargo build --release"
LABEL org.chess.test="cargo test"
LABEL org.chess.analyze="cargo check --all-targets"
LABEL org.chess.bugit="if [ -f .bugit/main.rs.bak ]; then echo 'bugit already active for rust'; else mkdir -p .bugit && cp src/main.rs .bugit/main.rs.bak && printf '\n)\n' >> src/main.rs; fi"
LABEL org.chess.fix="if [ -f .bugit/main.rs.bak ]; then mv .bugit/main.rs.bak src/main.rs && rmdir .bugit 2>/dev/null || true; else echo 'no rust bugit backup to restore'; fi"

CMD ["./target/release/chess"]
