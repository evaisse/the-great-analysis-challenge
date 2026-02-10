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

LABEL org.chess.language="php"
LABEL org.chess.version="8.3"
LABEL org.chess.author="PHP Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.build="php -l chess.php"
LABEL org.chess.test="echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | php chess.php"
LABEL org.chess.analyze="find . -name '*.php' -exec php -l {} \;"

CMD ["php", "chess.php"]
