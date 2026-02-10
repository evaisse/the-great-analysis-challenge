FROM haskell:9.6.3-slim

WORKDIR /app

# Copy project files
COPY chess.cabal ./
COPY src/ src/

# Install dependencies and build
# `cabal update` is needed to ensure the package list is fresh
RUN cabal update && cabal build

# Run the chess engine
CMD ["cabal", "run", "chess"]
