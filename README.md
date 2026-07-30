<div align="center">
  <h1>🚨 PagerDam</h1>
  <p><strong>Open-source, developer-first incident management & on-call alerting platform.</strong></p>
  <p>The self-hosted alternative to PagerDuty and Grafana OnCall — built for ChatOps-first teams.</p>

  [![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
  [![Go Version](https://img.shields.io/badge/go-1.23+-00ADD8?logo=go)](https://golang.org/)
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
  [![GitHub Stars](https://img.shields.io/github/stars/darisadam/PagerDam?style=social)](https://github.com/darisadam/PagerDam/stargazers)
</div>

---

## ✨ Why PagerDam?

Modern engineering teams already live in Slack, Discord, and Telegram. PagerDam treats **chat as the primary control plane** — no context switching to another web UI during a 3 AM incident.

| Feature | PagerDam | PagerDuty | Grafana OnCall (OSS) |
|---|---|---|---|
| Self-hosted | ✅ | ❌ | ⚠️ Archived |
| ChatOps-first | ✅ | Partial | Partial |
| Single binary | ✅ | ❌ | ❌ |
| Zero Redis/MQ | ✅ | ❌ | ❌ |
| Free forever tier | ✅ | ❌ | ✅ (archived) |
| Mobile push (DND bypass) | ✅ | ✅ | ❌ |

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

---

## 🚀 Quick Start (Docker Compose)

The entire stack runs with two containers — the Go binary and PostgreSQL.

```bash
# 1. Clone the repository
git clone https://github.com/darisadam/PagerDam.git
cd PagerDam

# 2. Copy and configure environment variables
cp .env.example .env
# Edit .env with your Slack/Discord tokens, etc.

# 3. Start everything
docker compose up -d

# PagerDam is now running at http://localhost:8080
```

> **That's it.** No Kubernetes, no Redis, no message broker.

---

## 📋 Core Features

### 🔔 Alert Ingestion & Deduplication
- Generic webhook endpoint (`POST /v1/events`) compatible with Prometheus Alertmanager, Grafana, Datadog, and CloudWatch
- **Deduplication engine:** compresses hundreds of identical alerts into a single incident thread — no alert fatigue
- Regex-based routing rules to direct alerts to the right team/channel

### 📅 On-Call Scheduling
- Visual calendar UI with multi-timezone support
- Daily/weekly rotations, shift handoffs, and manual override layers
- Exports `.ics` feed (RFC 5545) — sync directly to Google Calendar, Apple Calendar, or Outlook

### 🔗 Escalation Policies
- Chain-based routing: e.g., Step 1: Slack → Step 2: Mobile Push (5 min) → Step 3: Voice Call (15 min)
- Fully configurable per-team and per-severity

### 💬 ChatOps Engine (The Differentiator)
- **Slack & Microsoft Teams:** Rich alert cards with `Acknowledge`, `Resolve`, `Escalate` action buttons
- **Discord & Telegram:** Thread-based incident grouping — ideal for OSS/startup teams on free plans
- **WhatsApp Business API:** Low-latency delivery for regions with expensive SMS
- **Automated war rooms:** Auto-create a Zoom bridge on P1 Critical alerts

### 📱 Mobile Application
- **iOS Critical Alerts:** Bypass Silent/Focus mode natively
- **Android DND bypass:** Uses full-volume notification channels
- **SIP/WebRTC client:** Receive VoIP voice calls directly in the app, bypassing carrier unreliability
- Rich push action buttons: Acknowledge without opening the app

### 🔒 Security & Auth
- OAuth 2.0, SAML 2.0, and OIDC — integrates with Okta, Google Workspace, Azure AD
- Bring Your Own Keys (BYOK) for Twilio and WhatsApp — 100% free via Discord/Telegram targets

---

## ⚙️ Configuration

All configuration is via environment variables. Copy `.env.example` to `.env` to get started.

| Variable | Description | Required |
|---|---|---|
| `DATABASE_URL` | PostgreSQL connection string | ✅ |
| `JWT_SECRET` | Secret for signing JWT tokens | ✅ |
| `SLACK_BOT_TOKEN` | Slack Bot OAuth token | For Slack |
| `DISCORD_BOT_TOKEN` | Discord bot token | For Discord |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | For Telegram |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID | For voice calls |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token | For voice calls |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging key | For mobile push |

See [`.env.example`](.env.example) for the full list.

---

## 📁 Repository Structure

```
PagerDam/
├── backend/          # Go backend engine (single binary)
├── web/              # React + Vite + Tailwind web dashboard
├── mobile/           # Flutter mobile app (iOS + Android)
├── docs/             # Documentation
├── deploy/           # Docker & Kubernetes manifests
├── .github/          # CI/CD workflows, issue & PR templates
├── docker-compose.yml
├── .env.example
└── Makefile
```

---

## 🗺️ Roadmap

| Phase | Status | Description |
|---|---|---|
| Phase 1: Open Source MVP | 🚧 In Progress | Self-hosted, ChatOps core, Docker deploy |
| Phase 2: Hosted Beta | 📅 Planned | Managed cloud — zero maintenance hosting |
| Phase 3: SaaS Enterprise | 📅 Planned | Built-in telephony, SOC2, advanced analytics |

---

## 🤝 Contributing

We welcome all contributions! Please read our [Contributing Guide](CONTRIBUTING.md) before opening a PR.

1. Fork the repository
2. Create your feature branch: `git checkout -b feat/my-feature`
3. Commit using [Conventional Commits](https://www.conventionalcommits.org/): `git commit -m "feat: add discord integration"`
4. Push and open a Pull Request against `main`

---

## 🔐 Security

Found a security vulnerability? Please **do not** open a public issue. See [SECURITY.md](SECURITY.md) for our responsible disclosure process.

---

## 📄 License

PagerDam is distributed under the **Apache License 2.0**. See [LICENSE](LICENSE) for full details.

> The Apache 2.0 license allows corporate environments to safely adopt and deploy PagerDam internally without copyleft (GPL) restrictions.

---

<div align="center">
  <sub>Built with ❤️ by <a href="https://github.com/darisadam">darisadam</a> and contributors.</sub>
</div>
