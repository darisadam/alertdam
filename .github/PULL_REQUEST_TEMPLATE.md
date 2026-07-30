<!--
  Two things about this template:

  1. Your PR TITLE must be a valid Conventional Commit. This repository
     squash-merges with the PR title as the commit subject, so the title
     literally becomes the history on `main` and is what release-please reads to
     compute the next version. A CI check enforces it.
       ✓ feat(slack): add acknowledge button to alert cards
       ✗ Update feature

  2. This BODY becomes the commit message body. Delete the sections that do not
     apply — whatever you leave here is what future readers of `git log` see.
-->

## Summary

<!-- What changes, and why. One or two paragraphs. -->

## Motivation

<!-- The problem this solves. Link the issue: Closes #123 -->

Closes #

## Type of change

<!-- Should match your PR title's type. -->

- [ ] `feat` — new capability
- [ ] `fix` — bug fix
- [ ] `docs` — documentation only
- [ ] `refactor` — no behaviour change
- [ ] `perf` — performance
- [ ] `test` — tests only
- [ ] `chore` / `build` / `ci` — tooling, dependencies, pipelines

## Components touched

- [ ] `backend/` (Go)
- [ ] `web/` (React)
- [ ] `mobile/` (Flutter)
- [ ] `backend/migrations/` (database schema)
- [ ] `deploy/` (Docker, Kubernetes)
- [ ] `docs/`
- [ ] `.github/` / `scripts/` (CI, tooling)

## How this was tested

<!-- Be specific. "make verify passes" is a good start but rarely the whole
     story — say what you actually exercised. -->

- [ ] `make verify` passes locally
- [ ] Added or updated tests covering the change
- [ ] Manually verified against a running stack (`make dev`)

## Breaking changes

<!-- If your title has `!`, a `BREAKING CHANGE:` footer is required and CI will
     check for it. Describe the migration path here. -->

- [ ] This PR contains no breaking changes

## Checklist

- [ ] The PR title is a valid Conventional Commit (it becomes the commit on `main`)
- [ ] The branch is named `<type>/<description>` (e.g. `feat/slack-buttons`)
- [ ] Documentation and `.env.example` updated if behaviour or configuration changed
- [ ] No secrets, tokens or real credentials in the diff, the logs, or this description
- [ ] No AI-attribution trailers in the commits, title or body — see
      [CONTRIBUTING.md](../CONTRIBUTING.md#commit-messages). Disclose AI
      assistance in prose in the Summary instead.
