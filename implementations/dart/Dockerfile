FROM dart:stable-sdk AS build

# Set the working directory.
WORKDIR /app

# Copy the pubspec files and get dependencies.
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code.
COPY . .

# Compile the application.
# `dart pub get` must have already run to ensure all dependencies are resolved.
RUN dart compile exe bin/main.dart -o bin/chess_engine

# --- Runtime Image ---
FROM dart:stable-sdk

# Install make
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Set the working directory.
WORKDIR /app

# Copy the compiled executable and project structure
COPY --from=build /app /app

# Set the entrypoint for the container.
CMD ["./bin/chess_engine"]
