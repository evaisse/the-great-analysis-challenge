# Use official Node.js image
FROM node:18-bookworm

# Set working directory
WORKDIR /app

# Copy project files needed for dependency install and make targets
COPY package*.json ./
COPY tsconfig.json ./
COPY Makefile ./

# Install dependencies
RUN npm install

# Copy source code
COPY src/ ./src/
COPY test/ ./test/

# Build the TypeScript project
RUN npm run build

# Default command to run the chess engine
CMD ["node", "dist/chess.js"]
