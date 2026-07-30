# AlertDam v1.0.0 — Product Requirements

**Status:** Scope of record for v1.0.0. Supersedes the draft PRD (see
[prd-review.md](prd-review.md) for what changed and why). Changes to this
document happen by PR; a requirement is only descoped by editing this file.

Priorities use MoSCoW: **[M]**ust ship in v1.0.0, **[S]**hould ship (may slip
to v1.0.x with a stated reason), **[C]**ould ship (opportunistic).

---

## 1. Product summary

AlertDam is an open-source (Apache-2.0), self-hosted incident management and
on-call alerting platform for engineering teams: a single Go binary plus
PostgreSQL. Monitoring tools send events to it; it deduplicates them into
incidents, pages the right on-call human through escalating channels (chat,
email, mobile push, voice), and lets responders acknowledge, resolve and
escalate **from chat** without opening a dashboard.

**v1.0.0 deployment reality:** a DevOps engineer deploys the backend and
PostgreSQL (one `docker compose up` or one binary), points Alertmanager/
Grafana/anything-with-webhooks at it, connects a Slack workspace and/or
Telegram bot, and optionally builds the Flutter mobile app against their own
Firebase project for push. There is no hosted offering in v1.

**Not the goal of v1:** SaaS/multi-tenancy, status pages, analytics suites,
or breadth of integrations. The goal is that the core loop —
*event → incident → page → ack → resolve* — is boringly, provably reliable.

## 2. Product principles

- **P1 — Never fail silently.** Every accepted event either results in the
  configured notifications or in a loudly visible failure (dashboard, metrics,
  admin notice). There is no third outcome.
- **P2 — Chat is a control plane, not a mirror.** Anything a responder does
  during an incident works from Slack/Telegram: ack, resolve, escalate, see
  who is on call.
- **P3 — Two containers is a contract.** The Go binary and PostgreSQL.
  No Redis, no broker, no third container (ADR-0001, ADR-0009). A v1
  deployment needs no public inbound URL unless Twilio callbacks are enabled.
- **P4 — BYOK for anything that costs money.** Twilio, SMTP, Firebase are the
  operator's accounts. Chat-only operation is 100% free.
- **P5 — Boring correctness beats features.** Timezones/DST, retries,
  idempotency, crash-resume are the product. A feature that cannot be made
  reliable in time moves out of scope rather than shipping fragile.
- **P6 — The dashboard is for configuration and history**, not for
  firefighting.

## 3. Personas and core journeys

- **Priya, platform engineer (admin).** Deploys AlertDam, wires Alertmanager,
  configures services/schedules/policies, and needs to prove to her team it
  can be trusted. Journey: *zero → first real page acknowledged in under 30
  minutes*, following only the quickstart.
- **Marco, backend dev (responder).** On call one week a month. Journey: a
  CRITICAL fires at 03:00 → phone pushes through DND → he acks from the
  lock screen → the Slack card updates to "acknowledged by Marco" → he
  resolves from Slack when done; next morning the timeline shows every step
  with timestamps.
- **Sam, engineering manager.** Journey: checks "who is on call over the
  holidays" in the calendar, creates an override for a sick teammate in two
  clicks, and subscribes the team schedule ICS into Google Calendar.
- **The 3 AM forensic journey (any role):** "why didn't X get paged?" is
  answerable from the incident timeline + notification log alone: which rule
  matched, which notifications were created, each delivery attempt and its
  provider response.

## 4. Domain model (normative vocabulary)

- **Team** — group of users; owns services and schedules.
- **Service** — the unit things go wrong in ("checkout-api"). Owns
  integrations, an escalation policy binding, urgency rules and maintenance
  windows.
- **Integration** — one inbound event source for a service (type: events-API,
  Alertmanager, Grafana, heartbeat), identified by a secret routing key.
- **Alert** — one received event, immutable, linked to an incident.
- **Incident** — the deduplicated unit of response. States:
  `firing → acknowledged → resolved` (details §5.4).
