# Review of the draft PRD

This document evaluates the draft PRD (the "PagerDam" document targeting a
Q3 2026 launch) against one question: **what does it take to ship a v1.0.0
that engineers can trust with their pager?** Its output is the revised
[v1.0.0 PRD](prd-v1.md), the [implementation plan](implementation-plan.md),
and ADRs [0004](../adr/0004-deterministic-deduplication.md)–[0009](../adr/0009-embed-web-ui-in-binary.md).

The one-line verdict: the draft's architecture instincts are right and are
kept; its scope is 2–3 products wide and is cut to one; and it is silent on
the reliability semantics that make a pager trustworthy, which the revision
treats as the core of v1.

---

## What the draft gets right (kept, unchanged)

- **Single Go binary + PostgreSQL, nothing else.** Already ratified as
  ADR-0001 and reinforced by the two-container compose contract. This is the
  product's sharpest differentiator for self-hosters.
- **Chat as the control plane**, web as configuration/history. Correct read
  of how incidents are actually handled.
- **PagerDuty Events API v2-compatible wire format** for `POST /v1/events`.
  Every monitoring tool on earth already knows how to speak it; keeping wire
  compatibility buys an integration ecosystem for free.
- **RFC 5545 ICS feeds** for schedules — cheap, high-value, no lock-in.
- **BYOK for anything that costs money** (Twilio, SMTP), free operation via
  chat channels.
- **Apache-2.0**, no copyleft dependencies.
- **Deliberately minimal web dashboard.**

## Reality checks and decisions

Each finding below states the problem and the decision taken in the revised
PRD. The disposition table at the end summarises everything.

### 1. The timeline is not real

The draft targets "Q3 2026" — which is *now*, while every backend handler
returns a stub and `mobile/` cannot even run `flutter build`. Shipping a
pager prematurely is worse than shipping late: the first lost page costs the
project its reputation permanently.

**Decision:** re-baseline. The implementation plan (§7) estimates ~39
engineer-weeks of scoped work: with 2–3 engineers, a public beta (v0.9,
chat + web + core engine) lands in **November 2026** and v1.0.0 GA in
**January–February 2027**. Solo, roughly double. Dates move with staffing;
the milestone order does not.

### 2. "Regex-based deduplication router" is the wrong primitive

Dedup decides whether a human gets paged. Regex rules make that decision
depend on rule ordering and payload phrasing, are unexplainable at 3 AM, and
evaluate operator-authored patterns against attacker-influenced input on the
hot path.

**Decision (ADR-0004):** deduplication is exact-match on deterministic keys
(`dedup_key`, Alertmanager fingerprint, or a derived hash). Label-matching
routing *rules* — a good feature — move to post-1.0 and will route and
annotate, never define identity.

### 3. Five chat platforms is five products

Slack, Teams, Discord, Telegram and WhatsApp each mean a distinct auth model,
message format, interactivity callback protocol, rate-limit regime and test
harness. Shipping all five shallowly guarantees five mediocre integrations.

**Decision:** v1 ships **Slack and Telegram deep** (cards, buttons, threads,
account linking, commands) behind one channel-adapter interface, plus email
and signed outbound webhooks as universal fallbacks. Discord follows in v1.1
(its interactions endpoint is a bounded add); Teams when demand shows;
WhatsApp is dropped from the roadmap for now — the Business API requires
approval, template messages and per-message pricing, so it is neither
low-latency nor free in practice, and Telegram already covers the "SMS is
expensive here" audience at zero cost.

Slack integration defaults to **Socket Mode** and Telegram to long-polling —
so a v1 deployment needs *no public inbound URL at all* unless Twilio DTMF
callbacks are enabled. For self-hosters behind NAT this is a major
simplification the draft missed.

### 4. SIP/WebRTC in-app calling is a product in itself

A softphone plus STUN/TURN infrastructure, CallKit/PushKit entanglements on
iOS, and carrier-grade reliability expectations — to *replace* a channel
(carrier voice via Twilio) that is more reliable than self-hosted VoIP will
ever be.

**Decision: cut.** Twilio voice with DTMF acknowledgement is the
wake-someone-up channel. Revisit only with post-1.0 evidence of demand.

### 5. Automated war rooms are premature

Auto-creating Zoom bridges couples the core loop to a paid third-party API
and another OAuth surface for a convenience feature.

**Decision: defer.** v1's signed outbound webhooks let teams automate this
themselves; a native "create Slack channel per incident" action is a v1.1
candidate.

### 6. Fully self-hosted store-published mobile push is physically impossible

FCM/APNs deliver only to builds signed with the app publisher's credentials.
An official store app therefore requires a project-operated push relay — a
piece of hosted infrastructure other people's pagers would depend on, which
this project cannot responsibly run yet. The draft also promises iOS Critical
Alerts, which require a per-app entitlement Apple grants case by case.

**Decision (ADR-0008):** v1 mobile apps are **operator-built against the
operator's own free Firebase project** (BYOK, consistent with the rest of the
product); the backend sends via the FCM v1 API only. iOS defaults to
Time-Sensitive with server-driven re-notification; Critical Alerts activate
when the operator's app ID has the entitlement. Store apps + a hosted relay
are the Phase 2 (hosted offering) deliverable.

### 7. The draft omits table stakes for a self-hosted pager

Missing entirely, added as Must/Should requirements in the revised PRD:

- **SMTP email** — the universal channel, and required anyway for invites and
  password resets.
