# KALLAX Multi-Stage Dockerfile
# Build and run KALLAX in containerized environment

# ============================================================
# Stage 1: Rust Builder
# ============================================================
FROM rust:1.75-alpine AS rust-builder

WORKDIR /app/rust

# Install build dependencies
RUN apk add --no-cache musl-dev

# Copy Rust source
COPY rust/Cargo.toml rust/Cargo.lock ./
COPY rust/src ./src

# Build release binary
RUN cargo build --release

# ============================================================
# Stage 2: Node.js Builder
# ============================================================
FROM node:20-alpine AS node-builder

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
COPY node/package.json ./node/
RUN npm ci --workspace=node

# Copy source and build
COPY node ./node
COPY shared ./shared
COPY tsconfig.json ./

RUN npm run build -w node

# ============================================================
# Stage 3: Production Runtime
# ============================================================
FROM node:20-alpine AS production

WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 kallax && \
    adduser -D -u 1001 -G kallax kallax

# Install runtime dependencies
RUN apk add --no-cache \
    git \
    bash \
    curl

# Copy Rust binary
COPY --from=rust-builder /app/rust/target/release/kallax-core /usr/local/bin/kallax-core

# Copy Node.js application
COPY --from=node-builder /app/node/dist ./node/dist
COPY --from=node-builder /app/node_modules ./node_modules
COPY --from=node-builder /app/node/node_modules ./node/node_modules

# Copy configuration
COPY package.json ./
COPY .kallax/config.yml ./.kallax/config.yml
COPY .kallax/config ./.kallax/config

# Create data directories
RUN mkdir -p .kallax/data .kallax/logs .kallax/state .kallax/queue && \
    chown -R kallax:kallax /app

# Switch to non-root user
USER kallax

# Environment
ENV NODE_ENV=production
ENV KALLAX_MODE=docker

# Expose ports
EXPOSE 9877 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:9877/health || exit 1

# Default command
CMD ["node", "node/dist/index.js"]

# ============================================================
# Stage 4: Development Runtime
# ============================================================
FROM node:20-alpine AS development

WORKDIR /app

# Install development dependencies
RUN apk add --no-cache \
    git \
    bash \
    curl \
    vim

# Install Rust (for development)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Copy package files
COPY package.json package-lock.json ./
COPY node/package.json ./node/

# Install all dependencies (including dev)
RUN npm ci

# Copy source
COPY . .

# Environment
ENV NODE_ENV=development

# Expose ports
EXPOSE 9877 3000

# Development command with hot reload
CMD ["npm", "run", "dev"]
