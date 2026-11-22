FROM ghcr.io/evaisse/tgac-bend-toolchain:latest

WORKDIR /app
COPY . .

RUN make build

LABEL org.chess.language="bend"
LABEL org.chess.version="2.0.40"
LABEL org.chess.author="AI Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=100
LABEL org.chess.source_exts=".bend"
LABEL org.chess.build="make build"
LABEL org.chess.test="make test"
LABEL org.chess.analyze="make analyze"
LABEL org.chess.run="./chess"
LABEL org.chess.bugit="if [ -f .bugit/chess.bend.bak ]; then echo 'bugit already active for bend'; else mkdir -p .bugit && cp src/chess.bend .bugit/chess.bend.bak && printf '\ndef __bugit__(\n' >> src/chess.bend; fi"
LABEL org.chess.fix="if [ -f .bugit/chess.bend.bak ]; then mv .bugit/chess.bend.bak src/chess.bend && rmdir .bugit 2>/dev/null || true; else echo 'no bend bugit backup to restore'; fi"

CMD ["./chess"]
