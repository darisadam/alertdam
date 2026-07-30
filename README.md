<div align="center">
  <img src="docs/assets/logo.svg" alt="" width="88" height="88">
  <h1>AlertDam</h1>
  <p><strong>Open-source, developer-first incident management & on-call alerting platform.</strong></p>
  <p>Self-hosted, ChatOps-first incident response for engineering teams — a single Go binary and PostgreSQL.</p>

  [![CI](https://github.com/darisadam/alertdam/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/darisadam/alertdam/actions/workflows/ci.yml)
  [![CodeQL](https://github.com/darisadam/alertdam/actions/workflows/codeql.yml/badge.svg?branch=main)](https://github.com/darisadam/alertdam/actions/workflows/codeql.yml)
  [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/darisadam/alertdam/badge)](https://scorecard.dev/viewer/?uri=github.com/darisadam/alertdam)
  [![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
  [![Go Version](https://img.shields.io/github/go-mod/go-version/darisadam/alertdam?filename=backend%2Fgo.mod&logo=go)](backend/go.mod)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
</div>

---

> [!WARNING]
> **Project status: pre-alpha.** The repository layout, database schema and API surface are in place, but the backend handlers are still stubs — most endpoints return `501 Not Implemented`. Nothing here is ready to page a human yet. Follow the [roadmap](#️-roadmap), or [start a discussion](https://github.com/darisadam/alertdam/discussions) if you want to help build it.

---

## ✨ Why AlertDam?

Modern engineering teams already live in Slack, Discord, and Telegram. AlertDam treats **chat as the primary control plane** — no context switching to another web UI during a 3 AM incident.

Three design commitments shape everything else:

| Commitment | What it means in practice |
|---|---|
| **Operational minimalism** | One compiled Go binary plus PostgreSQL. No Redis, no RabbitMQ, no Kafka, no Kubernetes required. |
| **ChatOps first** | Acknowledge, resolve and escalate from the chat client you already have open. The web dashboard is for configuration and history, not for firefighting. |
| **Self-hosted by default** | Your alert data, escalation policies and phone numbers stay on infrastructure you control. Bring your own Twilio/WhatsApp keys, or stay entirely free using Discord and Telegram as delivery targets. |

---

## 🏗️ Architecture

```
[Prometheus / Grafana / Datadog / Webhook]
              │
              ▼
  ┌─────────────────────┐
  │  Go Backend Engine  │  ◄──► PostgreSQL (queue + store)
  │  (single binary)    │
  └──────────┬──────────┘
             │
   ┌─────────┼──────────────┐
   ▼         ▼              ▼
[Web UI]  [Mobile App]  [Chat Integrations]
(React)   (Flutter)     Slack / Discord / Telegram
                        Twilio Voice / WhatsApp
```

**Stack:**
- **Backend:** Go — single compiled binary, zero runtime dependencies
- **Database:** PostgreSQL — uses `LISTEN/NOTIFY` + row-locking for native queuing (no Redis/RabbitMQ)
- **Web:** React 19 + Vite + Tailwind CSS
- **Mobile:** Flutter (iOS + Android) with native Critical Alerts & DND bypass

See [`docs/architecture.md`](docs/architecture.md) for the reasoning behind the PostgreSQL-as-queue design.

---

## 🚀 Quick Start (Docker Compose)

The entire stack runs with two containers — the Go binary and PostgreSQL.

```bash
# 1. Clone the repository
git clone https://github.com/darisadam/alertdam.git
cd alertdam

# 2. Copy and configure environment variables
cp .env.example .env
# Edit .env — JWT_SECRET is required and deliberately has no default

# 3. Start everything
docker compose up -d

# AlertDam is now running at http://localhost:8080
curl -fsS http://localhost:8080/health
```

> **That's it.** No Kubernetes, no Redis, no message broker.

---

## 📋 Scope

The capabilities below are the Phase 1 target, not a description of what ships today — see the status warning above. Track progress in [issues](https://github.com/darisadam/alertdam/issues).

### 🔔 Alert Ingestion & Deduplication
- Generic webhook endpoint (`POST /v1/events`) compatible with Prometheus Alertmanager, Grafana, Datadog, and CloudWatch
- **Deduplication engine:** compresses hundreds of identical alerts into a single incident thread — no alert fatigue
- Regex-based routing rules to direct alerts to the right team/channel

### 📅 On-Call Scheduling
- Visual calendar UI with multi-timezone support
- Daily/weekly rotations, shift handoffs, and manual override layers
- Exports `.ics` feed (RFC 5545) — sync directly to Google Calendar, Apple Calendar, or Outlook

### 🔗 Escalation Policies
- Chain-based routing: e.g. Step 1: Slack → Step 2: Mobile Push (5 min) → Step 3: Voice Call (15 min)
- Fully configurable per-team and per-severity

### 💬 ChatOps Engine (the differentiator)
- **Slack & Microsoft Teams:** rich alert cards with `Acknowledge`, `Resolve`, `Escalate` action buttons
- **Discord & Telegram:** thread-based incident grouping — ideal for OSS and startup teams on free plans
- **WhatsApp Business API:** low-latency delivery for regions where SMS is expensive
- **Automated war rooms:** auto-create a conference bridge on P1 critical alerts

### 📱 Mobile Application
- **iOS Critical Alerts:** bypass Silent/Focus mode natively
- **Android DND bypass:** full-volume notification channels
- **SIP/WebRTC client:** receive VoIP voice calls in-app, bypassing carrier unreliability
- Rich push action buttons: acknowledge without opening the app

### 🔒 Security & Auth
- OAuth 2.0, SAML 2.0 and OIDC — integrates with common enterprise identity providers
- Bring Your Own Keys (BYOK) for Twilio and WhatsApp; entirely free via Discord/Telegram targets

---

## ⚙️ Configuration

All configuration is via environment variables. Copy `.env.example` to `.env` to get started.

| Variable | Description | Required |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | ✅ |
| `JWT_SECRET` | Secret for signing JWT tokens (64+ characters) | ✅ |
| `SLACK_BOT_TOKEN` | Slack bot OAuth token | For Slack |
| `DISCORD_BOT_TOKEN` | Discord bot token | For Discord |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | For Telegram |
| `TWILIO_ACCOUNT_SID` | Twilio account SID | For voice calls |
| `TWILIO_AUTH_TOKEN` | Twilio auth token | For voice calls |
| `FIREBASE_PROJECT_ID` | Firebase project for FCM push | For mobile push |

See [`.env.example`](.env.example) for the full list.

---

## 📁 Repository Structure

```
alertdam/
├── backend/          # Go backend engine (single binary)
├── web/              # React + Vite + Tailwind web dashboard
├── mobile/           # Flutter mobile app (iOS + Android)
├── docs/             # Documentation, ADRs, brand assets
├── deploy/           # Docker & Kubernetes manifests
├── scripts/          # Convention validators, shared by git hooks and CI
├── .github/          # CI/CD workflows, issue & PR templates, Dependabot config
├── docker-compose.yml
├── lefthook.yml      # Git hooks
├── .env.example
└── Makefile
```

Repository and CI configuration — branch rules, required checks, the review
policy — is documented in [`docs/repo-configuration.md`](docs/repo-configuration.md).

---

## 🗺️ Roadmap

| Phase | Status | Description |
|---|---|---|
| Phase 1: Open Source MVP | 🚧 In Progress | Self-hosted, ChatOps core, Docker deploy |
| Phase 2: Hosted Beta | 📅 Planned | Managed cloud — zero maintenance hosting |
| Phase 3: SaaS Enterprise | 📅 Planned | Built-in telephony, advanced analytics |

---

## 🤝 Contributing

Contributions are very welcome. Please read the [Contributing Guide](CONTRIBUTING.md) before opening a PR.

1. Fork the repository
2. Create your branch: `git switch -c feat/my-feature`
3. Commit using [Conventional Commits](https://www.conventionalcommits.org/): `git commit -m "feat: add discord integration"`
4. Push and open a pull request against `main`

Branch names, commit messages and PR titles are checked automatically. Run the same checks locally with `make setup` (installs git hooks) and `make verify`.

---

## 🔐 Security

Found a security vulnerability? Please **do not** open a public issue — [report it privately](https://github.com/darisadam/alertdam/security/advisories/new). See [SECURITY.md](SECURITY.md) for the full disclosure process.

---

## 📄 License

AlertDam is distributed under the **Apache License 2.0**. See [LICENSE](LICENSE) for full details.

> Apache 2.0 lets corporate environments adopt and deploy AlertDam internally without copyleft (GPL) restrictions.

---

## ™️ Trademarks

AlertDam is an independent open-source project. It is not affiliated with, endorsed by, or sponsored by any of the third-party services it integrates with. All product names, logos and brands referenced here are the property of their respective owners and are used solely for identification. See [TRADEMARKS.md](TRADEMARKS.md).

> Formerly named *PagerDam*; renamed to AlertDam in July 2026. Old repository URLs redirect here.

---

<div align="center">
  <sub>Built with ❤️ by <a href="https://github.com/darisadam">darisadam</a> and contributors.</sub>
</div>
