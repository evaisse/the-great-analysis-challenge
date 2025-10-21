# Multi-stage build
FROM openjdk:11-jdk-slim as build

WORKDIR /app

# Copy all source files and build script
COPY . .

# Build the application
RUN ./gradlew build

# Runtime stage
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy the built JAR file
COPY --from=build /app/build/libs/*.jar chess-engine.jar

# Run the chess engine
CMD ["java", "-jar", "chess-engine.jar"]