# Backend — AlertDam Go Engine

The AlertDam backend is a single Go binary that handles all alert ingestion, escalation, scheduling, and notification delivery.

## Requirements

- Go 1.23+
- PostgreSQL 16+

## Directory Structure

```
backend/
├── cmd/
│   └── alertdam/
│       └── main.go          # Application entry point
├── internal/
│   ├── api/                 # HTTP router and handlers
│   │   └── router.go
│   ├── alert/               # Alert ingestion, deduplication engine
│   │   └── ingest.go
│   ├── escalation/          # Escalation policy engine
│   ├── schedule/            # On-call schedule rotation logic
│   ├── integration/         # Chat bot integrations (Slack, Discord, Telegram)
│   ├── notification/        # Push (FCM/APNs), Twilio voice, SIP
│   ├── auth/                # OAuth2, SAML, OIDC
│   └── db/                  # PostgreSQL connection and queries
├── migrations/              # SQL migration files (run in order)
│   └── 001_initial.sql
├── go.mod
└── go.sum
```

## Local Development

```bash
# Install dependencies
go mod download

# Run locally (requires PostgreSQL)
export DATABASE_URL=postgres://alertdam:alertdam@localhost:5432/alertdam?sslmode=disable
export JWT_SECRET=your-dev-secret
go run ./cmd/alertdam/...

# Or use the root Makefile:
make dev-backend
```

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `POST` | `/v1/events` | Ingest an alert event |
| `GET` | `/v1/incidents` | List all incidents |
| `POST` | `/v1/incidents/{id}/acknowledge` | Acknowledge an incident |
| `POST` | `/v1/incidents/{id}/resolve` | Resolve an incident |
| `GET` | `/v1/schedules` | List on-call schedules |
| `GET` | `/v1/schedules/{id}/feed.ics` | iCalendar feed (RFC 5545) |
| `POST` | `/v1/webhooks/alertmanager` | Prometheus Alertmanager webhook |
| `POST` | `/v1/webhooks/grafana` | Grafana alerts webhook |
| `POST` | `/v1/webhooks/slack/actions` | Slack interactive actions |
| `POST` | `/v1/webhooks/telegram` | Telegram bot webhook |
| `GET` | `/health` | Health check |

## Database Migrations

Migrations are plain SQL files in `migrations/`. Apply them in order:

```bash
psql $DATABASE_URL -f migrations/001_initial.sql
```

## Testing

```bash
go test ./... -v -race
```
