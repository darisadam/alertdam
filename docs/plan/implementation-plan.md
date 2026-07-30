# AlertDam v1.0.0 — Implementation Plan

**Scope of record:** [prd-v1.md](prd-v1.md). Where this plan and the PRD
disagree, the PRD wins. Rationale for scope decisions:
[prd-review.md](prd-review.md). Load-bearing design decisions: ADRs
[0004](../adr/0004-deterministic-deduplication.md),
[0005](../adr/0005-durable-jobs-and-notification-outbox.md),
[0006](../adr/0006-oncall-schedule-model.md),
[0007](../adr/0007-authentication-and-sessions.md),
[0008](../adr/0008-mobile-push-via-byo-firebase.md),
[0009](../adr/0009-embed-web-ui-in-binary.md).

## 1. How to read this plan

- A **task** is one PR-sized unit with a suggested Conventional Commit title
  (which becomes the squash-merge subject on `main`), a scope statement, and
  acceptance criteria. Branch names follow `<type>/<kebab-description>`.
- Sizes: **S** ≤ 2 days, **M** ≤ 1 week, **L** 1–2 weeks (single engineer,
  including tests and docs). Estimates include review turnaround.
- Every milestone ends in a **demoable exit criterion**. Milestones are
  releasable increments: `main` stays green and shippable throughout
  (release-please already cuts v0.x minors from merged `feat:` PRs).
- Tasks should be mirrored into GitHub issues under milestones `M0`…`M9`
  (see Appendix A). This file is the plan of record; issues are the working
  state.

## 2. Where the repository stands today (2026-07-30)

Strong foundations, no product yet:

- **Done and good:** governance/community files; conventions enforcement
  (hooks + CI); CI matrix (Go, web, Flutter, Docker, migrations, shell) with
  SHA-pinned actions; release automation (release-please + GoReleaser +
  cosign signing + SBOM + provenance); compose file; scratch-image
  Dockerfile; brand assets; docs skeleton.
- **Backend:** `cmd/alertdam` starts an HTTP server with graceful shutdown;
  every `/v1` handler is a stub (mostly 501/empty); no DB connection, no
  config layer beyond `APP_PORT`, no subcommands. `internal/alert` is dead
  code (tracked). Only dependency: chi.
- **Schema:** `migrations/001_initial.sql` is a first draft — incidents but
  no alert rows, a single queue table (ADR-0005 replaces it), sessions table
  but JWT env var, no teams/contact-methods/notification-rules/audit/
  heartbeats/devices.
- **Web:** scaffold with routing shell and placeholder pages; good tooling
  (Vite, TS strict, vitest, ESLint/Prettier).
- **Mobile:** Flutter lib skeleton with FCM/local-notifications wiring in
  `main.dart`; `ios/`/`android/` do not exist yet (tracked), so it cannot
  build.
- **Known rough edges** (tracked in AGENTS.md) are scheduled here rather
  than fixed silently: dead ingest code → M0-02; no `migrate` subcommand →
  M0-03/M0-05; missing platform dirs → M7-01; advisory coverage → M9-08.

## 3. Target architecture at v1.0.0

```
                    ┌────────────────────────────────────────────────┐
 Alertmanager ─▶    │                 alertdam binary                │
 Grafana      ─▶    │                                                │
 curl/anything─▶    │  httpapi ──▶ ingest ──▶ dedup ──▶ incident     │
 heartbeat pings ─▶ │                │                    │          │
                    │                ▼                    ▼          │
 Slack (socket) ◀─▶ │   ┌──────── PostgreSQL (single source) ─────┐  │
 Telegram (poll)◀─▶ │   │ alerts incidents timeline schedules ... │  │
 Twilio callback ─▶ │   │ jobs (timers)   notifications (outbox)  │  │
                    │   └──────────────────────────────────────────┘ │
                    │        ▲ LISTEN/NOTIFY + ≤5s poll               │
                    │        │                                        │
                    │  escalation engine ──▶ recipient resolution     │
                    │        │                   (rules × schedules)  │
                    │        ▼                                        │
                    │  delivery workers ─▶ email slack telegram push  │
                    │                      voice sms webhook          │
                    │  embedded SPA (go:embed) + /metrics /readyz     │
                    └────────────────────────────────────────────────┘
```

**Backend package layout** (module `github.com/darisadam/alertdam`):

```
cmd/alertdam/          subcommand dispatch (serve, migrate, admin, ...)
internal/config/       env loading + validation + `config check` probes
internal/store/        pgx pool, queries, migrations (embedded), tx helpers
internal/httpapi/      chi router, middleware, OpenAPI-generated interfaces
internal/ingest/       event contract, mappers (alertmanager, grafana), limits
internal/incident/     domain: dedup, state machine, timeline, storm guard
internal/escalation/   policy engine (jobs-driven), recipient resolution
internal/schedule/     pure resolution engine + ICS rendering
internal/queue/        jobs + notifications claim protocol, worker pool
internal/notify/       channel adapter interface
internal/notify/{email,slack,telegram,push,twilio,webhook}/
internal/auth/         sessions, PATs, OIDC, RBAC matrix
internal/audit/        recorder + query
internal/web/          go:embed of web/dist, SPA handler
```

**Schema v2 inventory** (migration 002+, replaces the 001 draft where noted):

