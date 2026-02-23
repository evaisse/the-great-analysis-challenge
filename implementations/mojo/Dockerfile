FROM --platform=linux/amd64 xanonymous/mojo:latest

WORKDIR /app

# Ensure Mojo is on PATH (image typically installs under /root/.modular/bin)
ENV PATH="/root/.modular/bin:${PATH}"

# Copy the chess engine source code
COPY . .

LABEL org.chess.language="mojo"
LABEL org.chess.version="0.6.0"
LABEL org.chess.author="Mojo Implementation"
LABEL org.chess.features="perft,ai,fen,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.run="mojo chess.mojo"
LABEL org.chess.build="mojo chess.mojo --no-run"
LABEL org.chess.test="mojo chess.mojo"
LABEL org.chess.analyze="mojo chess.mojo --no-run"

CMD ["mojo", "chess.mojo"]
