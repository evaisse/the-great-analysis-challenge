FROM ghcr.io/evaisse/tgac-kotlin-toolchain:latest

COPY . .

RUN mkdir -p build/classes build/libs && \
    kotlinc src/main/kotlin/*.kt -include-runtime -d build/libs/chess-1.0.0.jar

LABEL org.chess.language="kotlin"
LABEL org.chess.version="1.9.10"
LABEL org.chess.author="Kotlin Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion,pgn,uci,chess960"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=500
LABEL org.chess.source_exts=".kt"
LABEL org.chess.run="java -jar build/libs/chess-1.0.0.jar"
LABEL org.chess.build="kotlinc src/main/kotlin/*.kt -include-runtime -d build/libs/chess-1.0.0.jar"
LABEL org.chess.test="java -jar build/libs/chess-1.0.0.jar --test"
LABEL org.chess.analyze="kotlinc src/main/kotlin/*.kt"
LABEL org.chess.bugit="if [ -f .bugit/ChessEngine.kt.bak ]; then echo 'bugit already active for kotlin'; else mkdir -p .bugit && cp src/main/kotlin/ChessEngine.kt .bugit/ChessEngine.kt.bak && printf '\n)\n' >> src/main/kotlin/ChessEngine.kt; fi"
LABEL org.chess.fix="if [ -f .bugit/ChessEngine.kt.bak ]; then mv .bugit/ChessEngine.kt.bak src/main/kotlin/ChessEngine.kt && rmdir .bugit 2>/dev/null || true; else echo 'no kotlin bugit backup to restore'; fi"

CMD ["java", "-jar", "build/libs/chess-1.0.0.jar"]
