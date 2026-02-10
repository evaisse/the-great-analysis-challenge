# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-21-jdk \
    kotlin \
    make \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Compile source files directly
RUN mkdir -p build/classes build/libs && \
    kotlinc src/main/kotlin/*.kt -include-runtime -d build/libs/chess-1.0.0.jar

# Run the chess engine
CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]

LABEL org.chess.language="kotlin"
LABEL org.chess.version="1.9.10"
LABEL org.chess.author="Kotlin Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=500
LABEL org.chess.run="java -jar build/libs/chess-1.0.0.jar"
LABEL org.chess.build="make build"
LABEL org.chess.test="make test"
LABEL org.chess.analyze="make analyze"