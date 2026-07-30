# 0002. Rename the project from PagerDam to AlertDam

- **Status:** Accepted
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

The project was originally named **PagerDam** — "Dam" from the maintainer's own
name, Adam Daris Ryadhi. In the incident-management category, however, "Pager…"
reads as a deliberate echo of an established commercial product, and a
suggestive name in the same market and the same Nice class is the kind of thing
that attracts a letter regardless of intent.

The cost of renaming rises steeply over time. At the point of this decision the
project had: no release, no tag, no published Go module (so nothing in the module
proxy), no container image, no dependents, and one merged pull request. That is
the cheapest this will ever be.

A related and larger exposure was found during the rename. The README asserted
specific claims about a competitor's pricing and capabilities in a comparison
table, some of which were unverified and at least one of which was likely false.
False or misleading factual statements about a competitor are Lanham Act §43(a)
false-advertising territory — materially more actionable than a suggestive name.

## Decision

Rename to **AlertDam**, and remove competitor comparisons entirely.

Naming specifics:

- Repository slug is lowercase **`alertdam`**, not `AlertDam`. Go module paths are
  case-sensitive and the module proxy escapes capitals, so
  `github.com/darisadam/AlertDam` would be cached as `!alert!dam`. Docker
  repository names and npm package names must be lowercase regardless. "AlertDam"
  remains the display name in prose and UI.
- Brand names were removed from infrastructure identifiers rather than renamed:
  the Compose `container_name` keys were deleted and the network became
  `internal`. A brand name in a container name bought nothing and cost a
  migration — the generalisable lesson from this rename.
- `PAGERDUTY_ROUTING_KEY` in `.env.example` was left untouched. It names a real
  third-party integration, not this project.
- Git history was not rewritten. A dated, documented rename with a working
  redirect is better evidence of good faith than a scrubbed history.

## Consequences

### Positive

- Removes the closest-adjacent naming risk before the project has visibility.
- Removes the false-advertising exposure, which was the larger of the two.
- `alertdam` was free everywhere checked: no GitHub repository, npm package, or
  Docker Hub namespace, and no software project by that name in search.
- Forced a review of infrastructure naming that was worth doing anyway.

### Negative

- Loses discoverability from "alternative to X" search traffic. Judged worth it.
- Renaming a repository **frees the old name**. If anyone ever creates
  `darisadam/PagerDam`, the redirect dies permanently. Never recreate it.
- Git history retains the old name forever, so this is forward-looking mitigation
  rather than erasure.
- Third-party names still appear where integrations require them (env var names,
  webhook paths). That is nominative use for identification, covered by
  `TRADEMARKS.md`.

### Neutral

- GitHub redirects old web, API and git-remote URLs indefinitely, so nothing broke
  at the moment of the rename.

## Alternatives considered

**Keep the name.** Zero work, unbounded downside. The whole point of acting now is
that the cost only grows.

**Keep the comparison table with a dated sourcing footnote.** Naming a competitor
to describe your own product is nominative fair use and is standard practice in
OSS. Rejected in favour of the more conservative option, at the maintainer's
explicit direction — and it removed the need to fact-check and maintain claims
about someone else's product, which was itself an ongoing liability.

**A completely unrelated name.** Would have discarded the personal provenance of
"Dam", which is a genuine good-faith story worth keeping.

## Follow-up

A formal clearance search (USPTO TESS, EUIPO eSearch, WIPO Global Brand Database)
is still outstanding and should be done before "AlertDam" goes on a logo, a
website or a paid offering. Note the semantic adjacency to dam-safety and
water-level monitoring products — a real niche, but a different Nice class, so
coexistence is normally fine. Nothing in this ADR is legal advice.
