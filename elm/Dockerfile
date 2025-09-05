FROM node:20-alpine

WORKDIR /app

# Install Elm
RUN npm install -g elm@latest-0.19.1

# Copy package files
COPY package.json elm.json ./

# Install Node dependencies
RUN npm install

# Copy source files
COPY src ./src

# Build the Elm application
RUN npm run build

# Run the chess engine
CMD ["npm", "start"]
