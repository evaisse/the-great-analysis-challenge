# Use official Python image
FROM python:3.13-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    make \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt* ./

# Install Python dependencies
RUN if [ -f requirements.txt ]; then \
    pip3 install --no-cache-dir -r requirements.txt; \
    fi

# Copy source code
COPY . .

# Create a non-root user
RUN addgroup --system python && \
    adduser --no-create-home --shell /bin/false --disabled-password --system --ingroup python chess

# Change ownership of the app directory
RUN chown -R chess:python /app

# Switch to non-root user
USER chess

# Make chess.py executable
RUN chmod +x chess.py

# Create analyze script
RUN echo '#!/bin/bash\n\
echo "🔍 Running Python static analysis..."\n\
python3 -m mypy . || true\n\
python3 -m pylint . --disable=C0114,C0115,C0116 || true\n\
echo "✅ Analysis complete!"' > /app/analyze && \
    chmod +x /app/analyze

# Default command to run the chess engine

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
