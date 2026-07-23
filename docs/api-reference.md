# API Reference

## Base URL

```
http://localhost:8080/v1
```

## Authentication

All endpoints (except `/health` and inbound webhooks) require a Bearer JWT token:

```
Authorization: Bearer <token>
```

---

## Alert Ingestion

### `POST /v1/events`

Ingest an alert event. This is the main ingestion endpoint compatible with any monitoring tool.

**Request Body:**
```json
{
  "routing_key": "srv-abc-123-xyz",
  "event_action": "trigger",
  "dedup_key": "database-disk-space-90-percent",
  "payload": {
    "summary": "Storage critical on db-primary-01",
    "severity": "CRITICAL",
    "source": "Prometheus-Alertmanager",
    "custom_details": {
      "current_usage": "92.4%",
      "mount_point": "/var/lib/postgresql"
    }
  }
}
```

| Field | Type | Required | Description |
|---|---|---|---|
| `routing_key` | string | ✅ | Integration routing key |
| `event_action` | string | ✅ | `trigger`, `acknowledge`, or `resolve` |
| `dedup_key` | string | | Unique key for deduplication |
| `payload.summary` | string | ✅ | Human-readable alert summary |
| `payload.severity` | string | ✅ | `CRITICAL`, `HIGH`, `WARNING`, `INFO` |
| `payload.source` | string | | Source system name |
| `payload.custom_details` | object | | Arbitrary key-value metadata |

**Response:** `202 Accepted`
```json
{ "status": "accepted", "message": "Event received and queued for processing" }
```

---

## Incidents

### `GET /v1/incidents`

List all incidents.

**Query Parameters:**
| Param | Description |
|---|---|
| `status` | Filter by status: `firing`, `acknowledged`, `resolved` |
| `severity` | Filter by severity: `CRITICAL`, `HIGH`, `WARNING`, `INFO` |
| `page` | Page number (default: 1) |
| `limit` | Items per page (default: 25, max: 100) |

### `POST /v1/incidents/{id}/acknowledge`

Acknowledge an incident.

### `POST /v1/incidents/{id}/resolve`

Resolve an incident.

### `POST /v1/incidents/{id}/escalate`

Manually escalate an incident to the next escalation step.

---

## On-Call Schedules

### `GET /v1/schedules`

List all on-call schedules.

### `GET /v1/schedules/{id}/feed.ics`

Returns an iCalendar (RFC 5545) `.ics` feed for the schedule. Subscribe to this URL in Google Calendar, Apple Calendar, or Outlook.

---

## Monitoring Tool Webhooks

| Endpoint | Source |
|---|---|
| `POST /v1/webhooks/alertmanager` | Prometheus Alertmanager |
| `POST /v1/webhooks/grafana` | Grafana Alerts |
| `POST /v1/webhooks/datadog` | Datadog Webhooks |
| `POST /v1/webhooks/generic` | Any tool (generic format) |

---

## Health

### `GET /health`

```json
{ "status": "ok" }
```
