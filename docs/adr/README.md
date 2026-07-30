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

Start a new one by copying [`0000-template.md`](0000-template.md).
