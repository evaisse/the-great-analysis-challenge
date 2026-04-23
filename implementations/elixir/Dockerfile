FROM ghcr.io/evaisse/tgac-elixir-toolchain:latest

WORKDIR /app
COPY . .

RUN mix compile --warnings-as-errors

LABEL org.chess.language="elixir"
LABEL org.chess.version="1.17"
LABEL org.chess.author="AI Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1500
LABEL org.chess.source_exts=".ex,.exs"
LABEL org.chess.build="mix compile --warnings-as-errors"
LABEL org.chess.test="mix run --no-compile -e \"ChessEngine.SelfTest.main()\""
LABEL org.chess.analyze="mix format --check-formatted && mix compile --warnings-as-errors"
LABEL org.chess.bugit="if [ -f .bugit/chess_engine.ex.bak ]; then echo 'bugit already active for elixir'; else mkdir -p .bugit && cp lib/chess_engine.ex .bugit/chess_engine.ex.bak && printf '\n  def __bugit__( do\n' >> lib/chess_engine.ex; fi"
LABEL org.chess.fix="if [ -f .bugit/chess_engine.ex.bak ]; then mv .bugit/chess_engine.ex.bak lib/chess_engine.ex && rmdir .bugit 2>/dev/null || true; else echo 'no elixir bugit backup to restore'; fi"
LABEL org.chess.run="mix run --no-compile -e \"ChessEngine.CLI.main()\""

CMD ["mix", "run", "--no-compile", "-e", "ChessEngine.CLI.main()"]
