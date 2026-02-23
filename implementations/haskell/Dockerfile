# Use official Haskell image
FROM haskell:9.6 AS builder

WORKDIR /app

# Copy project files
COPY src/ src/

# Build directly with GHC (much faster for projects without external deps)
RUN ghc -O2 --make src/Main.hs -o chess_engine -i/app/src

# Final stage
FROM debian:bookworm-slim

WORKDIR /app

# We remove libgmp10 from here as requested.
# If the binary requires it, it will fail at runtime, 
# signalling that a native-bignum GHC build is required.
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/chess_engine ./

LABEL org.chess.language="haskell"
LABEL org.chess.version="9.0"
LABEL org.chess.author="Haskell Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.run="./chess_engine"
LABEL org.chess.build="cabal build"
LABEL org.chess.test="cabal test"
LABEL org.chess.analyze="hlint . && cabal check"

CMD ["./chess_engine"]
