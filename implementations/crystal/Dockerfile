# Use official Crystal image
FROM crystal:1.15-alpine

# Install make for the test suite
RUN apk add --no-cache make

# Set working directory
WORKDIR /app

# Copy source files
COPY shard.yml ./
COPY src/ ./src/

# Build the application
RUN crystal build src/chess_engine.cr --release -o chess_engine

# Make executable
RUN chmod +x chess_engine

# Default command

LABEL org.chess.language="crystal"
LABEL org.chess.version="1.14.0"
LABEL org.chess.author="Crystal Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="crystal build src/chess_engine.cr --release -o chess_engine"
LABEL org.chess.test="crystal spec"
LABEL org.chess.analyze="crystal tool format --check src/ && crystal build src/chess_engine.cr --no-codegen"

CMD ["./chess_engine"]
