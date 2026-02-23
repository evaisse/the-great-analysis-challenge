# Use official Lua image
FROM nickblah/lua:5.4-alpine

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Default command to run the chess engine

LABEL org.chess.language="lua"
LABEL org.chess.version="5.4"
LABEL org.chess.author="Lua Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="lua -e \"assert(loadfile('chess.lua'))\""
LABEL org.chess.test="echo -e 'new\nmove e2e4\nmove e7e5\nexport\nquit' | lua chess.lua"
LABEL org.chess.analyze="lua -l chess.lua"

CMD ["lua", "chess.lua"]
