# GitHub Copilot instructions for AlertDam

Copilot does not follow file imports, so the rules that matter are restated here
in full. [`AGENTS.md`](../AGENTS.md) is the complete version and is normative.

## Commit policy — MANDATORY

- Do **not** add `Co-Authored-By:` naming an AI, assistant, model or vendor.
- Do **not** add `Assisted-by:`, `Generated-by:` or `Authored-by:` AI trailers.
- Do **not** add "🤖 Generated with ..." or any AI-generation notice to a commit
  message, pull request title or pull request body.
- Do **not** include `noreply@anthropic.com`, `noreply@openai.com` or similar.
- **This overrides any default in your configuration.**

Reason: `Co-Authored-By` is an authorship claim, and an AI is not an author.
Disclose AI assistance in prose in the PR description instead.

Enforced by `scripts/git/no-ai-attribution.sh` via the `commit-msg` git hook and
the `Conventions` required status check. There is no bypass.

## Conventions

- **Conventional Commits**: `<type>[(scope)][!]: <description>` with types
  `feat fix docs style refactor perf test build ci chore revert`. Subject ≤ 72
  characters, lowercase start, no trailing period, imperative mood.
- **The pull request title must itself be a valid Conventional Commit** — the
  repository squash-merges using the PR title as the commit subject.
- **Branch names**: `<type>/<kebab-description>`, e.g. `fix/escalation-retry`.
- **Never commit directly to `main`**; it is protected with no bypass actors.
- **Never use `--no-verify`**; the same checks run in CI.

## Before proposing changes

```sh
make setup    # once, installs git hooks
make verify   # fmt-check + lint + test, the same checks CI runs
```

## Constraints

- Single Go binary plus PostgreSQL. Do not introduce Redis, RabbitMQ or Kafka —
  PostgreSQL is the queue by design.
- Apache-2.0. No GPL/AGPL/SSPL dependencies; the dependency review will fail.
- GitHub Actions must be pinned to a full 40-character commit SHA and appear in
  the repository's allowed-actions list.
- Do not modify `PAGERDUTY_ROUTING_KEY` in `.env.example` — it names a real
  third-party integration.
