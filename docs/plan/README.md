# v1.0.0 planning documents

Living documents, changed by PR like code. Precedence when they disagree:
**PRD > implementation plan**; ADRs record the decisions both build on.

| Document | What it is |
|---|---|
| [prd-review.md](prd-review.md) | Evaluation of the original draft PRD: what was kept, changed, cut and added — with reasons. Read this to understand *why* v1 looks the way it does. |
| [prd-v1.md](prd-v1.md) | **Scope of record** for v1.0.0: numbered functional and non-functional requirements (MoSCoW-tagged), the event API contract, explicit non-goals, and the release criteria for tagging v1.0.0. |
| [implementation-plan.md](implementation-plan.md) | The build plan: current-state audit, target architecture, milestones M0–M9 as PR-sized tasks with acceptance criteria, failure-mode matrix, test/security strategy, staffing scenarios and risk register. |

Related ADRs: [0004 deduplication](../adr/0004-deterministic-deduplication.md),
[0005 jobs & outbox](../adr/0005-durable-jobs-and-notification-outbox.md),
[0006 schedules](../adr/0006-oncall-schedule-model.md),
[0007 auth](../adr/0007-authentication-and-sessions.md),
[0008 mobile push](../adr/0008-mobile-push-via-byo-firebase.md),
[0009 embedded web UI](../adr/0009-embed-web-ui-in-binary.md).

Working state (issues/milestones) lives in the GitHub tracker per the plan's
Appendix A; this directory is the plan of record.
