FROM nimlang/nim:2.0.4-alpine

# Install build dependencies if needed (for c compilation)
# The `build-base` package is a common requirement for compiling Nim projects that link to C libraries.
RUN apk update && apk add build-base \
    && rm -rf /var/cache/apk/*

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
