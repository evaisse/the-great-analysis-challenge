FROM ghcr.io/evaisse/tgac-c-toolchain:latest

WORKDIR /app
COPY . .

RUN make build

LABEL org.chess.language="c"
LABEL org.chess.version="C11"
LABEL org.chess.author="AI Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=700
LABEL org.chess.source_exts=".c,.h"
LABEL org.chess.build="make build"
LABEL org.chess.test="make test"
LABEL org.chess.analyze="make analyze"
LABEL org.chess.bugit="if [ -f .bugit/chess.c.bak ]; then echo 'bugit already active for c'; else mkdir -p .bugit && cp src/chess.c .bugit/chess.c.bak && printf '\nint __bugit__(\n' >> src/chess.c; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.c.bak ]; then mv .bugit/chess.c.bak src/chess.c && rmdir .bugit 2>/dev/null || true; else echo 'no c bugit backup to restore'; fi"
LABEL org.chess.run="./chess"

CMD ["./chess"]
