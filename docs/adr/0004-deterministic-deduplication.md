# 0004. Deduplicate on deterministic keys, and store alerts separately from incidents

- **Status:** Proposed
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

The draft PRD specifies a "regex-based deduplication router". Deduplication is
the component that decides whether a page fires at all, so its failure modes
matter more than its flexibility:

- A regex engine evaluating operator-authored patterns against
  attacker-influenced payloads (`summary` comes from the wire) invites
  pathological inputs. Go's RE2 engine removes catastrophic backtracking, but
  not the debuggability problem.
- Regex rules make dedup outcomes depend on rule *ordering* and on payload
  *phrasing*. At 3 AM, "why did these two alerts merge?" must have a one-line
  answer.
- The wire format is already compatible with the PagerDuty Events API v2, which
  carries an explicit `dedup_key`. Alertmanager provides a stable `fingerprint`
  per alert. The deterministic key usually already exists.

Separately, the initial schema (001) stores only `incidents` — the raw events
are not persisted. That makes "this incident fired 400 times between 02:10 and
02:14" impossible to show, and makes reprocessing or auditing ingestion
impossible.

## Decision

1. **Deduplication is exact-match on a deterministic key**, scoped to one
   integration's service:
   - If the event carries `dedup_key`, use it verbatim.
   - Alertmanager events use the alert `fingerprint`.
   - Otherwise derive `sha256(routing_key || summary)`.
2. **At most one unresolved incident exists per (service, dedup_key)**,
   enforced by a partial unique index and an upsert inside the ingest
   transaction — not by application-level check-then-insert.
3. **Alerts are first-class rows.** Every accepted event is persisted as an
   `alert` linked to its incident, with a per-incident retention cap (row cap
   plus a running counter beyond it) so a storm cannot bloat the table
   unboundedly.
4. A `trigger` after `resolve` opens a **new** incident with the same key.
5. Regex/label-matching **routing rules are deferred** to post-1.0, and when
   they arrive they will route and annotate (set urgency, pick a policy) — they
   will not define identity. Identity stays deterministic.

## Consequences

### Positive

- Dedup outcomes are explainable and reproducible: same key, same incident.
- Uniqueness is enforced where races are actually resolved — in PostgreSQL —
  so concurrent duplicate events cannot open duplicate incidents.
- The alert/incident split gives the timeline ("fired 400×, last 02:14"), and
  keeps an audit trail of exactly what each monitoring tool sent.

### Negative

- Sources that send neither `dedup_key` nor stable summaries will group
  imperfectly (each phrasing variant becomes its own incident). The integration
  guides must teach setting `dedup_key`.
- No content-based grouping ("merge everything mentioning db-primary-01") in
  v1. Teams wanting that must encode it in their alert rules.

### Neutral

- The derived-key function is versioned; changing it later only affects new
  incidents.

## Alternatives considered

**Regex rules as the dedup primitive (the draft).** Rejected: outcome depends
on rule order and payload phrasing, is hard to explain during an incident, and
adds an evaluation cost and abuse surface to the hot ingest path.

**Similarity/ML grouping.** Rejected for v1: non-deterministic grouping in the
paging path is the opposite of trustworthy. Viable later as an *advisory*
"related incidents" hint, never as identity.

**Time-window bucketing (group anything from one integration within N
minutes).** Rejected: merges unrelated failures during precisely the large
outages where distinguishing them matters most.
