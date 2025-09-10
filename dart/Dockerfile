# Use the official Dart image for building the application.
FROM dart:stable AS build

# Set the working directory.
WORKDIR /app

# Copy the pubspec files and get dependencies.
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the application source code.
COPY . .

# Compile the application.
RUN dart compile exe bin/main.dart -o bin/chess_engine

# Use a minimal base image for the final image.
FROM scratch

# Set the working directory.
WORKDIR /app

# Copy the compiled executable from the build stage.
COPY --from=build /app/bin/chess_engine .

# Set the entrypoint for the container.
ENTRYPOINT ["/app/chess_engine"]
