FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Crystal
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    build-essential \
    pkg-config \
    libssl-dev \
    libxml2-dev \
    libyaml-dev \
    libgmp-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Crystal
RUN curl -fsSL https://packagecloud.io/84codes/crystal/gpgkey | gpg --dearmor -o /etc/apt/trusted.gpg.d/84codes_crystal.gpg \
    && echo "deb https://packagecloud.io/84codes/crystal/ubuntu/ jammy main" > /etc/apt/sources.list.d/crystal.list \
    && apt-get update \
    && apt-get install -y crystal \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy source files
COPY shard.yml ./
COPY src/ ./src/

# Build the application
RUN crystal build src/chess_engine.cr --release -o chess_engine

# Make executable
RUN chmod +x chess_engine

# Default command
CMD ["./chess_engine"]