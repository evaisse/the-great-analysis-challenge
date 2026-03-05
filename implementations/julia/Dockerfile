FROM ghcr.io/evaisse/tgac-julia-toolchain:latest

COPY . .

LABEL org.chess.language="julia"
LABEL org.chess.version="1.11"
LABEL org.chess.author="Julia Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.benchmark.build="skip"
LABEL org.chess.run="julia --project=. chess.jl"
LABEL org.chess.build="julia --project=. -e 'include(\"chess.jl\")'"
LABEL org.chess.test="echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | julia --project=. chess.jl | tail -1 | grep -q 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2'"
LABEL org.chess.analyze="julia --project=. -e 'include(\"chess.jl\")'"

CMD ["julia", "chess.jl"]
