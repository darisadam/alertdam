# 0007. Authenticate with local accounts plus OIDC, using server-side sessions

- **Status:** Proposed
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

The draft PRD lists "OAuth 2.0, SAML 2.0 (SSO), and OIDC". That is three
protocol surfaces before the product has one working login. The deployment
reality is a self-hosted tool operated by a DevOps team: it must work with no
identity provider at all (a 5-person team with a `.env` file) and with the
common self-hosted/corporate IdPs (Keycloak, Authentik, Google, Okta,
Microsoft Entra) — all of which speak OIDC.

There are four distinct credential kinds to design, not one:

1. Humans in a browser (the dashboard).
2. Automation calling the API (scripts, terraform, CLIs).
3. Monitoring tools posting events (Alertmanager cannot do OAuth dances).
4. Mobile devices that must stay signed in for months and call the API from
   notification action handlers.

The current scaffolding is ambiguous: the schema has a `user_sessions` table
with `token_hash` (server-side sessions), while the environment requires a
`JWT_SECRET` (stateless tokens). Both cannot be the design.

## Decision

1. **Humans**: local accounts (argon2id password hashes, admin-issued invites,
   email password reset) **plus OIDC** (authorization code + PKCE, discovery
   document, optional just-in-time provisioning behind an allowlist flag).
   SAML is explicitly out of scope for v1.
2. **Browser sessions are server-side and opaque**: a random 256-bit token in
   an `HttpOnly`, `SameSite=Lax`, `Secure` cookie, stored hashed in
   `user_sessions`, absolute and idle expiry, revocable individually and in
   bulk ("sign out everywhere"). State-changing routes require a CSRF token on
   top of the cookie. **JWTs are not used**; `JWT_SECRET` is removed from the
   configuration surface before the first tagged release.
3. **Automation**: personal access tokens (`ad_`-prefixed, random, shown once,
   stored hashed) with coarse scopes (`read`, `write`) and a recorded
   last-used timestamp.
4. **Event ingestion**: per-integration routing keys (random, stored hashed,
   rotatable) — never user credentials. A leaked routing key can create noise
   on one service; it cannot read anything.
5. **Mobile devices**: a device token minted through a QR/one-time-code
   pairing flow from an authenticated dashboard session; same power as a
   scoped PAT, listed and revocable per device.
6. **Authorization**: two roles in v1 — `admin` (mutates configuration,
   users, integrations) and `member` (full responder: sees everything, acks,
   resolves, escalates, edits own profile/rules). The route×role matrix is a
   table in code with a golden test, not ad-hoc checks in handlers.

## Consequences

### Positive

- Zero-IdP deployments work out of the box; IdP deployments get SSO with one
  well-trodden protocol.
- Every credential is revocable server-side the moment it leaks — the property
  stateless JWTs give up.
- Each caller class gets the narrowest credential that works; routing keys in
  monitoring configs are not API tokens.

### Negative

- Session lookup touches PostgreSQL on every request. At this product's
  request rates that is noise; if it ever matters, an in-process cache with
  short TTL bounds it without changing the model.
- No SAML means some large enterprises need an OIDC bridge (most IdPs that
  speak SAML also speak OIDC; Keycloak brokers the rest). Accepted for v1.
- Two roles will not satisfy everyone (read-only stakeholder role is a known
  request). Deferred, not refused.

### Neutral

- Removing `JWT_SECRET` is a config-surface break. It happens before v0.9 (the
  first tagged beta), where breaking changes are still free.

## Alternatives considered

**Stateless JWTs everywhere (the scaffolding's implied design).** Rejected:
revocation requires a denylist (state again), key rotation invalidates the
world, and the failure mode of a leaked signing secret is total. The product
stores its state in PostgreSQL either way; sessions are cheap rows.

**SAML in v1.** Rejected: large protocol surface, painful XML security
history, and the target v1 audience overwhelmingly has an OIDC path.

**Sessions in signed cookies only (no server row).** Rejected: no revocation,
no device list, no "sign out everywhere" — all of which a paging tool used
from personal phones needs.

**Basic auth for ingestion.** Rejected in favour of routing keys in the body
(PagerDuty-compatible) plus an `Authorization: Bearer <routing key>` /
query-parameter option for tools that cannot template bodies; either way the
credential is the integration's, not a person's.
