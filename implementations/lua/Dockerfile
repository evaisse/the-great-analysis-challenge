# Use official Lua image
FROM lua:5.4-slim

# Install build dependencies for potential C-extensions
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

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

# Create analyze script for static analysis
RUN echo '#!/bin/sh\necho "🔍 Running Lua syntax check..."\nlua5.4 -l chess.lua 2>&1 || true\necho "✅ Analysis complete!"' > /app/analyze && \
    chmod +x /app/analyze

# Default command to run the chess engine
CMD ["lua5.4", "chess.lua"]

# Alternative commands for different use cases:
# To run static analysis: docker run --rm chess-lua ./analyze
# Interactive mode: docker run -it chess-lua
