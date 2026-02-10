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
