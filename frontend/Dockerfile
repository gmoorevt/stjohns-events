# Development stage
FROM node:20-slim as development

WORKDIR /app

# Install system dependencies and build tools
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set npm config for better network handling
RUN npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000

# Set Node.js memory limit
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Install dependencies with specific flags
COPY package*.json ./
RUN npm install --legacy-peer-deps

# Copy application code
COPY . .

# Command to run the development server
CMD ["npm", "run", "dev"]

# Build stage
FROM node:20-slim as builder

WORKDIR /app

# Install system dependencies and build tools
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set npm config for better network handling
RUN npm config set fetch-retry-mintimeout 20000 \
    && npm config set fetch-retry-maxtimeout 120000

# Set Node.js memory limit
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Set production environment variables
ENV VITE_API_URL=/api

# Install dependencies with specific flags
COPY package*.json ./
RUN npm install --legacy-peer-deps

# Copy application code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:alpine as production

# Copy built assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 