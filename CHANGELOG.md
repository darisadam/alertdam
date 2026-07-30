# Changelog

All notable changes to PagerDam will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Initial repository scaffold with monorepo structure
- `backend/` — Go backend engine (single binary)
- `web/` — React + Vite + Tailwind CSS web dashboard
- `mobile/` — Flutter mobile app (iOS + Android)
- `docs/` — Architecture and integration documentation
- `deploy/` — Docker and Kubernetes deployment manifests
- `docker-compose.yml` — Two-container local development stack (Go + PostgreSQL)
- `.github/` — Issue templates, PR template, Dependabot configuration
- `.env.example` — Full environment variable reference
- `.gitleaks.toml` — Secret scanning configuration
- `Makefile` — Developer convenience targets
- `CONTRIBUTING.md` — Contribution guide with Conventional Commits conventions
- `SECURITY.md` — Responsible disclosure policy
- Branch protection rules on `main`
- Tag protection ruleset (`Protect Tags`)
- Dependabot alerts and security updates enabled
- Secret scanning and push protection enabled

---

## [0.1.0] — TBD (Phase 1 MVP)

> Phase 1: Open-Source MVP — self-hosted, ChatOps-core, Docker deploy

### Planned
- Go backend with `/v1/events` webhook ingestion endpoint
- Prometheus Alertmanager / Grafana / Datadog payload support
- Alert deduplication engine
- Basic on-call schedule management
- Slack integration with Acknowledge/Resolve action buttons
- Discord bot with thread-based incident grouping
- Telegram bot integration
- Escalation policy engine (multi-step chain)
- Web dashboard — Incident feed and schedule calendar
- Flutter mobile app — FCM / APNs push with DND bypass
- PostgreSQL-based queue using `LISTEN/NOTIFY`
- iCalendar (RFC 5545) feed export for on-call schedules
- Docker Compose single-command deploy

---

[Unreleased]: https://github.com/darisadam/PagerDam/compare/HEAD...HEAD