- **Escalation policy** — ordered steps of targets (users/schedules) with
  delays and repeat count.
- **Notification rule** — a *user's* personal "how to reach me" list per
  urgency (contact method + delay).
- **Notification** — one delivery attempt chain to one contact method, with
  an auditable outcome.
- **Schedule** — layered rotations + overrides resolving to one on-call user
  at any instant (ADR-0006).

## 5. Functional requirements

### 5.1 Users, authentication and access (ADR-0007)

- **AUTH-1 [M]** Local accounts: email + password (argon2id), admin-created
  invites with expiring links, self-service password reset via email.
- **AUTH-2 [M]** OIDC login (discovery + PKCE) against one configured
  provider; optional JIT provisioning behind an env flag; works with
  Keycloak, Authentik, Google, Okta, Entra.
- **AUTH-3 [M]** Server-side sessions: opaque cookie, revocable per session
  and "everywhere"; CSRF protection on state-changing browser routes.
- **AUTH-4 [M]** Personal access tokens: `ad_`-prefixed, shown once, hashed at
  rest, scopes `read`/`write`, last-used timestamp, revocable.
- **AUTH-5 [M]** Roles: `admin` (mutate config/users) and `member` (full
  responder + own profile). Route×role authorization matrix tested as a
  golden table.
- **AUTH-6 [M]** First-run bootstrap: `alertdam admin create-admin` (no
  default credentials, ever).
- **AUTH-7 [S]** Login rate limiting + audit of auth events (ties AUD-1).
- **AUTH-8 [C]** TOTP 2FA for local accounts (OIDC deployments get MFA from
  the IdP).

### 5.2 Services, integrations and event ingestion

- **SVC-1 [M]** CRUD for teams, services, integrations. Routing keys are
  random ≥192-bit, stored hashed, displayed once, rotatable.
- **SVC-2 [M]** Per-service urgency mapping: severity → urgency
  (`high`/`low`), default CRITICAL/HIGH→high, WARNING/INFO→low.
- **SVC-3 [M]** Test-fire button per integration: sends a synthetic event
  through the *entire* pipeline (dedup → incident → notifications), labelled
  as test.
- **ING-1 [M]** `POST /v1/events` implementing the contract in §7
  (PagerDuty Events API v2-compatible wire format): `trigger`, `acknowledge`,
  `resolve` actions with `dedup_key`.
- **ING-2 [M]** Alertmanager inbound mapper: one endpoint accepting the
  standard webhook payload; `firing`/`resolved` per alert in the group;
  `fingerprint` → dedup key; severity from label (configurable label name);
  labels+annotations → `custom_details`; `generatorURL` preserved as a link.
  Golden-fixture tested against real Alertmanager payloads.
- **ING-3 [M]** Grafana alerting inbound mapper, same standard.
- **ING-4 [M]** Ingestion auth: routing key in body (PD-compatible) or
  `Authorization: Bearer <routing key>`. Unknown key → 401; malformed → 400;
  accepted → 202; oversized → 413; rate-limited → 429 with `Retry-After`;
  storage unavailable → 503 (sources retry; Alertmanager does).
- **ING-5 [M]** Limits: request body ≤ 1 MiB; `summary` truncated at 1024
  chars (marked); `custom_details` stored up to 64 KiB (truncated, marked).
- **ING-6 [M]** Per-key token-bucket rate limit (default 600 events/min,
  configurable) + per-service **storm guard**: when open incidents for a
  service exceed a cap (default 200), further distinct keys fold into a
  single "alert storm" incident instead of paging per-key.
- **ING-7 [M]** Ingestion is fast-path: validate, persist, enqueue, 202.
  Processing is asynchronous (ADR-0005).
- **ING-8 [S]** Datadog inbound mapper. **ING-9 [C]** signed/timestamped
  ingest option for tools that support it.

### 5.3 Deduplication and grouping (ADR-0004)

