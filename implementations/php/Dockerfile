# Use official PHP image
FROM php:8.3-cli-alpine

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache make

# Copy composer.json if it exists
COPY composer.json* ./

# Install dependencies if composer.json exists
RUN if [ -f composer.json ]; then \
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
    composer install --no-dev --optimize-autoloader; \
    fi

# Copy source code
COPY . .

# Create a non-root user
RUN addgroup -S php && adduser -S chess -G php

# Change ownership of the app directory
RUN chown -R chess:php /app

# Switch to non-root user
USER chess

# Make chess.php executable
RUN chmod +x chess.php

# Default command to run the chess engine
CMD ["php", "chess.php"]
