# Use official Kotlin image
FROM zenika/kotlin:1.9-jdk21

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
LABEL org.chess.build="kotlinc src/main/kotlin/*.kt -include-runtime -d build/libs/chess-1.0.0.jar"
LABEL org.chess.test="java -jar build/libs/chess-1.0.0.jar --test"
LABEL org.chess.analyze="kotlinc src/main/kotlin/*.kt"
