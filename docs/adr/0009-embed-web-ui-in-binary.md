# 0009. Embed the built web dashboard in the Go binary

- **Status:** Proposed
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

The deployment promise — repeated in the README, ADR-0001 and the compose file
— is *two containers: the Go binary and PostgreSQL*. Yet `docker-compose.yml`
has no container serving `web/`, and the scratch-based image contains only the
binary. As things stand the dashboard has no deployment story at all: a third
container or a manually configured reverse proxy would break the promise; not
shipping the dashboard breaks the product.

The same question applies to the plain-binary distribution (GoReleaser
archives): `alertdam` on a VM should serve its own UI without a webserver
install.

## Decision

1. **The production build of `web/` is embedded into the binary with
   `go:embed`** and served by the same chi router: `/v1/*` and
   `/metrics`/`/healthz`/`/readyz` are API routes; everything else serves
   static assets with an SPA fallback to `index.html`.
2. **Caching**: hashed assets (`assets/*-<hash>.js`) get
   `Cache-Control: immutable`; `index.html` gets `no-cache`. This is what
   makes upgrades take effect on refresh.
3. **Build order** becomes: `npm run build` → copy `web/dist` into the
   backend embed directory → `go build`. The Dockerfile gains a Node build
   stage; GoReleaser gains a before-hook; CI asserts the embed is never stale.
   A `dev` build tag keeps `go build` working without Node for backend-only
   contributors (serving a "UI not embedded in dev builds" placeholder), and
   `make dev-web` (Vite with a proxy to :8080) stays the frontend dev loop.
4. The SPA is served from the **same origin** as the API, so the session
   cookie is first-party, CORS is unnecessary, and `SameSite=Lax` does its
   job (ADR-0007).

## Consequences

### Positive

- The two-container promise and the single-binary promise both become true —
  `docker compose up` yields a working dashboard at `:8080`, and so does the
  bare binary on a VM.
- Same-origin removes the CORS/cookie/third-party-cookie class of bugs
  entirely.
- Version skew between UI and API is impossible; they ship as one artifact.

### Negative

- Binary grows by the size of the SPA build (single-digit MB compressed —
  irrelevant next to the ~20 MB image, but it is no longer "just Go").
- Every release build now needs Node; backend-only local builds do not
  (the `dev` tag), but CI and GoReleaser pipelines get a second toolchain.
- UI-only fixes require a backend release. Acceptable: release cadence is
  cheap here (release-please + GoReleaser are already automated).

### Neutral

- A reverse proxy in front remains fully supported (TLS termination is
  documented that way); it is just no longer *required* for the UI.

## Alternatives considered

**Third container (nginx serving the SPA).** Rejected: breaks the
two-container contract that is this product's positioning, adds CORS or proxy
config, and adds an image to version-match with the API.

**CDN / separately hosted SPA.** Rejected: contradicts self-hosted and
air-gapped deployments — many target networks have no egress.

**Server-rendered UI in Go templates.** Rejected: the dashboard (calendar,
policy editor) is interactive enough that this fights the requirement, and the
React scaffolding already exists.
