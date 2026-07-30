# AlertDam — System Architecture

## Overview

AlertDam is a **single-binary, self-hosted** incident management platform. The entire stack runs via two Docker containers: the Go binary and PostgreSQL.

```
[Monitoring Sources]           [Chat Platforms]
 Prometheus/Alertmanager  →          Slack
 Grafana Alerts           →          Discord
 Datadog Webhooks         →          Telegram
 Generic Webhook          →          MS Teams / WhatsApp
         │                                │
         └──────────────┬─────────────────┘
                        ▼
         ┌─────────────────────────────┐
         │      AlertDam Go Binary     │
         │                             │
         │  ┌──────────────────────┐   │
         │  │  Alert Ingestion     │   │  POST /v1/events
         │  │  & Deduplication     │   │
         │  └──────────┬───────────┘   │
         │             │               │
         │  ┌──────────▼───────────┐   │
         │  │  Escalation Engine   │   │  Policy chain evaluation
         │  └──────────┬───────────┘   │
         │             │               │
         │  ┌──────────▼───────────┐   │
         │  │  Notification Queue  │   │  PostgreSQL LISTEN/NOTIFY
         │  └──────────┬───────────┘   │
         │             │               │
         │  ┌──────────▼───────────┐   │
         │  │  Delivery Workers    │   │  Slack / Discord / Push / Voice
         │  └──────────────────────┘   │
         └──────────────┬──────────────┘
                        │
         ┌──────────────▼──────────────┐
         │          PostgreSQL          │
         │  (State + Queue + Schedules) │
         └─────────────────────────────┘
                        │
         ┌──────────────┼──────────────┐
         ▼              ▼              ▼
    [Web Dashboard]  [Mobile App]  [iCal Feed]
     React/Vite       Flutter      RFC 5545
```

## Key Design Decisions

### Zero External Dependencies
- **No Redis:** PostgreSQL's `LISTEN/NOTIFY` + `FOR UPDATE SKIP LOCKED` provides reliable queuing natively.
- **No RabbitMQ/Kafka:** Message delivery is handled by dedicated worker goroutines pulling from the `notification_queue` table.
- **No Kubernetes required:** The entire production stack is a single `docker-compose.yml`.

### PostgreSQL as a Queue
The `notification_queue` table uses the following pattern for worker concurrency:
```sql
-- Worker goroutine atomically claims a job
SELECT * FROM notification_queue
WHERE status = 'pending'
  AND scheduled_for <= NOW()
ORDER BY scheduled_for ASC
LIMIT 1
FOR UPDATE SKIP LOCKED;
```
This prevents duplicate deliveries without any external broker.

### Deduplication Engine
Rapid-fire identical alerts (e.g., 500 identical "Database Timeout" alerts/minute) are compressed into a single incident using `dedup_key`. New events with the same `dedup_key` append to the existing incident thread rather than creating new ones.

### ChatOps-First Design
The Go backend maintains long-lived WebSocket/bot connections to Slack and Discord. Alert state changes (Acknowledge/Resolve) are reflected instantly in the originating chat thread via button callbacks.

## Data Flow

```
1. Alert fires in Prometheus
2. Alertmanager sends POST /v1/webhooks/alertmanager (or /v1/events)
3. Deduplication engine checks for existing active incident with same dedup_key
   - If found: append event to existing incident, skip new notification
   - If not found: create new incident record
4. Escalation engine evaluates the routing_key → find escalation policy
5. Step 1 notifications enqueued in notification_queue (NOTIFY sent)
6. Delivery worker picks up job:
   - Posts rich card to Slack/Discord
   - Sends FCM push to mobile app
7. After escalation_delay_minutes with no acknowledgment: Step 2 executes
8. User clicks "Acknowledge" in Slack → callback hits POST /v1/webhooks/slack/actions
9. Incident status updated → all chat threads updated
```
