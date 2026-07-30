# Self-Hosting Guide

## Requirements

- Docker 24+ and Docker Compose v2
- A server or VPS (minimum 1 vCPU, 512MB RAM)
- A domain name (recommended) with SSL/TLS via reverse proxy
- Integration tokens (Slack, Discord, or Telegram) — at least one required

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/darisadam/alertdam.git
cd AlertDam

# 2. Configure environment
cp .env.example .env
# Open .env and set at minimum:
#   JWT_SECRET=<a long random string>
#   SLACK_BOT_TOKEN=xoxb-...  (or DISCORD/TELEGRAM equivalent)

# 3. Start the stack
docker compose up -d

# 4. Verify it's running
curl http://localhost:8080/health
# → {"status":"ok"}
```

## Production Deployment

### 1. Build the production image

The `deploy/docker/Dockerfile` uses a multi-stage build to produce a minimal binary image (~20MB).

```bash
docker build -f deploy/docker/Dockerfile -t alertdam:latest .
```

### 2. Use a reverse proxy (Nginx / Caddy)

**Caddy (recommended — auto SSL):**
```caddyfile
alertdam.example.com {
  reverse_proxy localhost:8080
}
```

**Nginx:**
```nginx
server {
  listen 443 ssl;
  server_name alertdam.example.com;
  # ... SSL config ...
  location / {
    proxy_pass http://localhost:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

### 3. Inbound Webhooks

For Slack, Discord, and Telegram to send callbacks, AlertDam must be reachable on the public internet. Ensure port 443 is open and your domain resolves correctly.

Register your webhook URL in each platform:
- **Slack:** App settings → Interactivity & Shortcuts → Request URL: `https://alertdam.example.com/v1/webhooks/slack/actions`
- **Telegram:** `GET https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://alertdam.example.com/v1/webhooks/telegram`

### 4. Database Backups

```bash
# Manual backup
docker exec alertdam-db pg_dump -U alertdam alertdam > backup_$(date +%Y%m%d).sql

# Restore
docker exec -i alertdam-db psql -U alertdam alertdam < backup_20260101.sql
```

## Environment Variables Reference

See [`.env.example`](../.env.example) for the full list.

## Updating AlertDam

```bash
git pull origin main
docker compose up -d --build
```

Migrations are applied automatically on startup.
