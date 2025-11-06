FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Java
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    openjdk-17-jdk \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

WORKDIR /app

# Copy Maven configuration first for better caching
COPY pom.xml ./

# Download dependencies
RUN mvn dependency:go-offline || true

# Copy source code
COPY . .

# Build the application
RUN mvn clean package

# Run the chess engine
CMD ["java", "-jar", "target/chess-1.0.0.jar"]
