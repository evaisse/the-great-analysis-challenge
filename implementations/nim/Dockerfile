FROM ubuntu:24.04

# Install Nim
RUN apt-get update && apt-get install -y \
    nim \
    && rm -rf /var/lib/apt/lists/*

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