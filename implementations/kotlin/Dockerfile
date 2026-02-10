# Use official Gradle image
FROM gradle:8.12-jdk21-slim

# Set working directory
WORKDIR /app

# Copy all source files
COPY . .

# Build the application
RUN gradle build --no-daemon

# Run the chess engine
CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]
