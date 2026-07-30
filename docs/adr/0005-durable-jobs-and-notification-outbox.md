# 0005. Run timers and deliveries as durable PostgreSQL jobs with an outbox

- **Status:** Proposed
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

ADR-0001 chose PostgreSQL as the queue. This ADR fixes the *semantics* on top
of it, because the failure modes that destroy trust in a pager are all here:

- An escalation timer held in process memory dies with the process. "The
  binary restarted during the 5-minute wait, so step 2 never fired" is an
  unacceptable failure mode.
- A notification enqueued outside the transaction that created the incident
  can be lost (incident exists, nobody paged) or orphaned (page for an
  incident that was rolled back).
- Two replicas — which the product must support for HA — must not both fire
  the same step or both deliver the same notification.
- Wall clocks on app replicas drift; timers compared against `time.Now()` on
  different machines fire early, late, or twice.

The 001 schema has a single `notification_queue` table. Deliveries and timers
have different shapes: a delivery targets a (recipient, channel) and retries on
provider errors; a timer ("evaluate escalation step 2 at T") is unique per
incident and gets *cancelled* by acknowledgement.

## Decision

1. **Two tables**: `notifications` (the delivery outbox: one row per recipient
   × contact method × incident event, with payload, attempt count, and a
   terminal status) and `jobs` (durable timers: escalation step evaluation,
   heartbeat expiry, ack-timeout, handoff notices — each with `run_at` and an
   idempotent handler key).
2. **Outbox invariant**: rows in both tables are only ever written in the same
   transaction as the state change that implies them. An incident cannot be
   created without its escalation job; a job cannot fire without recording the
   notifications it produced.
3. **Claim protocol**: workers claim with
   `SELECT ... WHERE run_at <= now() AND status='pending' ORDER BY run_at
   FOR UPDATE SKIP LOCKED LIMIT n`, mark `claimed` with a lease deadline, and
   either finish or are re-claimed after lease expiry. Claims are short; work
   (the actual HTTP call to a provider) happens outside the claiming
   transaction.
4. **`LISTEN/NOTIFY` is a latency optimisation only.** Every worker also polls
   on a ≤5s ticker. Correctness never depends on a NOTIFY arriving (they are
   lost when no listener is connected — ADR-0001).
5. **Database time is authoritative.** All `run_at` comparisons happen in SQL
   against `now()`. App-server wall clocks are never compared against stored
   deadlines.
6. **Cancellation is a state check, not a delete race.** Acknowledging an
   incident marks intent in the incident row; when an escalation job fires it
   re-reads incident state inside its transaction and no-ops if the incident is
   no longer eligible. Firing a stale job is harmless by construction.
7. **Delivery is at-least-once with visible outcomes.** Each notification ends
   in `sent`, `failed_retryable` (with next retry scheduled, capped attempts),
   or `failed_permanent` (dead-letter). Dead-lettered rows are surfaced in the
   dashboard and in metrics — a notification is never silently dropped. A
   per-row idempotency key bounds duplicates when a provider call succeeds but
   the acknowledgement of success is lost.

## Consequences

### Positive

- Kill the process at any instant and the system resumes correctly from the
  tables; this is testable and becomes a standing chaos test.
- Two or more replicas are safe by construction (SKIP LOCKED + leases + state
  re-checks), which is the entire HA story — no leader election.
- "Why didn't it page?" has a queryable answer: the notification row and its
  attempts are the audit trail.

### Negative

- At-least-once means rare duplicate sends (crash between provider success and
  status write). Accepted: for a pager, a duplicate page is annoying; a missing
  page is a product failure. The idempotency key keeps the window small.
- More moving parts than a naive queue table: leases, re-claims, and two tables
  need focused tests.

### Neutral

- Heartbeat expiry, handoff notices, and future periodic work all ride the
  same `jobs` table instead of ad-hoc tickers — one mechanism to test and
  monitor (`alertdam_queue_depth{kind}`).

## Alternatives considered

**In-process timers (`time.AfterFunc`) with the DB as backup.** Rejected: two
sources of truth that disagree after every deploy; the "backup" path is the
one that never gets exercised until it matters.

**One combined queue table (schema 001 as-is).** Rejected: timers need
cancellation semantics and uniqueness per incident; deliveries need retry
semantics per recipient. Modelling both in one row shape produced exactly the
ambiguity this ADR exists to remove.

**An embedded job library (e.g. river, gocraft/work).** river is attractive
and also Postgres-native; rejected for now to keep the claim protocol ~200
lines we fully understand and can instrument precisely. Revisit if our
implementation grows features a library gives for free.

**Redis/broker-backed delayed jobs.** Already rejected by ADR-0001.
