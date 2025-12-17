FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Java
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

# Install Gradle
RUN GRADLE_VERSION="8.0" \
    && wget "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" \
    && unzip "gradle-${GRADLE_VERSION}-bin.zip" \
    && mv "gradle-${GRADLE_VERSION}" /opt/gradle \
    && ln -s /opt/gradle/bin/gradle /usr/local/bin/gradle \
    && rm "gradle-${GRADLE_VERSION}-bin.zip"

WORKDIR /app

# Copy all source files and build script
COPY . .

# Build the application
RUN gradle build

# Run the chess engine
CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]