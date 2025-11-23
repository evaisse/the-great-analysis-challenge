# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Ruby
RUN apt-get update && apt-get install -y \
    ruby \
    ruby-dev \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile first for better caching
COPY Gemfile ./

# Install bundler and gems
RUN gem install bundler && bundle install

# Copy source code
COPY . .

# Create a non-root user
RUN groupadd -g 1001 ruby && \
    useradd -u 1001 -g ruby -m -s /bin/bash chess

# Change ownership of the app directory
RUN chown -R chess:ruby /app

# Switch to non-root user
USER chess

# Make chess.rb executable
RUN chmod +x chess.rb

# Create an analyze script for easy static analysis
RUN echo '#!/bin/sh\nbundle exec rubocop --format progress' > /app/analyze && \
    chmod +x /app/analyze

# Default command to run the chess engine
CMD ["ruby", "chess.rb"]

# Alternative commands for different use cases:
# To run static analysis: docker run --rm chess-ruby ./analyze
# To run rubocop: docker run --rm chess-ruby bundle exec rubocop
# Interactive mode: docker run -it chess-ruby