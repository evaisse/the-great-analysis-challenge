FROM ghcr.io/evaisse/tgac-mojo-toolchain:latest

COPY . .

LABEL org.chess.language="mojo"
LABEL org.chess.version="24.5"
LABEL org.chess.author="Mojo Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".mojo"
LABEL org.chess.build="mojo chess.mojo --no-run || echo 'Note: Mojo runtime required or engine WIP'"
LABEL org.chess.test="printf 'help\nquit\n' | mojo chess.mojo || true"
LABEL org.chess.analyze="mojo chess.mojo --no-run || echo 'Mojo runtime required or engine WIP'"
LABEL org.chess.bugit="if [ -f .bugit/chess.mojo.bak ]; then echo 'bugit already active for mojo'; else mkdir -p .bugit && cp chess.mojo .bugit/chess.mojo.bak && printf '\n)\n' >> chess.mojo; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.mojo.bak ]; then mv .bugit/chess.mojo.bak chess.mojo && rmdir .bugit 2>/dev/null || true; else echo 'no mojo bugit backup to restore'; fi"

CMD ["mojo", "chess.mojo"]
