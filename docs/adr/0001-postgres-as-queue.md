# 0001. Use PostgreSQL as the notification queue

- **Status:** Accepted
- **Date:** 2026-07-23
- **Deciders:** @darisadam

## Context

AlertDam must deliver notifications reliably: an alert that is not delivered is
the one failure mode the product cannot have. That normally implies a durable
queue with at-least-once delivery, retries, and a way for multiple workers to
claim work without duplicating it.

The dominant constraint is a product one, not a technical one. AlertDam targets
teams who are self-hosting because they do not want to operate a SaaS
dependency — small teams, OSS projects, startups. Every additional
piece of infrastructure they must install, monitor, back up and upgrade makes the
product less likely to be adopted, and every such component is a new way for the
paging system itself to be the thing that is down at 3 AM.

## Decision

Use PostgreSQL as the queue. No Redis, no RabbitMQ, no Kafka, no NATS.

Specifically:

- A `notification_queue` table holds pending deliveries.
- Workers claim work with `SELECT ... FOR UPDATE SKIP LOCKED`, which gives
  competing consumers without duplicate delivery.
- `LISTEN`/`NOTIFY` wakes idle workers immediately, so latency does not depend on
  a polling interval.
- A partial index (`notification_queue_pending_idx`) keeps the claim query cheap
  as the table grows.

The deployment is therefore exactly two containers: the Go binary and PostgreSQL.

## Consequences

### Positive

- `docker compose up` is a complete, production-shaped deployment.
- One thing to back up, and the queue state is inside the same transaction as the
  incident state — so an incident can never be recorded without its notification
  being enqueued, and vice versa. With an external broker that is a distributed
  transaction problem.
- Operators already know how to run PostgreSQL.
- Queue contents are inspectable with `psql`, which matters when debugging why a
  page did not arrive.

### Negative

- Throughput ceiling is far lower than a dedicated broker. Acceptable: the
  workload is human-paging volume, not telemetry volume.
- `LISTEN`/`NOTIFY` payloads are capped (8000 bytes) and notifications are lost if
  no listener is connected, so it is used only as a wake-up hint — the table
  remains the source of truth. Correctness must never depend on a `NOTIFY`
  arriving.
- Long-lived `LISTEN` connections interact badly with transaction-mode connection
  poolers (PgBouncer in transaction mode, some managed Postgres proxies). This
  needs documenting for operators.
- Aggressive polling or long-held claim transactions can bloat the table and
  interfere with autovacuum. Claims must be short.

### Neutral

- If throughput ever becomes the binding constraint, the claim interface can be
  reimplemented behind the same internal API without changing the incident model.

## Alternatives considered

**Redis.** The usual reflex, and genuinely good at this. Rejected because it adds
a second stateful service, and Redis's default persistence settings make it
possible to lose queued notifications on restart — which is precisely the failure
this system exists to prevent. Getting that right requires operator expertise the
target audience should not need.

**RabbitMQ / NATS.** Correct tools for the job and materially more capable.
Rejected on the same operational-footprint grounds, more strongly: they are
another thing to cluster, monitor and upgrade.

**In-process queue only.** Simplest, and wrong: a restart loses everything
pending, and it cannot scale past one replica.

**Cloud-managed queue (SQS, Pub/Sub).** Contradicts the self-hosted premise and
would fracture the deployment story per cloud.
