FROM ghcr.io/evaisse/tgac-nim-toolchain:latest

COPY . .

RUN nim c -d:release chess.nim

LABEL org.chess.language="nim"
LABEL org.chess.version="2.0"
LABEL org.chess.author="Nim Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="nim c -d:release chess.nim"
LABEL org.chess.test="./chess --test"
LABEL org.chess.analyze="nim check chess.nim"

CMD ["./chess"]
