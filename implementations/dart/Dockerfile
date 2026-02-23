# Build stage
FROM dart:stable AS build

WORKDIR /app

# Copy the pubspec files and get dependencies.
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code.
COPY . .

# Compile the application.
RUN dart compile exe bin/main.dart -o bin/chess_engine

# Runtime stage
FROM dart:stable

WORKDIR /app

# Copy the compiled executable, project structure, and pub cache
COPY --from=build /app /app
COPY --from=build /root/.pub-cache /root/.pub-cache

# Set the entrypoint for the container.

LABEL org.chess.language="dart"
LABEL org.chess.version="3.0"
LABEL org.chess.author="Dart Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=900
LABEL org.chess.test="dart test"
LABEL org.chess.analyze="dart analyze"

CMD ["./bin/chess_engine"]
