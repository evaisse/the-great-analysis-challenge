# Use official Nim image
FROM jfrog.int.bourso.net/web-v-docker/nimlang/nim:2.2.0-alpine

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Compile the chess engine
RUN nim compile --opt:speed chess.nim

# Make executable
RUN chmod +x chess

LABEL org.chess.language="nim"
LABEL org.chess.version="2.2.0"
LABEL org.chess.author="Nim Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,zobrist,repetition"
LABEL org.chess.max_ai_depth=3
LABEL org.chess.estimated_perft4_ms=1200
LABEL org.chess.build="make docker-build"
LABEL org.chess.run="docker run --network none --rm -i chess-nim"
LABEL org.chess.test="make docker-test"
LABEL org.chess.analyze="docker run --network none --rm chess-nim nim check chess.nim"

ENTRYPOINT ["./chess"]
