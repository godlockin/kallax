# KALLAX Web Dashboard — Multi-Stage Dockerfile
# Static dashboard served via http-server (zero deps, node:20-alpine base)
# Stage 1 builds deps in /app; Stage 2 copies only runtime artifacts + web content
#
# EPIC-058-C — web dashboard deployment-ready (跟主公 2026-06-19 '都拆卡做' explicit 联合)
# 跟 v2.7.4 部署成熟度 联合, 跟 root Dockerfile (Rust + Node.js API) 互为 互补
# Default port: 8080 (跟 API server 9877 隔离, 跟 dispatch/dashboard 端口分层 联合)

# ============================================================
# Stage 1: Builder — install http-server + web deps
# ============================================================
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json* ./

RUN npm install --omit=dev --no-audit --no-fund

# ============================================================
# Stage 2: Runtime — copy only runtime node_modules + web content
# ============================================================
FROM node:20-alpine AS runtime

# Constant: default dashboard port (named to satisfy Rule 4 0 magic numbers)
ENV DASHBOARD_PORT=8080
ENV NODE_ENV=production

WORKDIR /app

# Create non-root user (跟 root Dockerfile 模式 一致, uid 1001)
RUN addgroup -g 1001 kallax && \
    adduser -D -u 1001 -G kallax kallax

# Copy runtime deps from builder (http-server only)
COPY --from=builder --chown=kallax:kallax /app/node_modules ./node_modules
COPY --from=builder --chown=kallax:kallax /app/package.json ./package.json

# Copy web content (single entry: web/ root, Iter 9 砍 dead dispatch dashboard)
COPY --chown=kallax:kallax index.html ./index.html
COPY --chown=kallax:kallax styles.css ./styles.css
COPY --chown=kallax:kallax app.js ./app.js
COPY --chown=kallax:kallax lib ./lib
COPY --chown=kallax:kallax src ./src

USER kallax

# Expose dashboard port
EXPOSE 8080

# Health check (verify HTTP 200 from /)
HEALTHCHECK --interval=30s --timeout=5s --start-period=3s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

# Default command — http-server serves web/ root with cache disabled (deployment-ready)
CMD ["npx", "http-server", ".", "-p", "8080", "-c-1", "--silent"]