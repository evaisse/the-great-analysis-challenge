# Use official JDK image
FROM eclipse-temurin:21-jdk-jammy

# Set working directory
WORKDIR /app

# Install make
RUN apt-get update && apt-get install -y make && rm -rf /var/lib/apt/lists/*

# Copy all source files
COPY . .

# Build the application using the wrapper
RUN ./gradlew build --no-daemon

# Run the chess engine
CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]
