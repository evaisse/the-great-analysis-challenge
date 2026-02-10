# Use official Haskell image
FROM haskell:9.10-slim

WORKDIR /app

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY chess.cabal ./
COPY src/ src/

# Install dependencies and build
RUN cabal update && cabal build

# Run the chess engine
CMD ["cabal", "run", "chess"]
