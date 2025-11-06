FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Java
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    ca-certificates-java \
    openjdk-17-jdk \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Set Java environment variables
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="$JAVA_HOME/bin:$PATH"

# Update CA certificates for Java
RUN update-ca-certificates && \
    update-ca-certificates -f

WORKDIR /app

# Copy all files
COPY . .

# Build the application using javac directly
RUN cd src/main/java && \
    javac -d /app/target/classes *.java && \
    cd /app && \
    mkdir -p target && \
    jar cvfe target/chess-1.0.0.jar Chess -C target/classes .

# Run the chess engine
CMD ["java", "-jar", "target/chess-1.0.0.jar"]
