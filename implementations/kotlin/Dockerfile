# Build stage
FROM gradle:jdk21 AS build

WORKDIR /app
COPY . .

# Build the application
RUN gradle build --no-daemon

# Runtime stage
FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app

# Install make for the test suite
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy the built jar and project structure
COPY --from=build /app /app

# Default command to run the chess engine
CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]

LABEL org.chess.language="kotlin"
LABEL org.chess.version="1.9.10"
LABEL org.chess.author="Kotlin Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=500
LABEL org.chess.run="./gradlew run"
LABEL org.chess.build="./gradlew build"
LABEL org.chess.test="./gradlew test"
LABEL org.chess.analyze="./gradlew ktlintCheck detekt"

CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]
