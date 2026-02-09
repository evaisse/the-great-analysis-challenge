FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Dart
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    apt-transport-https \
    ca-certificates \
    make \
    && rm -rf /var/lib/apt/lists/*

# Install Dart
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/dart.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/dart.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main' | tee /etc/apt/sources.list.d/dart_stable.list \
    && apt-get update \
    && apt-get install -y dart \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory.
WORKDIR /app

# Copy the pubspec files and get dependencies.
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code.
COPY . .

# Compile the application.
RUN dart compile exe bin/main.dart -o bin/chess_engine

# Set the entrypoint for the container.
CMD ["./bin/chess_engine"]
