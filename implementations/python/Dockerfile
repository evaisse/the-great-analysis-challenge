# Use Ubuntu base image
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Python
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt ./

# Install Python dependencies
RUN pip3 install --no-cache-dir --break-system-packages -r requirements.txt

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

# Create analyze script for comprehensive static analysis
RUN echo '#!/bin/bash\n\
echo "🔍 Running Python static analysis..."\n\
echo "=" | head -c 50; echo\n\
\n\
echo "📝 Type checking with mypy..."\n\
python3 -m mypy . || true\n\
echo\n\
\n\
echo "🎯 Code quality with pylint..."\n\
python3 -m pylint . --disable=C0114,C0115,C0116 || true\n\
echo\n\
\n\
echo "📏 Style checking with flake8..."\n\
python3 -m flake8 . --max-line-length=100 --ignore=E203,W503 || true\n\
echo\n\
\n\
echo "🖤 Code formatting with black..."\n\
python3 -m black --check --diff . || true\n\
echo\n\
\n\
echo "🔒 Security analysis with bandit..."\n\
python3 -m bandit -r . -f txt || true\n\
echo\n\
\n\
echo "✅ Analysis complete!"' > /app/analyze && \
    chmod +x /app/analyze

# Default command to run the chess engine
CMD ["python3", "chess.py"]

# Alternative commands for different use cases:
# To run static analysis: docker run --rm chess-python ./analyze
# To run mypy only: docker run --rm chess-python python3 -m mypy .
# To run pylint only: docker run --rm chess-python python3 -m pylint .
# Interactive mode: docker run -it chess-python