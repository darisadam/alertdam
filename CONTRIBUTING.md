# Contributing to AlertDam

Thanks for your interest in contributing. 🎉

AlertDam is **pre-alpha**: the structure, schema and API surface exist, but most
backend handlers still return `501 Not Implemented`. That means there is a lot of
well-defined work available, and also that things may move under you.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Branching](#branching)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Conventions Enforced Automatically](#conventions-enforced-automatically)
- [Development Setup](#development-setup)
- [Testing](#testing)

---

## Code of Conduct

This project has a [Code of Conduct](CODE_OF_CONDUCT.md) (Contributor Covenant
2.1). By participating you agree to abide by it. Reporting instructions,
including the current limitations of the reporting channel, are in that document.

---

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/alertdam.git
   cd alertdam
   ```
3. **Add the upstream remote:**
   ```bash
   git remote add upstream https://github.com/darisadam/alertdam.git
   ```
4. **Set up your environment.** This installs the git hooks, so do not skip it:
   ```bash
   make setup
   cp .env.example .env
   # Edit .env — JWT_SECRET is required and deliberately has no default
   ```
5. **Check everything works:**
   ```bash
   make verify
   ```

`make setup` installs [lefthook](https://lefthook.dev), a single static binary —
you do not need Node or Python unless you are working in `web/` or `mobile/`.

---

## Branching

AlertDam uses **trunk-based development**. In GitHub's vocabulary this is
"GitHub Flow"; the two names describe the same thing, so do not go looking for a
distinction:

- `main` is the **only** long-lived branch. It is always releasable.
- All work happens on **short-lived** branches off the latest `main`, merged back
  within a few days.
- There is no `develop`, no release branches, and no long-running forks.
- Releases are cut by **tagging `main`**, not by branching from it.

**Branch names must be `<type>/<kebab-description>`:**

| Prefix | For |
|---|---|
| `feat/` | New features |
| `fix/` | Bug fixes |
| `docs/` | Documentation |
| `refactor/` | Restructuring with no behaviour change |
| `perf/` | Performance work |
| `test/` | Tests |
| `style/` | Formatting only |
| `chore/`, `build/`, `ci/` | Maintenance, dependencies, pipelines |
| `hotfix/` | Urgent production fix |

```bash
git fetch upstream
git switch main && git merge --ff-only upstream/main
git switch -c feat/slack-thread-support
```

**Rules:**

- **Never commit directly to `main`.** The `main` ruleset has no bypass actors, so
  a direct push is rejected server-side — for maintainers too.
- Keep branches short-lived and scoped to one concern.
- Rebase on `main` rather than merging `main` into your branch, so history stays
  linear: `git fetch upstream && git rebase upstream/main`.

---

## Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/).

```
<type>(<optional scope>): <description>

[optional body]

[optional footer, e.g. Closes #123 or BREAKING CHANGE: ...]
```

**Types:** `feat` `fix` `docs` `style` `refactor` `perf` `test` `build` `ci`
`chore` `revert`

**Rules, all machine-checked:**

- Subject ≤ 72 characters
- Description starts lowercase, no trailing period
- **Imperative mood** — "add", not "added" or "adds"
- A `!` before the colon (`feat!:`) requires a `BREAKING CHANGE:` footer
  describing the migration

```bash
git commit -m "feat(slack): add acknowledge button to alert cards"
git commit -m "fix(escalation): prevent duplicate notifications on retry"
git commit -m "docs: add self-hosting guide"
git commit -m "chore(deps): bump chi to 5.2.4"
```

Check a message before you commit:

```bash
echo 'feat(api): add something' | sh scripts/git/commit-msg-lint.sh --stdin
```

### Prohibited trailers

The following are **rejected** in commit messages, PR titles and PR bodies:

- `Co-Authored-By:` naming an AI, assistant, model or vendor
- `Assisted-by:`, `Generated-by:` or `Authored-by:` naming an AI
- "🤖 Generated with ...", "Created with ..." or any AI-generation notice
- `noreply@anthropic.com`, `noreply@openai.com` and similar addresses
- The 🤖 emoji

**Why:** `Co-Authored-By` is an authorship claim, and an AI is not a legal author
and cannot hold copyright — so the trailer is meaningless at best and misleading
about provenance at worst. It also pollutes `git log` and the contributor graph.

**AI assistance is welcome.** Disclose it in prose in the pull request
description instead, where it is actually useful information:

> Drafted with AI assistance; I reviewed the logic and added the tests.

If your assistant adds these trailers by default, the rules are restated for it
in [`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md) and
[`.github/copilot-instructions.md`](.github/copilot-instructions.md).

---

## Pull Request Process

1. Rebase onto the latest `main`.
2. Run `make verify` — it runs exactly what CI runs.
3. **Make the PR title a valid Conventional Commit.** This is the single most
   important formatting rule here: the repository squash-merges using the PR
   title as the commit subject, so **your PR title becomes the history on
   `main`**, and it is what release-please reads to compute the next version. A
   tidy local history with a sloppy PR title still produces a sloppy `main`.
4. Fill in the PR template. The body also becomes part of the commit message, so
   delete the sections that do not apply.
5. Link the issue: `Closes #123`.
6. Wait for CI. **If you are an outside contributor, a maintainer must click
   "Approve and run workflows" before CI starts** — this repository requires
   approval for all external contributors' workflow runs. A PR sitting with no
   checks is waiting on that click, not broken.
7. All required status checks must pass.
8. Outside contributions additionally need an approving review from a maintainer.
   Maintainers' own PRs do not require an approval, because there is nobody else
   to give one — see [GOVERNANCE.md](GOVERNANCE.md).
9. Merging is **squash only**. Merge commits and rebase merges are disabled.

---

## Conventions Enforced Automatically

Nothing here relies on you remembering it. Every rule runs in a git hook *and* in
CI, from the same script — so `git commit --no-verify` only defers the failure, it
cannot avoid it.

| Rule | Local hook | CI job | Implementation |
|---|---|---|---|
| Conventional commit message | `commit-msg` | `Conventions` | `scripts/git/commit-msg-lint.sh` |
| PR title is a valid commit | — | `Conventions` | same script, `--stdin` |
| No AI-attribution trailers | `commit-msg` | `Conventions` | `scripts/git/no-ai-attribution.sh` |
| Branch name | `pre-push` | `Conventions` | `scripts/git/branch-name-lint.sh` |
| No direct push to `main` | `pre-push` | `main` ruleset | `scripts/git/pre-push-guard.sh` |
| No secrets committed | `pre-commit` | `Security` | gitleaks + `.gitleaks.toml` |
| No credential files committed | `pre-commit` | — | `scripts/git/reject-secrets-files.sh` |
| No conflict markers | `pre-commit` | — | `scripts/git/no-conflict-markers.sh` |
| Go formatted, vetted, linted | `pre-commit` | `CI` | gofmt, go vet, golangci-lint |
| Web linted and formatted | `pre-commit` | `CI` | eslint, prettier |
| Dart formatted | `pre-commit` | `CI` | dart format |
| Tests pass | `pre-push` | `CI` | go test -race, vitest, flutter test |
| Workflows valid | `pre-commit` | `Conventions` | actionlint |
| Shell scripts valid | `pre-commit` | `CI` | shellcheck |
| Reviewed by a maintainer (external PRs) | — | `review-policy` | `scripts/ci/review-policy.sh` |

Preview the hooks without committing:

```bash
lefthook run pre-commit --all-files
```

There is one escape hatch, `SKIP_COMMIT_LINT=1`, for genuine emergencies. CI
ignores it.

---

## Development Setup

### Backend (Go)
```bash
cd backend
go mod download
go run ./cmd/alertdam      # starts the server on :8080
```

### Web Dashboard (React)
```bash
cd web
npm ci
npm run dev                # :3000, proxying /v1 to :8080
```

### Mobile App (Flutter)
```bash
cd mobile
flutter pub get
flutter analyze
flutter test
```

> `mobile/ios/` and `mobile/android/` do not exist yet, so `flutter run` and
> `flutter build` will not work. Run `flutter create --platforms=android,ios .`
> first — and consider contributing that scaffolding as its own PR.

### Full stack (Docker)
```bash
make dev
curl -fsS http://localhost:8080/health
```

---

## Testing

```bash
make verify          # everything CI runs
make test            # backend (with -race) + web
make test-backend
make test-web
make test-mobile     # requires flutter
make coverage-report
make secrets-scan
```

Please add tests for new functionality. The target is **>80% backend coverage**;
we are well below that today because most handlers are stubs, so the CI coverage
report is currently **advisory rather than a gate**. It will be ratcheted upward
as real code lands — please do not add a hard floor before then.

---

## Questions?

Open a [Discussion](https://github.com/darisadam/alertdam/discussions) or read
[SUPPORT.md](SUPPORT.md). For security issues, see [SECURITY.md](SECURITY.md) —
never a public issue.