| Table | Purpose / notable columns |
|---|---|
| `users`, `user_contact_methods`, `user_notification_rules` | contact methods typed+verified; rules = (urgency, delay, method) |
| `user_identities` | OIDC subject, Slack user ID, Telegram chat ID links |
| `user_sessions`, `api_tokens`, `devices` | hashed credentials; devices = push registry |
| `teams`, `team_members`, `services` | service → policy binding, urgency rules, storm cap |
| `integrations` | service-scoped, type, hashed routing key + display prefix |
| `alerts` | **new** — one row per accepted event (ADR-0004) |
| `incidents` | + number seq, urgency, suppressed flag; keeps partial unique dedup index |
| `incident_timeline` | renamed from `incident_events`; actor + origin |
| `escalation_policies`, `escalation_steps`, `escalation_step_targets` | as 001, minus per-step `notify_via` (rules own the *how*) |
| `schedules`, `schedule_layers`, `schedule_layer_users`, `schedule_overrides` | + rotation length, anchor, restrictions (ADR-0006) |
| `jobs` | **new** — durable timers (ADR-0005) |
| `notifications` | **replaces** `notification_queue` — outbox + delivery log |
| `incident_chat_messages` | incident ↔ chat message mapping for in-place card updates |
| `chat_channel_routes` | service → Slack channel / Telegram chat routing |
| `heartbeats`, `maintenance_windows`, `webhook_endpoints`, `audit_log`, `settings` | per PRD §5.6/5.8/5.11 |

Pre-beta schema policy: until v0.9 is tagged, migrations may reshape
destructively (there are no deployments to preserve). From v0.9 on:
forward-only, auto-applied under advisory lock (OPS-2).

## 4. Engineering guardrails (apply to every task)

1. **Postgres-only** (ADR-0001). No new stateful infrastructure, ever, without
   an ADR.
2. **Time discipline:** domain packages take an injected clock; `time.Now()`
   is lint-banned in `schedule`/`escalation`/`queue`; queue deadlines compare
   against DB `now()` (ADR-0005/0006).
3. **Outbox invariant:** state change and its jobs/notifications commit in one
   transaction. Code review rejects violations.
4. **OpenAPI-first:** `/v1` shape lives in the spec; handlers implement
   generated interfaces; CI diffs generated code. Errors use one envelope
   (RFC 9457 `application/problem+json`).
5. **Every channel adapter** reports outcomes into the notification log;
   "fire and forget" is not an accepted pattern (P1).
6. **Secrets:** hashed at rest (SEC-1), redacted in logs (OPS-4), provider
   credentials via env. `.env.example` updated in the same PR as any new
   variable (PR checklist enforces).
7. **Repo constraints stand:** SHA-pinned actions + allow-list for any CI
   change; Apache-2.0-compatible deps only; never touch the items in
   AGENTS.md "things not to touch".
8. **SaaS-neutrality:** no code assumes single-org in ways that are expensive
   to unwind (e.g. no global mutable config singletons), but no `org_id`
   speculation either — YAGNI until Phase 2.

## 5. Dependency shortlist

Licenses are re-verified at adoption time; the dependency-review CI job
enforces the Apache-2.0-compatible policy either way.

| Dependency | Purpose | License (verify) |
|---|---|---|
| `jackc/pgx/v5` (+pgxpool) | PostgreSQL driver | MIT |
| `pressly/goose/v3` *or* `jackc/tern` | embedded migrations | check both; pick the cleaner embed story |
| `sqlc` (build-time) | typed queries | MIT |
| `oapi-codegen` (build-time) | OpenAPI → chi interfaces | Apache-2.0 |
| `coreos/go-oidc/v3` + `golang.org/x/oauth2` | OIDC | Apache-2.0 / BSD |
| `alexedwards/scs` *or* hand-rolled | sessions (we already have the table; prefer hand-rolled ~200 LOC) | — |
| `slack-go/slack` | Slack API + Socket Mode | BSD-2 |
| Telegram: `go-telegram/bot` *or* raw HTTP | Bot API is small; prefer thin | MIT |
| `golang.org/x/crypto/argon2` | password hashing | BSD |
| `prometheus/client_golang` | metrics | Apache-2.0 |
| `google/uuid` | IDs | BSD-3 |
| FCM: raw HTTP v1 + `golang.org/x/oauth2/google` | push (avoid the heavy firebase-admin SDK) | BSD |
| Twilio: raw REST + request validation (small, well-documented) | voice/SMS | — |
| web: `react-hook-form`, `zod` | forms/validation | MIT |
| e2e: Playwright; load: k6 (external tools) | testing | Apache-2.0 |

Bias: thin clients over SDK frameworks; every dependency must be justifiable
to a security-conscious self-hoster reading `go.mod`.

## 6. Milestones

### M0 — Platform foundations (~3 wk)

