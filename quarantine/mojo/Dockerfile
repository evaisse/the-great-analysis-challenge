FROM ghcr.io/evaisse/tgac-mojo-toolchain:latest

COPY . .

LABEL org.chess.language="mojo"
LABEL org.chess.version="24.5"
LABEL org.chess.author="Mojo Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="mojo build chess.mojo"
LABEL org.chess.test="mojo chess.mojo"
LABEL org.chess.analyze="mojo chess.mojo --no-run"

CMD ["mojo", "chess.mojo"]
