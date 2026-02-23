# Use official PHP image
FROM php:8.3-cli

# Set working directory
WORKDIR /app

# Copy composer.json if it exists
COPY composer.json* ./

# Copy source code
COPY . .

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