**Goal:** the binary becomes an operable service: config, DB, migrations,
observability, subcommands, test harness. Fixes the tracked rough edges.
**Exit demo:** `docker compose up` → healthy container (real HEALTHCHECK),
`alertdam migrate status` works, `/metrics` and `/readyz` live, schema v2
applied, CI runs DB-backed tests.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M0-01 | `feat(backend): add validated environment configuration` | Typed config struct; startup fails fast listing *all* invalid vars; secrets never printed; docs table regenerated from struct tags. | S | — |
| M0-02 | `refactor(api): wire ingestion through internal/alert` | Remove the router's local stub duplication; one handler package; behaviour unchanged (202). Closes the dead-code rough edge. | S | — |
| M0-03 | `feat(cli): add subcommand dispatch (serve, version, healthcheck)` | Stdlib dispatch; bare invocation = `serve` (compose/ENTRYPOINT compatible); `healthcheck` probes `/healthz` and exits 0/1 (works from `scratch`). | M | M0-01 |
| M0-04 | `feat(backend): connect PostgreSQL via pgx pool` | Pool with sane limits; `/healthz` (process) vs `/readyz` (DB ping); reconnect with backoff; required `DATABASE_URL` for serve. | M | M0-01 |
| M0-05 | `feat(backend): embedded migrations and migrate subcommand` | go:embed SQL; `migrate up|status`; auto-migrate on serve under advisory lock (env-disable); CI migrations job still applies raw SQL identically; Makefile `migrate-up` note replaced; makes deployment.md's auto-migrate claim true. | M | M0-03, M0-04 |
| M0-06 | `feat(db): schema v2 core remodel` | Migration 002 per §3 inventory (pre-beta destructive OK); CI schema assertions updated; ERD comment header in the SQL. | L | M0-05 |
| M0-07 | `feat(backend): structured JSON logging with redaction` | slog; request logs with request ID; secret/payload redaction helpers + tests; level via env. | S | M0-01 |
| M0-08 | `feat(backend): Prometheus metrics and container healthchecks` | `/metrics` with OPS-3 base metrics + build info; Dockerfile/compose `HEALTHCHECK` via `alertdam healthcheck`. | M | M0-03 |
| M0-09 | `build(api): adopt OpenAPI spec with generated chi interfaces` | `api/openapi.yaml` seeded with current `/v1` surface; oapi-codegen wiring; CI check that generated code is in sync; problem+json error envelope. | M | — |
| M0-10 | `test(backend): PostgreSQL-backed test harness` | Per-test isolated schema against a real PG (testcontainers locally, service container in CI); first integration test = migrations apply + assert. | M | M0-05 |
| M0-11 | `ci: add postgres service to the backend job` | Pinned image/action edits per repo policy; DB tests run in CI. | S | M0-10 |
| M0-12 | `chore(dev): compose dev overlay with mailpit` | `docker-compose.dev.yml` adding mailpit (SMTP sink) for local email work; documented in backend README. | S | — |

### M1 — Identity and access (~3 wk)

**Goal:** ADR-0007 implemented end-to-end; the dashboard gets a real login.
**Exit demo:** `alertdam admin create-admin` → login (local and OIDC against
Keycloak in dev compose) → invite a member by email → member sets password →
authz matrix test green.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M1-01 | `feat(auth): local accounts with server-side sessions` | argon2id; opaque cookie sessions (hashed, absolute+idle expiry); CSRF; logout/logout-everywhere; login rate limit. Removes `JWT_SECRET` from config surface (compose + .env.example updated). | L | M0-06 |
| M1-02 | `feat(auth): bootstrap, invites and password reset over SMTP` | Minimal SMTP sender util (full channel lands M3); expiring invite/reset tokens (hashed); `admin create-admin`, `admin reset-password`. | M | M1-01 |
| M1-03 | `feat(auth): OIDC login` | Discovery + PKCE; JIT provisioning behind flag; `user_identities` linkage; Keycloak added to dev overlay for testing. | M | M1-01 |
| M1-04 | `feat(auth): personal access tokens and role middleware` | `ad_` tokens hashed, scopes read/write, last-used; route×role matrix as data + golden test (AUTH-5). | M | M1-01 |
| M1-05 | `feat(audit): audit log recorder and API` | AUD-1 events with actor+origin; recorder called from auth paths now, everything later; list API with filters. | M | M0-06 |
| M1-06 | `feat(web): authenticated app shell` | Login/invite/reset pages; OIDC button; guarded routes; TanStack Query client + API layer with CSRF; profile page (timezone); replaces the placeholder `App.tsx`. | L | M1-01..03 |
| M1-07 | `docs: authentication and access guide` | Local + OIDC (Keycloak/Google examples) + PAT usage + session semantics. | S | M1-04 |

### M2 — Ingestion and incident core (~4 wk)

**Goal:** events become deduplicated incidents with a queryable timeline
(ADR-0004). No notifications yet — but everything they need exists.
**Exit demo:** real Alertmanager fires → incident appears in the dashboard
with correct severity/urgency; repeat alerts increment one incident; ack via
UI; resolve event auto-resolves it; test-fire button works.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M2-01 | `feat(core): teams, services and integrations` | CRUD APIs; hashed routing keys, display-once + rotation; urgency rules (SVC-2); OpenAPI updated. | M | M1-04 |
| M2-02 | `feat(ingest): full /v1/events contract` | §7 semantics; limits ING-5; response-code matrix ING-4 as table-driven tests; per-key rate limit; ingest metrics; Go fuzz target for the parser. | L | M2-01 |
| M2-03 | `feat(incident): deduplication engine and incident lifecycle` | ADR-0004: txn upsert on partial unique index; repeat counting + alert-row cap; resolve/trigger-after-resolve; severity upgrade recording; storm guard (ING-6); state machine INC-1 with actor+origin. | L | M2-02 |
| M2-04 | `feat(api): incident endpoints` | Cursor-paginated list with filters; detail with timeline; ack/resolve/escalate-now/notes; idempotency tests. | M | M2-03 |
| M2-05 | `feat(ingest): alertmanager inbound mapper` | ING-2 with golden fixtures from real payloads (firing+resolved, grouped); configurable severity label. | M | M2-03 |
| M2-06 | `feat(ingest): grafana inbound mapper` | ING-3, golden fixtures. | S | M2-03 |
| M2-07 | `feat(core): maintenance windows` | SIL-1: CRUD + suppressed incident marking at create time (notification suppression enforced in M3); un-suppress-at-window-end job lands M3. | S | M2-03 |
| M2-08 | `feat(web): services and integrations UI` | WEB-3 minus heartbeats: CRUD, key display-once, per-tool setup snippets, test-fire. | M | M2-01, M1-06 |
| M2-09 | `feat(web): incident list and detail` | WEB-2: filters, pagination, ≤10 s refresh, timeline, actions, notes. | L | M2-04, M1-06 |
| M2-10 | `docs: integration guides (alertmanager, grafana, generic)` | Copy-paste configs matching the setup snippets; replaces the aspirational parts of docs/api-reference.md with spec-derived content. | S | M2-05, M2-06 |

