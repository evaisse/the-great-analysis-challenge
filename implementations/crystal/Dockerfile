# Use official Crystal image
FROM jfrog.int.bourso.net/web-v-docker/crystallang/crystal:latest

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

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
LABEL org.chess.build="make docker-build"
LABEL org.chess.run="docker run --rm -i chess-crystal"
LABEL org.chess.test="make docker-test"
LABEL org.chess.analyze="docker run --rm chess-crystal make analyze"

CMD ["./chess_engine"]
