# Use official Go image
FROM golang:1.23

WORKDIR /app
COPY . .

# Build the application
RUN go build -ldflags="-s -w" -o chess .

# Default command

LABEL org.chess.language="go"
LABEL org.chess.version="1.23"
LABEL org.chess.author="AI Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.build="go build -o chess ."
LABEL org.chess.test="go test ./..."
LABEL org.chess.analyze="go vet ./... && gofmt -d ."

CMD ["./chess"]
