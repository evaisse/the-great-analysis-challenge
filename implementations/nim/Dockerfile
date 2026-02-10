# Use official Nim image
FROM nimlang/nim:2.2.0-alpine

# Install build dependencies
RUN apk add --no-cache build-base make

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Compile the chess engine
RUN nim compile --opt:speed chess.nim

# Make executable
RUN chmod +x chess

# Set entrypoint
ENTRYPOINT ["./chess"]


LABEL org.chess.language="nim"
LABEL org.chess.version="1.6.14"
LABEL org.chess.author="Nim Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=3
LABEL org.chess.estimated_perft4_ms=1200
LABEL org.chess.run="./chess"
LABEL org.chess.build="nim compile --opt:speed chess.nim"
LABEL org.chess.test="nim compile chess.nim && ./chess"
LABEL org.chess.analyze="nim check chess.nim"
