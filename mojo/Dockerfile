FROM modular/mojo:latest

WORKDIR /app

# Copy the chess engine source code
COPY . .

# Make the chess engine executable
RUN chmod +x chess.mojo

# Default command to run the chess engine
CMD ["mojo", "chess.mojo"]