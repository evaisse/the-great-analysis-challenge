FROM ghcr.io/evaisse/tgac-ruby-toolchain:latest

COPY . .

RUN bundle install

LABEL org.chess.language="ruby"
LABEL org.chess.version="3.4"
LABEL org.chess.author="Ruby Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.source_exts=".rb"
LABEL org.chess.benchmark.build="skip"
LABEL org.chess.build="ruby -c chess.rb"
LABEL org.chess.test="rspec"
LABEL org.chess.analyze="bundle exec rubocop --fail-level E"
LABEL org.chess.bugit="if [ -f .bugit/chess.rb.bak ]; then echo 'bugit already active for ruby'; else mkdir -p .bugit && cp chess.rb .bugit/chess.rb.bak && printf '\n)\n' >> chess.rb; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.rb.bak ]; then mv .bugit/chess.rb.bak chess.rb && rmdir .bugit 2>/dev/null || true; else echo 'no ruby bugit backup to restore'; fi"

CMD ["ruby", "chess.rb"]
