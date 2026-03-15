FROM ghcr.io/evaisse/tgac-go-toolchain:latest

COPY . .

RUN go build -ldflags="-s -w" -o chess .

LABEL org.chess.language="go"
LABEL org.chess.version="1.23"
LABEL org.chess.author="AI Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=800
LABEL org.chess.source_exts=".go"
LABEL org.chess.build="go build -o chess ."
LABEL org.chess.test="go test ./..."
LABEL org.chess.analyze="go vet ./... && gofmt -d ."
LABEL org.chess.bugit="if [ -f .bugit/types.go.bak ]; then echo 'bugit already active for go'; else mkdir -p .bugit && cp types.go .bugit/types.go.bak && printf '\nfunc __bugit__( {\n' >> types.go; fi"
LABEL org.chess.fix="if [ -f .bugit/types.go.bak ]; then mv .bugit/types.go.bak types.go && rmdir .bugit 2>/dev/null || true; else echo 'no go bugit backup to restore'; fi"

CMD ["./chess"]