### M3 — Delivery pipeline and escalation engine (~5 wk)

**Goal:** ADR-0005 in full: durable jobs, notification outbox, workers,
retries, DLQ; escalation policies execute; first two channels (email,
webhook) prove the pipeline end-to-end.
**Exit demo:** unacked incident escalates step 1 → 2 → repeat with correct
timing; `kill -9` mid-wait, restart, escalation resumes on schedule; failed
SMTP send retries then dead-letters visibly; system health page shows it all.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M3-01 | `feat(queue): durable jobs and notification outbox` | Two tables + claim protocol (SKIP LOCKED, leases, re-claim); LISTEN/NOTIFY wake + ≤5 s poll; DB-time deadlines; outbox tx helpers; queue metrics. | L | M0-06 |
| M3-02 | `feat(queue): worker pool lifecycle` | Start with serve; graceful drain (OPS-5); panic isolation per job; DLQ status + requeue API; lease-expiry reclaim test. | M | M3-01 |
| M3-03 | `feat(escalation): policy engine` | ESC-1/2/3: steps as jobs; ack/resolve cancellation via state re-check; repeat; ack-timeout (INC-7); empty-target warnings; `kill -9` resume test (REL-2). | L | M3-01, M2-03 |
| M3-04 | `feat(escalation): recipient resolution` | ESC-4: user rules × urgency → notification rows; in-flight (user, method) dedupe; defaults on user creation. | M | M3-03 |
| M3-05 | `feat(notify): email channel` | CH-EMAIL over the adapter interface; templates with action links; mailpit-backed integration tests; delivery outcomes recorded. | M | M3-02 |
| M3-06 | `feat(notify): outbound webhooks` | CH-WEBHOOK: HMAC + timestamp, retries, SSRF guard (deny private ranges unless allow-listed, with tests), per-endpoint log. | M | M3-02 |
| M3-07 | `feat(core): heartbeat monitors` | HB-1 end-to-end: ping endpoint, expiry via jobs, auto-trigger/auto-resolve; maintenance-window end un-suppression job (completes SIL-1). | M | M3-01, M2-07 |
| M3-08 | `feat(web): system health page` | WEB-8: queue depths/ages, worker liveness, DLQ browser + requeue, channel last-success/failure. | M | M3-02 |
| M3-09 | `feat(web): escalation policies and notification rules UI` | WEB-4 editor; WEB-6 rules editor + ESC-5 "test my rules". | L | M3-04, M1-06 |
| M3-10 | `test(escalation): time-travel scenario suite` | Fake clock + scenario DSL (policy × events × expected notifications/timing); becomes the regression bed for every future escalation bug. | M | M3-03 |

### M4 — Schedules and on-call (~4 wk)

**Goal:** ADR-0006 implemented; escalation targets real on-call humans.
**Exit demo:** weekly rotation with an override resolves identically in the
calendar UI, ICS export, API and a fired escalation — across a DST
transition; handoff notification arrives.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M4-01 | `feat(schedule): resolution engine` | Pure function per ADR-0006; layers/rotations/overrides (+restrictions if cheap, else M4-08); property tests + the permanent DST matrix (named zones incl. +05:30, +10:30, +12:45). | L | M0-06 |
| M4-02 | `feat(schedule): CRUD and on-call APIs` | SCH-3: CRUD, who-is-on-call, range expansion for calendars; OpenAPI. | M | M4-01 |
| M4-03 | `feat(escalation): schedule targets` | ESC-3 resolution at fire time; empty → warn path tested. | S | M4-01, M3-03 |
| M4-04 | `feat(schedule): ICS feeds` | SCH-4: schedule + personal feeds, tokenized URLs, RFC 5545 validated against Google/Apple import. | M | M4-02 |
| M4-05 | `feat(schedule): handoff notifications` | SCH-6 via jobs; configurable lead. | S | M4-01, M3-04 |
| M4-06 | `feat(web): schedule calendar` | WEB-5 read views (month/week) + on-call-now panel, rendered from the range-expansion API. | L | M4-02, M1-06 |
| M4-07 | `feat(web): layer and override editors` | Form-based editors; override quick-create. | M | M4-06 |
| M4-08 | `feat(schedule): layer restrictions` | SCH-5 follow-the-sun windows (if not folded into M4-01). | M | M4-01 |
| M4-09 | `docs: scheduling guide` | Recipes: weekly primary/secondary, follow-the-sun, override etiquette, DST behaviour statement. | S | M4-07 |

