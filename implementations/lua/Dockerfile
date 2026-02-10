# Use Debian base image
FROM debian:bookworm-slim

# Set working directory
WORKDIR /app

# Install Lua and build dependencies
RUN apt-get update && apt-get install -y \
    lua5.4 \
    build-essential \
    make \
    && rm -rf /var/lib/apt/lists/*

# Copy source code
COPY . .

# Create a non-root user
RUN addgroup --system lua && \
    adduser --no-create-home --shell /bin/false --disabled-password --system --ingroup lua chess

# Change ownership of the app directory
RUN chown -R chess:lua /app

# Switch to non-root user
USER chess

# Make chess.lua executable
RUN chmod +x chess.lua

# Default command to run the chess engine

LABEL org.chess.language="lua"
LABEL org.chess.version="5.4"
LABEL org.chess.author="Lua Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="lua5.4 -e "assert(loadfile('chess.lua'))""
LABEL org.chess.test="echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | lua5.4 chess.lua"
LABEL org.chess.analyze="lua5.4 -l chess.lua"

CMD ["lua5.4", "chess.lua"]
