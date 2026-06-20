# Deployment Guide

> Instructions for deploying KALLAX in Docker and bare-metal environments.

---

## Docker Deployment

### Quick Start

```bash
# Build image
docker build -t kallax:latest .

# Run with default config
docker run -d \
  --name kallax \
  -p 3000:3000 \
  -v kallax-data:/app/.kallax \
  kallax:latest

# With custom config
docker run -d \
  --name kallax \
  -p 3000:3000 \
  -v /host/path/config.yml:/app/.kallax/config.yml \
  -v kallax-data:/app/.kallax/data \
  -e KALLAX_MODE=production \
  -e KALLAX_LOG_LEVEL=warn \
  kallax:latest
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  kallax:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - kallax-data:/app/.kallax/data
    environment:
      - KALLAX_MODE=production
      - REDIS_URL=redis://redis:6379
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

volumes:
  kallax-data:
  redis-data:
```

---

## Bare-Metal Deployment

### Prerequisites

```bash
# Node.js >= 18
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Rust (optional, for Rust modules)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# SQLite (bundled, no install needed)
# Redis (optional, for multi-node)
apt-get install -y redis-server
```

### Installation

```bash
git clone https://github.com/org/kallax.git /opt/kallax
cd /opt/kallax
npm install --production
npm run build

# Systemd service
cat > /etc/systemd/system/kallax.service << 'EOF'
[Unit]
Description=KALLAX Agent Orchestrator
After=network.target redis.service

[Service]
Type=simple
User=kallax
WorkingDirectory=/opt/kallax
ExecStart=/usr/bin/node dist/server.js
Restart=always
RestartSec=10
Environment=KALLAX_MODE=production
Environment=KALLAX_PORT=3000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now kallax
```

---

## Configuration

See `docs/reference/config-reference.md` for full configuration options.

```bash
# Minimal production config
export KALLAX_MODE=production
export KALLAX_PORT=3000
export KALLAX_LOG_LEVEL=warn
export KALLAX_DATA_DIR=/var/lib/kallax
export REDIS_URL=redis://localhost:6379
```

---

## Health Checks

```bash
# Docker
docker exec kallax ./scripts/health_check.sh

# HTTP endpoint
curl http://localhost:3000/health

# CLI
kallax system doctor
```

---

## Related Files

- `docker/Dockerfile` — Docker build definition
- `docker/docker-compose.yml` — Compose deployment
- `k8s/` — Kubernetes manifests
- `scripts/health_check.sh` — Health check script
- `docs/ops/monitoring.md` — Monitoring setup
- `docs/ops/backup-restore.md` — Backup procedures
