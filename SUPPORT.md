# Getting help

## Where to go

| What you have | Where it goes |
|---|---|
| A usage or configuration question | [Discussions → Q&A](https://github.com/darisadam/alertdam/discussions/categories/q-a) |
| An idea that is not yet a concrete proposal | [Discussions → Ideas](https://github.com/darisadam/alertdam/discussions/categories/ideas) |
| A reproducible defect | [Open a bug report](https://github.com/darisadam/alertdam/issues/new?template=bug_report.yml) |
| A specific feature proposal | [Open a feature request](https://github.com/darisadam/alertdam/issues/new?template=feature_request.yml) |
| A new platform to integrate with | [Open an integration request](https://github.com/darisadam/alertdam/issues/new?template=integration_request.yml) |
| **A security vulnerability** | [Report it privately](https://github.com/darisadam/alertdam/security/advisories/new) — **never** in a public issue. See [SECURITY.md](SECURITY.md) |

Questions filed as issues will usually be converted to discussions. That is not
a rebuke — it just keeps the issue tracker as a list of work to do.

## What to expect

AlertDam is maintained by one person in their spare time. There is **no SLA**,
and there is no paid support tier.

Realistically:

- Security reports: acknowledged within 48 hours (see [SECURITY.md](SECURITY.md)).
- Bug reports with clear reproduction steps: usually looked at within a week.
- Feature requests: read, labelled, and honestly deprioritised if they conflict
  with the project's design commitments.
- Pull requests: reviewed within a week or two. A PR that arrives with tests and
  a green CI run gets reviewed considerably faster than one without.

The single best thing you can do to get a fast response is to make the problem
cheap to reproduce.

## Before you ask

AlertDam is **pre-alpha**. Most API handlers currently return
`501 Not Implemented`. If you are getting a `501`, the feature is not built yet
rather than broken — check the roadmap in the [README](README.md).

Worth trying first:

```bash
# Is the service up?
curl -fsS http://localhost:8080/health

# Turn up the logs
APP_LOG_LEVEL=debug docker compose up

# What is actually running?
docker compose ps
docker compose logs app
```

And the documentation:

- [`docs/architecture.md`](docs/architecture.md) — how the pieces fit together
- [`docs/api-reference.md`](docs/api-reference.md) — endpoints and payloads
- [`docs/deployment.md`](docs/deployment.md) — self-hosting and reverse proxies
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — local development

## Commercial support

None exists today. Phase 3 of the roadmap contemplates a hosted offering; until
then, self-hosting is the only option and this repository is the only support
channel.
