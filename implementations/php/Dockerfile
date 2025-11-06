# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and PHP
RUN apt-get update && apt-get install -y \
    php8.3-cli \
    php8.3-mbstring \
    php8.3-xml \
    composer \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy composer files first for better caching
COPY composer.json* composer.lock* ./

# Install PHP dependencies if composer.json exists
RUN if [ -f composer.json ]; then composer install --no-dev --optimize-autoloader; fi

# Copy source code
COPY . .

# Create a non-root user
RUN addgroup --system php && \
    adduser --no-create-home --shell /bin/false --disabled-password --system --ingroup php chess

# Change ownership of the app directory
RUN chown -R chess:php /app

# Switch to non-root user
USER chess

# Make chess.php executable
RUN chmod +x chess.php

# Default command to run the chess engine
CMD ["php", "chess.php"]

# Alternative commands for different use cases:
# To run static analysis: docker run --rm chess-php ./analyze
# Interactive mode: docker run -it chess-php