### M5 — ChatOps: Slack and Telegram (~5 wk)

**Goal:** P2 delivered — the full incident loop from chat (PRD §5.8).
**Exit demo:** incident fires → Slack card + Telegram message; ack in
Telegram updates the Slack card and the web timeline within seconds;
unlinked user pressing a button gets a linking prompt; `/alertdam oncall`
answers.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M5-01 | `feat(slack): socket-mode client and app manifest` | Connection lifecycle + health surfacing (system health page); manifest YAML in-repo; signed-HTTP alternative documented. | M | M3-02 |
| M5-02 | `feat(slack): alert cards with state sync` | Cards per chat_channel_routes; in-place updates on every transition from any origin (incident_chat_messages); thread appends for repeats/timeline. | L | M5-01, M3-04 |
| M5-03 | `feat(slack): interactive actions and account linking` | Ack/Resolve/Escalate buttons; ephemeral linking flow; actions authorized as linked user + audited; signature verification tests (recorded fixtures). | L | M5-02 |
| M5-04 | `feat(slack): direct-message notifications` | "Slack DM" contact method wired into rules; handoff DMs. | M | M5-03 |
| M5-05 | `feat(telegram): bot with inline actions` | Long-poll client; group/channel posts + inline keyboards; callback auth via linked chat; `/link` deep-link flow; webhook mode + secret token documented. | L | M3-02 |
| M5-06 | `feat(telegram): DMs and commands` | DM contact method; `/oncall`, `/ack`. | M | M5-05 |
| M5-07 | `feat(core): per-service chat routing config + UI` | chat_channel_routes CRUD + web UI; channel test-message button. | M | M5-02, M5-05 |
| M5-08 | `feat(slack): slash commands` | `/alertdam oncall|ack|incidents` (ESC-7-adjacent convenience). | M | M5-03 |
| M5-09 | `test(chat): fake provider servers and contract fixtures` | Local fake Slack/Telegram HTTP servers driven by recorded payloads; interaction contract tests run in CI without real tokens. | M | M5-03, M5-05 |
| M5-10 | `docs: slack and telegram setup guides` | Manifest import walkthrough, BotFather steps, linking, troubleshooting. | S | M5-07 |
| M5-11 | `feat(discord): outbound-only webhook embeds` | CH-DISCORD [C]; clearly labelled notify-only. | S | M3-02 |

### M6 — Dashboard completion and single-artifact serving (~4 wk)

**Goal:** WEB-* complete; ADR-0009 lands; **v0.9.0 public beta** ships.
**Exit demo:** fresh VM, `docker compose up`, browse to `:8080`, complete
Priya's ≤30-minute journey with no dev tooling installed.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M6-01 | `feat(web): dashboard home` | WEB-9: open incidents by service, my on-call, recent activity. | M | M2-09, M4-06 |
| M6-02 | `feat(web): user and team administration` | WEB-7: invites, roles, deactivation; team membership. | M | M1-06 |
| M6-03 | `feat(web): audit viewer and global settings` | WEB-7 remainder: audit filters; base URL, retention settings. | M | M1-05 |
| M6-04 | `feat(web): UX hardening pass` | WEB-10: empty states that teach, error/loading states, keyboard nav, AA contrast, responsive read views. | M | M6-01..03 |
| M6-05 | `feat(backend): embed the web dashboard (go:embed)` | ADR-0009: SPA fallback, cache headers, `dev` build tag placeholder; same-origin cookie flow verified. | M | M6-04 |
| M6-06 | `build(release): web build stage in Docker and GoReleaser` | Node stage in Dockerfile; GoReleaser before-hook; CI stale-embed check; image size budget noted. | M | M6-05 |
| M6-07 | `test(e2e): Playwright suite against the compose stack` | Journeys: login → service → test-fire → ack → resolve; schedule override; runs in CI (new pinned job) on PRs touching web/backend. | M | M6-05 |
| M6-08 | `chore(release): cut v0.9.0 beta` | Beta notes, known-limitations doc, feedback channel (Discussions), upgrade promise from v0.9 → v1.0. | S | all M6 |

### M7 — Mobile apps (~6 wk, parallel lane from M3 onward)

**Goal:** MOB-* per ADR-0008. Backend work (device registry, FCM channel,
re-notify) is part of this lane.
**Exit demo:** Marco's journey — CRITICAL at 03:00, phone through DND, ack
from lock screen, Slack card flips to acknowledged.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M7-01 | `feat(mobile): generate ios and android platform scaffolds` | `flutter create --platforms=android,ios .`; bundle IDs, icons, min SDK/iOS versions; CI gains a debug-build step (dummy Firebase config for CI). Closes the tracked rough edge. | M | — |
| M7-02 | `feat(api): device pairing and registry` | MOB-2 backend: QR/one-time code from profile page; device tokens (hashed), list/revoke API; web UI section. | M | M1-04 |
| M7-03 | `feat(mobile): pairing and API client` | Scan/enter code; secure storage; dio client + riverpod stores; reachability banner. | L | M7-01, M7-02 |
| M7-04 | `feat(notify): FCM push channel` | CH-PUSH backend: FCM v1 with service-account creds; token lifecycle incl. UNREGISTERED pruning; `config check` dry-run validation. | M | M3-02, M7-02 |
| M7-05 | `feat(mobile): incident list, detail and actions` | MOB-3 with foreground live updates. | L | M7-03 |
| M7-06 | `feat(mobile): actionable push notifications` | MOB-4: ack/resolve from the notification, deep links, background handler. | L | M7-04, M7-05 |
| M7-07 | `feat(mobile): android alerting channels and dnd bypass` | MOB-5 Android: max-importance channel, DND-bypass request UX, alarm sound. | M | M7-06 |
| M7-08 | `feat(mobile): ios interruption levels and sounds` | MOB-5 iOS: Time-Sensitive default; Critical behind entitlement flag; sound assets. | M | M7-06 |
| M7-09 | `feat(notify): re-notify until acknowledged` | CH-PUSH [S]: server-driven repeat via jobs, capped, per user rules. | M | M7-04 |
| M7-10 | `feat(mobile): on-call view and diagnostics screen` | MOB-6 + MOB-7 (incl. "send test push" round-trip). | M | M7-05 |
| M7-11 | `build(mobile): fastlane lanes and byo-firebase build guide` | MOB-1: lanes for both platforms; the step-by-step Firebase/APNs/TestFlight/Play-internal guide; doc tested by a clean-room run. | M | M7-08 |

