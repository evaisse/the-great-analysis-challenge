FROM gcc:14

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
LABEL org.chess.run="./chess"

CMD ["./chess"]
