# Changelog

All notable changes to AlertDam will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> This file records changes to the **software**. Repository and GitHub
> configuration (branch rulesets, required checks, secret scanning, Dependabot)
> is documented in [`docs/repo-configuration.md`](docs/repo-configuration.md).

---

## [Unreleased]

### Changed

- **BREAKING: the project has been renamed from PagerDam to AlertDam.** Every
  identifier moved in one commit:
  - Go module path: `github.com/darisadam/pagerdam` → `github.com/darisadam/alertdam`
  - Command package: `backend/cmd/pagerdam` → `backend/cmd/alertdam`
  - Binary and local Docker image: `pagerdam` → `alertdam`
  - npm package: `pagerdam-web` → `alertdam-web`
  - Dart package: `pagerdam_mobile` → `alertdam_mobile`; root widget `PagerDamApp` → `AlertDamApp`
  - Compose: project name pinned to `alertdam`, service `pagerdam` → `app`,
    network `pagerdam-net` → `internal`, both `container_name` keys removed
  - PostgreSQL default role / password / database: `pagerdam` → `alertdam`
  - APNs bundle id: `com.yourapp.pagerdam` → `com.alertdam.mobile`
  - Gitleaks rule id: `pagerdam-jwt-secret` → `alertdam-jwt-secret`

  **Migration.** The GitHub repository was renamed, so old URLs and existing git
  remotes redirect automatically; run `git remote set-url origin
  https://github.com/darisadam/alertdam.git` anyway so the redirect stops being
  load-bearing. `POSTGRES_USER`/`POSTGRES_DB` are honoured only when PostgreSQL
  initialises an empty data directory, so an existing dev volume keeps the old
  `pagerdam` role: either run `docker compose down -v` to start clean, or set
  `POSTGRES_USER=pagerdam` and `POSTGRES_DB=pagerdam` in your `.env`. No
  released version existed, so there is no upgrade path to support.

- README no longer positions AlertDam against named competitors; capabilities are
  described on their own terms, and a pre-alpha status warning was added because
  most API handlers still return `501`.

### Added

- `NOTICE` — Apache-2.0 §4(d) attribution notice.
- `TRADEMARKS.md` — trademark policy and third-party mark attributions.

### Fixed

- `deploy/docker/Dockerfile` now cross-compiles via `$BUILDPLATFORM` +
  `$TARGETARCH` instead of hardcoding `GOARCH=amd64`, so multi-arch builds do
  not need QEMU emulation. Version metadata is passed in via `--build-arg`
  rather than `git describe`, which always resolved to `dev` because the build
  context excludes `.git`. The image now runs as uid 65532 instead of root.
- `main.go` declares the `version`, `commit` and `date` variables that
  `-ldflags -X` targets. The linker silently ignores `-X` for symbols that do
  not exist, so version stamping had never worked.
- `docker-compose.yml` no longer bind-mounts `./service-account.json`
  unconditionally — the file is gitignored and absent, so Docker created a
  *directory* in its place. It moved behind an opt-in `fcm` profile.
- Removed the `app` container healthcheck: it shelled out to `wget` inside a
  `scratch` image with no shell and no wget, so the container could never
  become healthy and `depends_on: service_healthy` would block forever.
- `JWT_SECRET` now fails the Compose stack loudly when unset instead of
  starting the app with an empty signing secret.
- PostgreSQL's host port binding is now `127.0.0.1:5432` rather than all
  interfaces.

---

## [0.1.0] — TBD (Phase 1 MVP)

> Phase 1: Open-Source MVP — self-hosted, ChatOps core, Docker deploy

### Planned
- Go backend with `/v1/events` webhook ingestion endpoint
- Prometheus Alertmanager / Grafana / Datadog payload support
- Alert deduplication engine
- Basic on-call schedule management
- Slack integration with Acknowledge/Resolve action buttons
- Discord bot with thread-based incident grouping
- Telegram bot integration
- Escalation policy engine (multi-step chain)
- Web dashboard — incident feed and schedule calendar
- Flutter mobile app — FCM / APNs push with DND bypass
- PostgreSQL-based queue using `LISTEN/NOTIFY`
- iCalendar (RFC 5545) feed export for on-call schedules
- Docker Compose single-command deploy

---

[Unreleased]: https://github.com/darisadam/alertdam/compare/29ee01b...HEAD
