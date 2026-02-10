FROM gradle:8.5-jdk21-slim

# Set working directory
WORKDIR /app

# Copy all source files and build script
COPY . .

# Build the application
# This is required to compile and produce the JAR
RUN gradle build

# Run the chess engine
# Assuming the JAR name convention is correct
CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]
