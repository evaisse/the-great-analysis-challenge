FROM ghcr.io/evaisse/tgac-python-toolchain:latest

COPY . .

LABEL org.chess.language="python"
LABEL org.chess.version="3.11"
LABEL org.chess.author="Python Implementation"
LABEL org.chess.features="perft,fen,ai,castling,en_passant,promotion"
LABEL org.chess.max_ai_depth=5
LABEL org.chess.estimated_perft4_ms=1000
LABEL org.chess.build="python3 -m py_compile chess.py"
LABEL org.chess.test="python3 -m pytest test_chess.py || python3 -m unittest discover -s . -p 'test*.py'"
LABEL org.chess.analyze="python3 analyze.py"

CMD ["python3", "chess.py"]