### M8 — Telephony, BYOK Twilio (~2 wk, flag-gated; parallel after M3)

**Goal:** CH-VOICE/CH-SMS. The only feature requiring a public URL —
documented as such.
**Exit demo:** escalation step reaches a verified phone; voice call reads
the summary; pressing 4 acks; timeline and Slack update.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M8-01 | `feat(voice): twilio voice channel with dtmf actions` | TwiML flow, no-answer/busy handling, signature validation, outcomes recorded. | L | M3-04 |
| M8-02 | `feat(sms): twilio sms channel` | Summary + ack link; cost-guard caps shared with voice. | M | M8-01 |
| M8-03 | `feat(core): phone verification and call caps` | Verify via code call/SMS before use; per-user hourly caps; `config check` Twilio probe. | M | M8-01 |
| M8-04 | `docs: twilio byok guide` | Setup, public-URL requirement, cost expectations, testing tips. | S | M8-03 |

### M9 — Hardening and GA (~3 wk)

**Goal:** PRD §9 release criteria, proven.
**Exit:** v1.0.0 tagged; artifacts verified; quickstart timed on a fresh VM.

| ID | Suggested PR title | Scope & acceptance | Size | Needs |
|---|---|---|---|---|
| M9-01 | `test(load): k6 profiles enforcing PERF targets` | Ingest steady + storm profiles; nightly workflow; results archived. | M | M6 |
| M9-02 | `test(chaos): fault-injection suite` | Scripted: app kill mid-escalation, PG restart, provider 5xx/timeout/hang, NOTIFY blackhole; asserts §8 matrix rows. | M | M6 |
| M9-03 | `test(soak): 24h nightly soak with invariants` | Continuous synthetic load + induced faults; invariant checker (no lost/dup beyond REL-1, bounded growth). | M | M9-02 |
| M9-04 | `chore(security): execute the pre-GA security checklist` | §10 checklist run; fixes; recorded results in docs/security-review-v1.md. | M | M6, M7, M8 |
| M9-05 | `perf(db): index and query audit at 10M rows` | Seeded volume; EXPLAIN audit of hot paths; `prune` command (OPS-7). | M | M6 |
| M9-06 | `docs: production operations set` | Hardening, monitor-the-monitor (example Prometheus rules), backup/restore, upgrade, troubleshooting runbook ("why did nobody get paged?"), FAQ. | M | M6 |
| M9-07 | `test(upgrade): v0.9 to v1.0 migration verification` | Seeded v0.9 database upgraded in CI; assertions on data integrity. | S | M9-05 |
| M9-08 | `ci: ratchet coverage floors` | Backend ≥70% overall, ≥85% schedule/escalation/dedup (per the documented ratchet). | S | M9-03 |
| M9-09 | `chore(release): v1.0.0` | `release-as: 1.0.0` PR; checklist: artifact signature verification, fresh-VM quickstart timing, announcement notes. | S | all |

## 7. Sequencing, staffing and timeline

Critical path: **M0 → M1 → M2 → M3 → M4 → M5 → M6** (≈ 24 eng-weeks of
backend+web). M7 (mobile, ≈6) runs as a parallel lane once M3-02 and M7-02
exist; M8 (≈2) parallel after M3; M9 (≈3) is serial at the end. Total ≈ 39
engineer-weeks, including tests and docs, excluding community management.

Within milestones, web tasks (`*-0x` web rows) can proceed in parallel with
the next milestone's backend tasks — the lanes are: **backend core**,
**web**, **mobile**, each independently PR-able.

| Staffing | v0.9 beta (post-M6) | v1.0.0 GA (post-M9) |
|---|---|---|
| 1 engineer | ~May 2027 | ~Aug 2027 |
| 2 engineers (backend + full-stack) | **late Nov 2026** | **Feb 2027** |
| 3 engineers (+ mobile) | **early Nov 2026** | **late Dec 2026 – Jan 2027** |

Assumptions: start early Aug 2026, ~75% focus factor, review latency < 1 day
(solo maintainer review is the hidden serializer — keep PRs small). The
de-scope levers, in order, if dates slip: M5-08/M5-11 (commands, Discord
notify-only), M4-08 (restrictions), ESC-7 simulator, M8 (telephony is
flag-gated and can ship in v1.0.x), MOB-8. The non-negotiables are P1–P6 and
the failure-mode matrix.

## 8. Failure-mode matrix (what "robust" means, testably)

