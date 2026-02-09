FROM python:3.11-slim

WORKDIR /app

# Install dependencies if any (none for this minimal scaffold)
# RUN pip install -r requirements.txt

# Copy application files
COPY . .

# Define entrypoint command to run the engine
# This assumes the engine will read from stdin
CMD ["python", "main.py"]