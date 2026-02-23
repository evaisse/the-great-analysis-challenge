FROM ghcr.io/evaisse/tgac-ruby-toolchain:latest

COPY . .

LABEL org.chess.language="ruby"
LABEL org.chess.version="3.4"
LABEL org.chess.author="Ruby Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.test="rspec"
LABEL org.chess.analyze="rubocop"

CMD ["ruby", "chess.rb"]