| # | Scenario | Required behaviour | Proven by |
|---|---|---|---|
| F1 | Process killed between incident insert and notification send | Outbox rows committed with incident; workers deliver after restart | M3-03 kill test; M9-02 |
| F2 | Process killed mid escalation delay | Timer is a DB job; fires within PERF-3 after restart | M3-03; M9-02 |
| F3 | Two replicas running | No duplicate step fires or deliveries (SKIP LOCKED + leases + state re-check) | M3-01 concurrency test |
| F4 | `LISTEN/NOTIFY` lost or connection dropped | ≤5 s poll picks up work; latency degrades, correctness unaffected | M3-01; M9-02 NOTIFY blackhole |
| F5 | PostgreSQL down | Ingest 503s (sources retry), `/readyz` red, auto-recovery incl. re-LISTEN + poll sweep | M9-02 PG restart |
| F6 | Provider (Slack/SMTP/FCM) erroring or hanging | Timeouts, classified retries with backoff, dead-letter + dashboard/metric/admin notice; other channels unaffected | M3-05/06 fault tests; M9-02 |
| F7 | Provider succeeded but ack lost (crash after send) | Bounded duplicate (≤ REL-1 budget) — duplicate page over missing page | M9-03 invariant checker |
| F8 | Duplicate/concurrent identical events | Single incident (partial unique index upsert); counters correct | M2-03 race test |
| F9 | Alert storm (many distinct keys) | Rate limit + storm-guard fold; the *system* stays responsive; storm incident pages once | M2-03; M9-01 storm profile |
| F10 | Oversized/hostile payloads | 413/400; truncation markers; fuzzed parser never panics | M2-02 fuzz + limits tests |
| F11 | DST transition during a shift | Resolution correct per ADR-0006 pinned rules; UI = ICS = pager | M4-01 DST matrix |
| F12 | Schedule resolves to nobody | Step skipped loudly: timeline warning + admin notice — never silent | M4-03 |
| F13 | Replica wall clocks skewed | Deadlines compared against DB `now()` only | M3-01 design test; lint ban |
| F14 | Migration fails mid-upgrade | Transactional migration + advisory lock; server refuses to serve on mismatch; restore documented | M0-05; M9-07 |
| F15 | Chat credentials revoked/expired | Connection health on system page + admin notice; deliveries dead-letter visibly | M5-01; M3-08 |
| F16 | Graceful shutdown under load | In-flight jobs finish or release cleanly within 30 s; nothing stuck `claimed` | M3-02 drain test |
| F17 | Webhook target is internal/malicious | SSRF guard refuses private ranges unless allow-listed | M3-06 tests |
| F18 | Operator misconfiguration | Startup fails fast with actionable errors; `config check` validates credentials with dry-runs | M0-01; M7-04 |

## 9. Test strategy

- **Unit:** domain logic (dedup, state machine, escalation, schedule
  resolution) — table-driven; injected clocks everywhere (guardrail 2).
- **Property tests:** schedule invariants (exactly-one-on-call, handoff
  continuity, override boundaries) via `testing/quick` or rapid.
- **DST matrix (permanent):** America/New_York, Europe/London spring+fall;
  Asia/Kolkata (+05:30), Australia/Lord_Howe (+10:30/+11:00),
  Pacific/Chatham (+12:45). Runs on every PR touching schedule code.
- **Integration:** real PostgreSQL (M0-10 harness); migrations; queue claim
  concurrency; golden fixtures for Alertmanager/Grafana/Slack/Telegram/Twilio
  payloads (recorded once, replayed forever — no live tokens in CI).
- **E2E:** Playwright over the compose stack (M6-07); Flutter widget tests +
  one emulator smoke per PR touching mobile [S].
- **Fuzz:** Go native fuzzing on every wire parser (events, mappers, chat
  callbacks).
- **Load/chaos/soak:** k6 profiles, fault-injection scripts, 24 h nightly
  soak (M9-01..03) — scheduled workflows, not PR-blocking.
- **Coverage:** advisory today by design; ratchet at M9-08 to the PRD floors.
  Don't add floors earlier — stubs would game them.

## 10. Security plan

Threats and owners of their controls:

| Surface | Threats | Controls (task) |
|---|---|---|
| Public ingest | key brute force, floods, hostile payloads, dedup poisoning | hashed high-entropy keys (M2-01), rate limits + storm guard (M2-02/03), size caps + fuzz (M2-02) |
| Browser auth | credential stuffing, session theft, CSRF | argon2id + rate limit, cookie flags, CSRF, revocation (M1-01) |
| Chat callbacks | forged actions, replay | Slack signing / Telegram secret / Twilio signature verification with fixture tests (M5-03/05, M8-01); actor mapping + audit |
| Outbound webhooks | SSRF into internal networks | deny-private-by-default + allowlist (M3-06) |
| Secrets at rest / in logs | DB dump or log leak | hash-at-rest policy (SEC-1), redaction (M0-07), env-only provider creds, gitleaks (already enforced) |
| Supply chain | dep/action compromise | SHA-pinned actions + allow-list (existing), dependency review (existing), thin-dependency bias (§5), signed releases (existing) |
| AuthZ | privilege escalation, IDOR | route×role golden matrix (M1-04) + per-object checks in reviews |

