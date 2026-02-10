# Use official Haskell image
FROM haskell:9.6

WORKDIR /app

# Copy project files
COPY chess.cabal ./
COPY src/ src/

# Install dependencies and build
RUN cabal update && cabal build

# Run the chess engine

LABEL org.chess.language="haskell"
LABEL org.chess.version="9.0"
LABEL org.chess.author="Haskell Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.run="./chess"
LABEL org.chess.build="cabal build"
LABEL org.chess.test="cabal test"
LABEL org.chess.analyze="hlint . && cabal check"

CMD ["cabal", "run", "chess"]
