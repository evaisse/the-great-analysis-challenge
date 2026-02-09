FROM node:20-slim

WORKDIR /app

COPY package*.json ./
RUN npm install --production=false

COPY src ./src
COPY chess.meta .

# Expose the build command in case we need to compile inside the container
CMD ["npm", "start"]