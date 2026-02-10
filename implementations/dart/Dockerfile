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
# Use an ultra-minimal scratch image for the final deployment to reduce size.
FROM scratch
# Copy runtime dependencies from the build stage.
COPY --from=build /runtime/ /
# Copy the compiled executable.
COPY --from=build /app/bin/chess_engine /app/bin/chess_engine

# Set the entrypoint for the container.
CMD ["/app/bin/chess_engine"]
