FROM ghcr.io/evaisse/tgac-php-toolchain:latest

COPY . .

LABEL org.chess.language="php"
LABEL org.chess.version="8.3"
LABEL org.chess.author="PHP Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960,PGN Comment Show,PGN Result Checkmate Show,PGN Variation Navigation"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.source_exts=".php"
LABEL org.chess.benchmark.build="skip"
LABEL org.chess.build="php -l chess.php"
LABEL org.chess.test="printf 'new\nmove e2e4\nmove e7e5\nexport\nquit\n' | php chess.php"
LABEL org.chess.analyze="find . -name '*.php' -exec php -l {} \;"
LABEL org.chess.bugit="if [ -f .bugit/chess.php.bak ]; then echo 'bugit already active for php'; else mkdir -p .bugit && cp chess.php .bugit/chess.php.bak && printf '\n)\n' >> chess.php; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.php.bak ]; then mv .bugit/chess.php.bak chess.php && rmdir .bugit 2>/dev/null || true; else echo 'no php bugit backup to restore'; fi"

CMD ["php", "chess.php"]