- **DED-1 [M]** Exact-match dedup on deterministic key; at most one
  unresolved incident per (service, dedup_key), enforced by partial unique
  index inside the ingest transaction (race-proof).
- **DED-2 [M]** Key derivation when absent: Alertmanager `fingerprint`;
  otherwise `sha256(routing_key || summary)`.
- **DED-3 [M]** Repeat `trigger`s append to the open incident: alert row +
  count + last-seen; per-incident alert-row cap (500) with counter beyond.
- **DED-4 [M]** `resolve` events resolve the matching open incident
  (idempotent; unknown key → accepted no-op). `trigger` after resolve opens a
  new incident.
- **DED-5 [M]** Severity upgrades on an open incident raise incident severity
  and are recorded in the timeline/chat thread; an *acknowledged* incident is
  not re-paged by design (documented).

### 5.4 Incidents

- **INC-1 [M]** States and transitions: `firing → acknowledged → resolved`;
  ack and resolve are idempotent; resolve allowed from either state; every
  transition records actor (user or system) and origin (web/API/Slack/
  Telegram/mobile/voice/auto).
- **INC-2 [M]** Severity: `CRITICAL|HIGH|WARNING|INFO` (as in current code);
  urgency `high|low` derived per SVC-2 at creation.
- **INC-3 [M]** Human-friendly sequential incident number (#42) alongside
  UUID.
- **INC-4 [M]** Timeline: every event (alerts appended, notifications sent
  with outcomes, escalation steps fired, state changes, notes) with
  timestamps, queryable via API and UI.
- **INC-5 [M]** Manual actions: ack, resolve, escalate-now (jump to next
  step), add note — from web, API, chat, mobile.
- **INC-6 [S]** Manual incident creation (web/API/chat) for human-detected
  issues.
- **INC-7 [S]** Ack-timeout: per policy, an acknowledged-but-unresolved
  incident re-escalates after N minutes (opt-in).
- **INC-8 [C]** Snooze (ack that auto-expires); per-service auto-resolve
  after quiet period (default off).

### 5.5 Escalation policies and personal notification rules

- **ESC-1 [M]** Policy = ordered steps; step = set of targets (users and/or
  schedules) + delay before the *next* step; policy repeat count (0–9).
  Ack or resolve anywhere halts the chain (race-safe per ADR-0005 §6).
- **ESC-2 [M]** Timers survive restarts and replicas (durable jobs,
  ADR-0005); drift bounds per NFR PERF-3.
- **ESC-3 [M]** Schedule targets resolve to the on-call user *at fire time*.
  Empty resolution (nobody on call) skips the target with a timeline warning
  and an admin system notice — never a silent gap.
- **ESC-4 [M]** Per-user notification rules: for each urgency, an ordered
  list of (delay, contact method). Defaults on user creation: high → push+
  email at 0 min; low → email at 0 min. The policy chooses *who*; the user's
  rules choose *how*.
- **ESC-5 [M]** "Test my notification rules" button: fires a test through
  every configured method and shows per-method delivery results.
- **ESC-6 [M]** Low urgency never triggers voice calls; high urgency ignores
  any future quiet-hours feature. (Quiet hours themselves: **[C]**.)
- **ESC-7 [S]** Policy simulator in UI: "if a high-urgency incident fired
  now, who would be notified, how, and when" — computed from live schedule
  resolution.

### 5.6 Heartbeats and maintenance windows

- **HB-1 [M]** Heartbeat monitors: expected interval + grace; a ping URL
  (`GET/POST /v1/heartbeats/{key}/ping`, secret key auth); missed → triggers
  an alert through the owning service; recovery → auto-resolves it. UI shows
  last-ping ages. (This is the dead-man's-switch for the monitoring stack
  itself, e.g. Alertmanager Watchdog.)
- **SIL-1 [M]** Maintenance windows per service (one-off intervals):
  incidents are still created and grouped but marked suppressed — no
  notifications; if still firing when the window ends, notifications fire
  then (P1: never fail silently).
- **SIL-2 [S]** Recurring maintenance windows. **SIL-3 [C]** Ad-hoc "silence
  this incident's notifications for N minutes".

### 5.7 On-call schedules (ADR-0006)

- **SCH-1 [M]** Schedules with IANA timezone; ordered layers (participants,
  rotation length daily/weekly/custom days-or-hours, anchor instant, local
  handoff time); schedule-level overrides `[start,end)` naming one user.
- **SCH-2 [M]** One pure resolution function used by UI, ICS, chat and
  escalation alike; precedence override > highest covering layer; DST rules
  as pinned in ADR-0006 and covered by a permanent test matrix.
- **SCH-3 [M]** APIs: CRUD; who-is-on-call(schedule, t); expanded shifts over
  a range (for calendar rendering).
- **SCH-4 [M]** ICS feeds (RFC 5545): per schedule and per user ("my
  shifts"), tokenized secret URLs, read-only, subscribable from Google/Apple/
  Outlook.
- **SCH-5 [S]** Layer restrictions (time-of-day / day-of-week windows) for
  follow-the-sun. May slip to v1.0.x; the model supports it from day one.
- **SCH-6 [S]** Handoff notifications: "you are on call now / in 1 hour" via
  the user's channels; configurable lead time.

### 5.8 Notification channels and ChatOps

All channels implement one adapter interface with: send, per-channel retry
classification (retryable vs permanent), and delivery-outcome reporting into
the notification log (ADR-0005). A notification that exhausts retries is
dead-lettered and surfaced (dashboard + metric + admin notice) — **[M]**.

- **CH-EMAIL [M]** SMTP (STARTTLS/TLS): incident notifications with action
  links, invites, password resets, admin notices. Plain-text plus minimal
  HTML.
- **CH-SLACK [M]** Slack app (manifest shipped in-repo, installed per
  workspace by the operator — no marketplace dependency):
  - Socket Mode by default (no public URL); signed HTTP endpoints as the
    documented alternative for multi-replica deployments.
  - Alert cards to per-service channels: severity colour, summary, service,
    who-is-on-call, links; buttons **Acknowledge / Resolve / Escalate**.
  - Cards update in place on every state change from *any* origin; repeats
    and timeline events append to the card's thread.
  - Slack↔AlertDam account linking (button-press by an unlinked Slack user
    gets an ephemeral linking prompt); actions are authorized as the linked
    user and audited.
  - Personal notification rule method "Slack DM".
  - **[S]** Slash commands: `/alertdam oncall|ack <n>|incidents`.
- **CH-TELEGRAM [M]** Bot (BotFather token): long-polling by default
  (webhook + secret token optional); group/channel alert messages with
  inline **Ack/Resolve/Escalate** buttons; account linking via deep-link
  code; DMs as a personal method; **[S]** `/oncall`, `/ack` commands.
- **CH-PUSH [M]** Mobile push via FCM v1 with operator credentials
  (ADR-0008): device registry (register on pairing, list, revoke, prune
  invalid tokens on FCM `UNREGISTERED`); high-priority payloads;
  actionable ack/resolve buttons; Android max-importance channel with
  DND-bypass; iOS Time-Sensitive default, Critical when the operator's app
  is entitled. **[S]** server-driven re-notify every N minutes until ack
  (capped), per user rules.
- **CH-VOICE / CH-SMS [M when Twilio creds configured]** BYOK Twilio:
  - Voice: TTS summary + "press 4 to acknowledge, 6 to escalate" (DTMF);
    no-answer/busy → chain continues; per-call status recorded. Requires a
    public URL for TwiML callbacks (the only feature that does); Twilio
    request-signature validation.
  - SMS: summary + ack link. **[C]** reply-code ack via inbound number.
  - Phone numbers verified (test call/code) before use; per-user hourly call
    caps as cost guard.
- **CH-WEBHOOK [M]** Outbound webhooks: subscribed events
  (`incident.triggered|acknowledged|resolved|escalated`,
  `heartbeat.expired`, ...), versioned JSON envelope, HMAC-SHA256 signature +
  timestamp header (replay window ≤5 min), retries with backoff, per-endpoint
  delivery log with manual redelivery **[S]**. SSRF guard: private/link-local
  destinations refused unless explicitly allow-listed. This is also the v1
  "runbook automation" answer: trigger your own automation, no remote code
  execution in AlertDam.
- **CH-DISCORD [C]** Outbound-only embeds via Discord webhook URL (no
  interactivity; full bot is v1.1).

### 5.9 Web dashboard

Stack: existing React 19 + Vite + Tailwind scaffolding; served by the backend
binary (ADR-0009), same-origin.

- **WEB-1 [M]** Auth screens (login local/OIDC, invite accept, reset).
- **WEB-2 [M]** Incidents: list (filter status/severity/service/urgency/time;
  cursor pagination; auto-refresh ≤10 s) and detail (full timeline incl.
  per-notification delivery outcomes; actions; notes).
- **WEB-3 [M]** Services & integrations: CRUD, key display-once + rotation,
  per-tool setup snippets (copy-paste Alertmanager/Grafana config), test-fire,
  urgency rules, maintenance windows, heartbeats.
- **WEB-4 [M]** Escalation policies: step editor with user/schedule targets,
  delays, repeat; **[S]** the ESC-7 simulator.
- **WEB-5 [M]** Schedules: month/week calendar rendering resolved shifts,
  "on call now" panel, layer editor (forms), override create/edit.
  **[S]** drag-to-create overrides; **[C]** drag-editing rotations.
- **WEB-6 [M]** Profile: timezone, contact methods (verify email/phone),
  notification rules editor with ESC-5 test, personal ICS link, sessions,
  PATs, paired devices.
- **WEB-7 [M]** Admin: users/invites/roles, chat connection status, global
  settings (base URL, retention), audit log viewer.
- **WEB-8 [M]** System health page: queue depths, worker liveness, dead-letter
  browser with requeue, per-channel last-success/failure, DB status, version.
- **WEB-9 [M]** Dashboard home: open incidents by service, my on-call status,
  recent activity.
- **WEB-10 [S]** UX baseline: dark mode default, keyboard navigability, WCAG
  AA contrast, empty states that teach setup, responsive read-only views on
  small screens.

### 5.10 Mobile apps (Flutter; ADR-0008)

- **MOB-1 [M]** Platforms: iOS 15+, Android 8+ (API 26). Operator-built
  (BYO Firebase); fastlane lanes + step-by-step build guide; TestFlight/Play
  internal distribution documented.
- **MOB-2 [M]** Pairing: scan QR (or enter code) from the dashboard profile
  page → server URL + device token stored in secure storage; multiple
  servers **[C]**.
- **MOB-3 [M]** Incident list (open/acked/mine filters, pull-to-refresh,
  reachability banner) and detail (timeline, ack/resolve/escalate, notes).
- **MOB-4 [M]** Push: FCM registration; actionable notifications (ack/resolve
  from the notification without opening the app); deep links to incident
  detail; foreground live updates.
- **MOB-5 [M]** Sound/interruption: Android max-importance channel +
  DND-bypass request flow + distinct alarm sound; iOS Time-Sensitive (+
  Critical when entitled) + custom sound.
- **MOB-6 [M]** On-call view: am I on call, until when, next shifts.
- **MOB-7 [M]** Diagnostics screen: connection state, push token registered
  (server-side check), last push received, "send test push", app/server
  versions. This is the self-hoster's debug surface.
- **MOB-8 [S]** Notification settings in-app (mirror of rules); override
  request **[C]**.

### 5.11 Operability, administration and audit

- **OPS-1 [M]** Subcommands: `serve` (default), `migrate` (up/status),
  `admin create-admin`, `admin reset-password`, `config check` (validates
  env, DB, SMTP/Slack/FCM/Twilio credentials with dry-runs), `healthcheck`
  (for container HEALTHCHECK), `version`, `prune` (retention enforcement).
- **OPS-2 [M]** Migrations embedded in the binary; auto-applied on `serve`
  under an advisory lock (disable with env for regulated ops); forward-only
  after the first tagged release; server refuses to serve on schema mismatch.
- **OPS-3 [M]** `/healthz` (process) and `/readyz` (DB + workers) endpoints;
  `/metrics` Prometheus endpoint. Core metrics (stable names):
  `alertdam_events_ingested_total{result}`,
  `alertdam_incidents_open`,
  `alertdam_notifications_total{channel,outcome}`,
  `alertdam_notification_latency_seconds{channel}`,
  `alertdam_queue_depth{kind}`, `alertdam_queue_oldest_age_seconds{kind}`,
  `alertdam_escalation_fire_drift_seconds`, `alertdam_build_info`.
- **OPS-4 [M]** Structured JSON logs (slog) with request IDs; secrets and
  payload contents never logged; log level via env.
- **OPS-5 [M]** Graceful shutdown: drain workers, release claims, ≤30 s.
  Two-plus replicas safe by construction (ADR-0005); PgBouncer
  transaction-mode caveat documented (ADR-0001).
- **OPS-6 [M]** Documented backup/restore (pg_dump), upgrade, and sizing
  guidance; a "monitor the monitor" guide with example Prometheus alert rules
  for AlertDam itself.
- **OPS-7 [M]** Retention: incidents/alerts kept indefinitely by default;
  `prune --older-than` for alerts, timeline, notification log, audit; sent
  notification rows pruned automatically after N days (default 90).
- **AUD-1 [M]** Audit log: auth events, config mutations, incident actions —
  actor, origin, timestamp, before/after summary; API + UI; included in
  prune policy.

## 6. Non-functional requirements

Reference box for all targets: 2 vCPU / 4 GB VM running the compose stack,
PostgreSQL with 5 M historical alerts.

- **PERF-1 [M]** Ingest: p99 ≤ 250 ms at 50 events/s sustained; 60 s bursts
  of 200 events/s without 5xx (429 is acceptable per ING-6 limits).
- **PERF-2 [M]** Event accepted → notification handed to provider: p95 ≤ 5 s
  (chat, push) under nominal conditions.
- **PERF-3 [M]** Escalation timer fire drift: p95 ≤ 5 s, worst case ≤ 30 s
  across a process restart.
- **PERF-4 [S]** Dashboard initial load ≤ 2 s on broadband; lists paginate
  at 50.
- **REL-1 [M]** Delivery is at-least-once with visible terminal outcomes
  (ADR-0005); duplicate-send budget under induced faults ≤ 1 per 10k.
- **REL-2 [M]** Crash-resume: `kill -9` at any pipeline point loses nothing
  after restart (standing chaos test).
- **REL-3 [M]** DB unavailability: ingest returns 503 (sources retry),
  `/readyz` fails, recovery is automatic (reconnect + LISTEN re-subscribe +
  immediate poll sweep).
- **REL-4 [M]** 24 h soak with fault injection: zero lost notifications, no
  unbounded memory/table growth, all invariants hold.
- **SEC-1 [M]** Secrets hashed (argon2id for passwords; SHA-256 for
  high-entropy tokens/keys) — nothing secret stored plaintext; chat/provider
  credentials via environment, not DB, in v1.
- **SEC-2 [M]** All inbound third-party callbacks verified (Slack signing,
  Telegram secret token, Twilio signature); outbound webhooks signed;
  SSRF guard per CH-WEBHOOK.
- **SEC-3 [M]** Rate limits: login, ingest per key, API per token. Security
  headers + CSP on the SPA. Sessions per AUTH-3.
- **SEC-4 [M]** Dependency policy: Apache-2.0-compatible only (no
  GPL/AGPL/SSPL — enforced by dependency review); actions SHA-pinned.
- **SEC-5 [M]** A threat-model doc and pre-GA security review checklist
  (implementation plan §10) must be executed before tagging v1.0.0.
- **COMPAT-1 [M]** PostgreSQL 14+ (CI on 16); single-node baseline; 2+
  app replicas supported and documented. Browsers: evergreen, last 2
  versions. Node/Flutter/Go versions pinned by the repo's manifests.
- **DOC-1 [M]** Docs are part of the product: quickstart (≤30 min to first
  page), per-integration guides, per-channel setup, mobile build guide,
  self-hosting hardening, backup/upgrade, troubleshooting/runbook ("why did
  nobody get paged?"), API reference generated from the OpenAPI spec.

## 7. Event API contract (summary)

Canonical spec: the OpenAPI document in-repo (M0 deliverable) — this section
pins semantics.

```json
POST /v1/events
{
  "routing_key": "<integration routing key>",
  "event_action": "trigger | acknowledge | resolve",
  "dedup_key": "optional-stable-identity",
  "payload": {
    "summary":  "Storage critical on db-primary-01",
    "severity": "CRITICAL | HIGH | WARNING | INFO",
    "source":   "optional origin identifier",
    "timestamp": "optional RFC 3339",
    "custom_details": { "any": "JSON object" },
    "links": [ { "href": "https://...", "text": "Runbook" } ]
  }
}
```

Semantics:

- `trigger` without a matching open incident creates one; with a match it
  appends (DED-3). `acknowledge`/`resolve` act on the open incident with that
  `dedup_key` and are idempotent; unknown key → 202 no-op (PD parity).
- Responses: `202` accepted (body echoes `dedup_key` and `status`); `400`
  malformed; `401` unknown/invalid routing key; `413`/`429`/`503` per ING-4.
  Validation failures are never 5xx; 5xx always means "retry me".
- Duplicate delivery by a retrying source is harmless by design
  (dedup + idempotent actions).

## 8. Out of scope for v1.0.0 (explicit)

Multi-tenant SaaS, billing, hosted push relay and store-published apps
(Phase 2); Microsoft Teams; WhatsApp; Discord interactive bot (v1.1);
SIP/WebRTC in-app calling; automated war rooms; label/regex routing rules
(v1.1); analytics dashboards (MTTA/MTTR — the *data* is captured in v1);
status pages; email-inbound ingestion; CloudWatch/SNS native mapper (v1.1);
SAML; i18n (English only); UnifiedPush; web push.

## 9. Release criteria for tagging v1.0.0

1. Every **[M]** requirement in §5–§6 closed, or descoped by a PR to this
   document with rationale.
2. Test gates green: full suite incl. DST matrix and authz golden matrix;
   failure-mode matrix (plan §8) fully covered; load (PERF-1/2/3) and 24 h
   soak (REL-4) runs recorded.
3. Upgrade path proven: v0.9 (beta) → v1.0.0 migration on a seeded database;
   backup/restore procedure exercised.
4. Security: plan §10 checklist executed; no known-critical findings open;
   `govulncheck`/audit/Trivy clean or accepted with rationale.
5. Coverage floors met: backend ≥ 70% overall, ≥ 85% on schedule, escalation
   and dedup packages (per CONTRIBUTING's ratchet).
6. Docs per DOC-1 complete; quickstart timed ≤ 30 min on a fresh VM by
   someone who did not write it.
7. Zero open P1 bugs; release artifacts (binaries, images, SBOMs, signatures)
   verified by the documented `cosign`/attestation procedure.

## 10. Post-1.0 direction (context, not commitment)

**v1.1 candidates:** Discord bot, routing rules (route/annotate), MTTA/MTTR
reporting, Datadog/CloudWatch mappers, TOTP, SSE live updates, Slack
channel-per-incident, recurring maintenance windows, read-only role.
**Phase 2 (hosted):** managed offering, project-run push relay +
store-published apps, org/tenant model. v1 keeps these possible (no
design choices that assume single-org forever) but builds none of them.
