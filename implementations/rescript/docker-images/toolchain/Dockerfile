# ReScript Toolchain Image for TGAC
FROM node:22-alpine
WORKDIR /app

# Install the project-scoped ReScript toolchain dependencies once in the base image.
COPY package*.json ./
RUN npm install