- **Heartbeat (dead-man's-switch) monitoring** — "alert me when Prometheus
  stops talking" is the first thing an SRE wires up (Watchdog pattern).
- **Maintenance windows** — planned-work suppression, with un-suppression of
  still-firing incidents when the window closes.
- **Per-user notification rules** separate from escalation policies (the
  policy decides *who*; the person decides *how they personally* get paged).
  The draft conflates the two inside policy steps.
- **A delivery audit trail** — every notification attempt with its outcome,
  queryable in the UI. "Prove it paged" is the trust feature.
- **Self-observability** — Prometheus `/metrics`, health/readiness endpoints,
  a monitor-the-monitor guide. A pager that cannot itself be monitored fails
  the audience.
- **Dead-letter surfacing** — a notification that exhausts retries must be
  loudly visible, never silently dropped.
- **Operational story** — documented backup/restore, upgrade, retention/prune
  tooling, and a `migrate` subcommand instead of "apply SQL with psql".

### 8. AuthN scope: SAML is enterprise-checklist territory

**Decision (ADR-0007):** local accounts (argon2id) + OIDC in v1 — that covers
Keycloak, Authentik, Google, Okta and Entra, i.e. the actual v1 audience.
Server-side revocable sessions instead of JWTs (the `JWT_SECRET` env var goes
away before the first beta). SAML deferred.

### 9. No quantified reliability or performance requirements

"High-reliability" appears as an adjective, not a number, in the draft.

**Decision:** the revised PRD §6 defines measurable NFRs — ingest latency and
sustained rate on a named reference box, end-to-end page latency, escalation
timer drift, crash-resume and duplicate-delivery budgets, 24-hour soak
invariants — and the implementation plan carries a failure-mode matrix where
every row names the test that proves the behaviour.

### 10. Smaller corrections

- **"Flutter or React Native"** → Flutter. Already scaffolded in `mobile/`
  with Riverpod/Dio/go_router committed; revisiting would be churn.
- **Datadog/CloudWatch "native support"** → Alertmanager and Grafana mappers
  are Must (the self-hosted mainstream); Datadog is a stretch goal; CloudWatch
  (SNS subscription confirmation etc.) moves to v1.1. All of them can reach
  v1 today through the generic events endpoint.
- **Naming** — the product is AlertDam (ADR-0002); the draft predates the
  rename. Third-party names remain nominative-use only (TRADEMARKS.md), and
  competitor capability/pricing claims stay removed from all public docs.
- **The SaaS roadmap** (Phases 2–3) is kept as direction but explicitly out
  of v1 scope; the only accommodation v1 makes is avoiding design choices that
  would foreclose it (see plan §4 "guardrails").

## Disposition table: draft → v1.0.0

| Draft item | Disposition | Where |
|---|---|---|
| Go single binary + PostgreSQL queue | **Keep** | ADR-0001, plan §3 |
| Two-container docker-compose deploy | **Keep** (made true by embedding the SPA) | ADR-0009 |
| `POST /v1/events` PD-compatible schema | **Keep**, contract tightened | PRD §5.2, §7 |
| Severity vocabulary CRITICAL/HIGH/WARNING/INFO | **Keep** (already in code) | PRD §5.4 |
| Regex deduplication router | **Change** → deterministic keys | ADR-0004 |
| Regex routing rules | **Defer** to v1.1 (route/annotate only) | PRD §8 |
| Slack bidirectional | **Keep** (Socket Mode default) | PRD §5.8 |
| Telegram bot | **Keep** (long-poll default) | PRD §5.8 |
| Discord bot | **Defer** full bot to v1.1; outbound-only webhook is a v1 Could | PRD §5.8 |
| Microsoft Teams | **Defer** (post-1.0, demand-driven) | PRD §8 |
| WhatsApp Business API | **Drop** from roadmap (approval + pricing defeat the stated purpose) | §3 above |
| Automated war rooms (Zoom) | **Defer**; outbound webhooks enable DIY | PRD §8 |
| Runbook automation (execute scripts) | **Change** → signed outbound webhooks only (no remote exec) | PRD §5.8 |
| On-call schedules, layers, overrides | **Keep**, semantics pinned | ADR-0006 |
| ICS feed (RFC 5545) | **Keep** | PRD §5.7 |
| Escalation policy chains | **Keep**, semantics pinned (ack-stop, repeat, ack-timeout) | PRD §5.5 |
| Mobile apps (Flutter) | **Keep**; BYO Firebase build, not store apps | ADR-0008 |
| iOS Critical Alerts | **Keep honestly**: Time-Sensitive default, Critical when entitled | ADR-0008 |
| SIP/WebRTC in-app calls | **Cut** | §4 above |
| Twilio voice + SMS (BYOK) | **Keep** (feature-flagged by credentials) | PRD §5.8 |
| OAuth2/SAML/OIDC | **Change** → local + OIDC; SAML deferred | ADR-0007 |
| Web dashboard (config hub) | **Keep**, screen inventory defined | PRD §5.9 |
| "Q3 2026" launch | **Re-baseline** → beta Nov 2026, GA Jan–Feb 2027 (2–3 eng) | plan §7 |
| SaaS Phases 2–3 | **Keep as direction**, out of v1 scope | PRD §8 |
| Email channel | **Add** (Must) | PRD §5.8 |
| Heartbeat monitoring | **Add** (Must) | PRD §5.6 |
| Maintenance windows | **Add** (Must) | PRD §5.6 |
| Per-user notification rules | **Add** (Must) | PRD §5.5 |
| Delivery audit trail + DLQ surfacing | **Add** (Must) | ADR-0005, PRD §5.8 |
| Prometheus metrics / health endpoints | **Add** (Must) | PRD §5.11 |
| Backup/upgrade/prune/migrate tooling | **Add** (Must) | PRD §5.11 |
| Quantified NFRs + failure-mode matrix | **Add** | PRD §6, plan §8 |