Checkpoints: authz matrix green from M1 onward; signature-verification
fixtures land with each chat/telephony channel; M9-04 executes the full
checklist (re-run matrix, SSRF, rate limits, secrets-in-logs sweep, fuzz
corpus review, `govulncheck`/`npm audit`/Trivy) and records results. The
existing private-disclosure process (SECURITY.md) covers intake.

## 11. Documentation plan

Docs ship in the same PR as the feature (DOC-1). Milestone-level set:
M1 auth guide; M2 integration guides + regenerated API reference (OpenAPI
becomes canonical; `docs/api-reference.md` then points at it); M3
notification pipeline + system health explainer; M4 scheduling guide; M5
Slack/Telegram guides; M6 revised quickstart + deployment (fixing the
currently aspirational auto-migrate/backup text); M7 mobile build guide; M8
Twilio guide; M9 production operations set + threat model. The README's
scope section flips from "Phase 1 target" to shipped-capability language at
v0.9.

## 12. Release engineering

Already in place and reused as-is: release-please (version from PR titles;
`bump-minor-pre-major` gives v0.x minors), GoReleaser (multi-platform
archives incl. migrations), cosign keyless signing + SBOM + provenance,
GHCR images. Deltas this plan introduces: web-embed build stage (M6-06),
Playwright/e2e CI jobs (M6-07, pinned per repo policy), nightly load/soak
workflows (M9), coverage ratchet (M9-08), and the GA release PR
(`release-as: 1.0.0`, M9-09). Pre-1.0 breaking changes (e.g. removing
`JWT_SECRET`, schema v2) land before v0.9 and are called out in beta notes;
after v0.9, migrations are forward-only (OPS-2).

## 13. Beta program and rollout

- **v0.9.0 (post-M6):** public beta — chat + web + engine complete; mobile
  and telephony explicitly labelled in-progress. Ask beta users for: a
  quickstart timing, one week of real traffic, and their "why didn't it
  page?" reports (each becomes a failure-matrix row or a fix).
- **v0.9.x:** M7/M8 land behind flags; beta upgrade path exercised
  continuously (M9-07 rehearsal).
- **v1.0.0:** per PRD §9 gates only. No date-driven GA: a pager earns trust
  exactly once.

## 14. Risk register

| Risk | P | Impact | Mitigation |
|---|---|---|---|
| Schedule/DST correctness bug pages the wrong person | M | Critical (trust) | ADR-0006 single pure function; property + DST matrix from day one; beta soak on real schedules |
| Solo-maintainer review becomes the bottleneck | H | High (dates) | Small PRs; lanes independent; the staffing table is honest about it |
| Mobile BYO-Firebase setup friction stalls adoption | M | Medium | M7-11 clean-room-tested guide; `config check` dry-run; chat/email remain first-class without mobile |
| iOS Critical Alerts entitlement rarely granted to operators | H | Low–Med | Time-Sensitive + re-notify (M7-09) as the designed default, not a fallback afterthought |
| Slack Socket Mode limits (connections/reconnect churn) | L | Medium | Health surfacing (M5-01); documented signed-HTTP mode as the multi-replica path |
| PG-as-queue throughput ceiling | L | Medium | Targets sized to paging volume (PERF-1); claim-protocol benchmarks in M3; ADR-0001 exit noted |
| Scope creep re-inflates the draft PRD | M | High | PRD §8 non-goals; change control by PR; de-scope levers pre-agreed (§7) |
| Chat provider API drift breaks fixtures | M | Low | Recorded fixtures + a weekly canary workflow against real APIs post-beta |
| e2e/emulator flake erodes CI trust | M | Medium | e2e non-required initially; quarantine policy; nightly not PR-blocking |
| Security issue in public ingest pre-GA | L | Critical | §10 controls land with the feature, not after; M9-04 gate; private disclosure already set up |

## 15. Post-v1 (pointer)

PRD §10 lists v1.1 candidates and the Phase 2 (hosted) direction. Nothing in
v1 may foreclose them, nothing in v1 builds them.

---

## Appendix A — GitHub tracking

Create milestones `M0`–`M9` mirroring §6; one issue per task, titled by the
suggested PR title, labelled by lane (`backend`, `web`, `mobile`, `chatops`,
`infra`) plus `v1.0.0`. The failure-mode matrix rows become checklist items
on the relevant test-task issues. Progress reporting = milestone completion,
not percent-feeling.

## Appendix B — configuration surface to be introduced

Names only (each PR adds docs + `.env.example` per the checklist):
`SESSION_SECRET`-free by design (sessions are DB-backed; `JWT_SECRET` is
*removed* in M1-01); `PUBLIC_BASE_URL` (reuse existing `APP_BASE_URL`);
`SMTP_HOST/PORT/USERNAME/PASSWORD/FROM`; `OIDC_ISSUER/CLIENT_ID/
CLIENT_SECRET/ALLOW_SIGNUP`; `SLACK_APP_TOKEN` (Socket Mode; existing
bot-token/signing-secret vars stay); `TELEGRAM_WEBHOOK_SECRET` (optional
mode); `WEBHOOK_ALLOW_PRIVATE_TARGETS`; `INGEST_RATE_LIMIT_PER_MINUTE`;
`STORM_GUARD_OPEN_INCIDENTS`; `AUTO_MIGRATE`; `LOG_LEVEL`; `RETENTION_*`.
Existing variables (`DATABASE_URL`, `APP_PORT`, `APP_BASE_URL`, Slack/
Telegram/Twilio/Firebase credentials, `PAGERDUTY_ROUTING_KEY`) keep their
names and meanings.
