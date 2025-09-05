FROM haskell:9

WORKDIR /app

# Copy project files
COPY chess.cabal ./
COPY src/ src/

# Install dependencies and build
RUN cabal update && cabal build

# Run the chess engine
CMD ["cabal", "run", "chess"]