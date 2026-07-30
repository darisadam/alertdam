# Architecture Decision Records

Short documents recording *why* a significant decision was made, so the reasoning
survives the people who made it. Format: [MADR](https://adr.github.io/madr/).

A decision belongs here when reversing it would be expensive, when the obvious
alternative was rejected for a non-obvious reason, or when someone is likely to
ask "why on earth is it done this way?" a year from now.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-postgres-as-queue.md) | PostgreSQL as the notification queue | Accepted |
| [0002](0002-rename-to-alertdam.md) | Rename from PagerDam to AlertDam | Accepted |
| [0003](0003-review-policy-as-a-status-check.md) | Enforce the review policy as a status check, not a ruleset bypass | Accepted |
| [0004](0004-deterministic-deduplication.md) | Deduplicate on deterministic keys, and store alerts separately from incidents | Proposed |
| [0005](0005-durable-jobs-and-notification-outbox.md) | Run timers and deliveries as durable PostgreSQL jobs with an outbox | Proposed |
| [0006](0006-oncall-schedule-model.md) | Model on-call as layered rotations resolved by a pure function | Proposed |
| [0007](0007-authentication-and-sessions.md) | Authenticate with local accounts plus OIDC, using server-side sessions | Proposed |
| [0008](0008-mobile-push-via-byo-firebase.md) | Deliver mobile push through the operator's own Firebase project | Proposed |
| [0009](0009-embed-web-ui-in-binary.md) | Embed the built web dashboard in the Go binary | Proposed |

Start a new one by copying [`0000-template.md`](0000-template.md).
