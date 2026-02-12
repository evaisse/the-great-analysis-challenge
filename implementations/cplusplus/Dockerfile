FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and C++ compiler
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy source files
COPY . .

# Compile the chess engine with optimizations
RUN g++ -std=c++17 -O2 -Wall -Wextra -o chess chess.cpp

# Set the command to run the chess engine
CMD ["./chess"]
