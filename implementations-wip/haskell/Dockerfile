FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Haskell
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    libffi-dev \
    libgmp-dev \
    zlib1g-dev \
    libtinfo-dev \
    ghc \
    cabal-install \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy project files
COPY chess.cabal ./
COPY src/ src/

# Install dependencies and build
RUN cabal update && cabal build

# Run the chess engine
CMD ["cabal", "run", "chess"]