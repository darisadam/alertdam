# Repository configuration

This documents the GitHub-side configuration that enforces
[GOVERNANCE.md](../GOVERNANCE.md) and [CONTRIBUTING.md](../CONTRIBUTING.md). It
lives here rather than in `CHANGELOG.md`, because a changelog describes what a
*consumer of the software* receives, and none of this ships in the binary.

Everything below is applied through the GitHub API. The `gh` commands are
included so the state is reproducible and auditable.

---

## The governance problem, and how it is solved

Three requirements that look simple and are not:

1. The maintainer can open a pull request and merge it **without anyone else's
   approval**.
2. Outside contributors must fork, open a PR, and get **CI green plus maintainer
   approval** before it can merge.
3. **Nobody** — maintainer included — may commit directly to `main`.

GitHub cannot express requirement 1 and 2 together on a personal-account
repository. An approval requirement applies to every PR regardless of author, and
GitHub forbids approving your own PR — so `required_approving_review_count: 1`
locks the sole maintainer out permanently. That was literally this repository's
state before this configuration: a classic branch protection with
`required_approving_review_count: 1` and `enforce_admins: true`, which made the
owner unable to merge anything.

The tempting fix is a second ruleset that the admin bypasses in "for pull
requests only" mode. That is rejected here, because it puts the *only* thing
enforcing requirement 2 behind the *only* bypass in the system — and GitHub's own
description of that bypass mode is that the actor "can then choose to bypass any
branch protections and merge that pull request", which is too broad a blast
radius to build a security property on.

Instead:

- **One ruleset on `main`, with no bypass actors at all.** It requires a pull
  request with **zero** native approvals — which is what forbids direct pushes for
  everyone — plus required status checks.
- **Requirement 2 is a required status check**, `review-policy`, implemented in
  [`scripts/ci/review-policy.sh`](../scripts/ci/review-policy.sh). It reads the
  PR author's association: `OWNER`/`MEMBER`/`COLLABORATOR` passes immediately;
  anyone else needs an approving review from a `*` owner in
  [`.github/CODEOWNERS`](../.github/CODEOWNERS), on the current head commit. It
  **fails closed** on any error or unexpected state.

This is strictly stronger than the native rule, because it also stops the
maintainer from merging an external PR they never actually reviewed.

---

## Branch ruleset: `main`

```bash
gh api repos/darisadam/alertdam/rulesets --jq '.[] | "\(.id)\t\(.name)\t\(.target)\t\(.enforcement)"'
```

| Rule | Value | Why |
|---|---|---|
| `pull_request` | `required_approving_review_count: 0` | The presence of this rule is what requires a PR and blocks direct pushes. The count is 0 so the maintainer is not locked out; `review-policy` supplies the author-conditional requirement. |
| | `required_review_thread_resolution: true` | Unresolved review conversations block the merge. |
| | `dismiss_stale_reviews_on_push: true` | New commits invalidate prior approvals. |
| | `allowed_merge_methods: ["squash"]` | One Conventional Commit per PR on `main`. |
| `required_status_checks` | `strict: true` | The branch must be up to date with `main` before merging. |
| `required_linear_history` | — | No merge commits. |
| `non_fast_forward` | — | No force pushes. |
| `deletion` | — | `main` cannot be deleted. |
| **bypass_actors** | **empty** | Including for admins. See the break-glass procedure in GOVERNANCE.md. |

### Required status checks

| Context | Source | Blocks on |
|---|---|---|
| `CI` | `ci.yml` aggregation gate | Go, web, mobile, container, migrations, shell |
| `Conventions` | `conventions.yml` | Commit messages, PR title, PR body, branch name, AI-attribution ban, actionlint |
| `Security` | `security.yml` aggregation gate | gitleaks, osv-scanner |
| `CodeQL` | `codeql.yml` aggregation gate | Go and JavaScript/TypeScript analysis |
| `Dependency review` | `dependency-review.yml` | High-severity advisories, denied licences |
| `review-policy` | commit status from `review-policy.yml` | Maintainer approval for external PRs |

Each of `CI`, `Security` and `CodeQL` is an **aggregation gate** — a job that
always runs and fails only if a needed job failed. This is deliberate and
load-bearing:

- A required check must always report. A workflow skipped by a trigger-level
  `paths:` filter never reports at all, so the PR sits at "Expected — waiting for
  status" forever. Path filtering therefore happens *inside* the workflow, and
  the gate absorbs the skips.
- Skipped jobs are **not** treated as failures; failed and cancelled ones are.
- The gate name stays stable when a stack, a matrix leg or a linter is added
  later. Never mark a path-filtered job as required.

### Why signed commits are *not* required

Tempting, and wrong for this repository. GitHub's documentation states that with
required commit signing you "cannot squash and merge a pull request into the
branch on GitHub unless you are the author of the pull request" — the workaround
being to squash and merge locally. That directly breaks requirement 2: the
maintainer could never squash-merge an outside contributor's PR through the UI.

Instead, the maintainer signs locally (SSH signing) and squash merges made
through GitHub are auto-signed with GitHub's web-flow key, so `main` ends up
verified in practice without the rule that would deadlock external contributions.

---

## Tag ruleset

Protects release tags without preventing automation from creating them.

- Targets `refs/tags/v*`
- Blocks `deletion` and `non_fast_forward`
- Does **not** block `creation` — release-please must be able to tag
- Admin bypass retained, so a mistaken tag can be cleaned up

> Metadata restriction rules (`tag_name_pattern`, `branch_name_pattern`,
> `commit_message_pattern`, the email patterns) are documented by GitHub as
> available to organisations on an Enterprise plan, so they are unavailable here.
> Those conventions are enforced by the `Conventions` CI job instead — which is
> the better enforcement point anyway, since ruleset metadata rules do not apply
> to fork pull requests at all.

---

## Merge settings

| Setting | Value | Why |
|---|---|---|
| Squash merge | enabled | One Conventional Commit per PR |
| Merge commit | **disabled** | Would break linear history |
| Rebase merge | **disabled** | Replays contributor commits individually, unsigned and only as well-formatted as their local history |
| Squash commit title | `PR_TITLE` | This is why PR-title linting is load-bearing |
| Squash commit message | `PR_BODY` | And why the PR body is checked for AI-attribution markers |
| Auto-merge | enabled | Used by Dependabot auto-merge |
| Update branch | enabled | Needed for the `strict` up-to-date requirement to be usable |
| Delete branch on merge | enabled | Trunk-based hygiene |

---

## GitHub Actions

```bash
gh api repos/darisadam/alertdam/actions/permissions
gh api repos/darisadam/alertdam/actions/permissions/selected-actions
gh api repos/darisadam/alertdam/actions/permissions/workflow
gh api repos/darisadam/alertdam/actions/permissions/fork-pr-contributor-approval
gh api repos/darisadam/alertdam/actions/permissions/artifact-and-log-retention
```

| Setting | Value | Why |
|---|---|---|
| `allowed_actions` | `selected` | GitHub-owned plus an explicit allow-list |
| `verified_allowed` | `false` | "Verified creator" is a weak signal; each third-party action is listed by name |
| `sha_pinning_required` | `true` | A tag is mutable; a commit SHA is not. `@v4` is rejected at run time |
| `default_workflow_permissions` | `read` | Least privilege; jobs escalate individually |
| `can_approve_pull_request_reviews` | `false` | `github-actions[bot]` must not be able to rubber-stamp PRs |
| `fork-pr-contributor-approval` | `all_external_contributors` | No stranger's code runs in CI unreviewed. Costs the maintainer one extra click per external PR |
| Artifact/log retention | 30 days | Down from the 90-day default |

The allow-list is exactly the set of third-party actions the workflows use — no
more. Adding an action requires both an allow-list entry and a SHA pin.

Deliberately **not** used as actions, and installed as pinned release binaries
instead: `gitleaks` (its action requires a licence key for organisation-owned
repositories, which would silently break if this project ever moves to an org),
`actionlint`, `osv-scanner`, and label syncing (a `gh`-based script). Each removes
a trust relationship in exchange for a few lines of shell.

---

## Security features

```bash
gh api repos/darisadam/alertdam --jq '.security_and_analysis'
gh api repos/darisadam/alertdam/private-vulnerability-reporting
```

| Feature | State |
|---|---|
| Secret scanning | enabled |
| Secret scanning push protection | enabled |
| Dependabot alerts | enabled |
| Dependabot security updates | enabled |
| Private vulnerability reporting | enabled |
| Secret scanning non-provider patterns | **unavailable** — a GitHub Advanced Security feature, not offered on a personal free account |
| Secret scanning validity checks | **unavailable** — same reason |
| Code scanning | CodeQL via the committed `codeql.yml` (advanced setup, for a stable required-check name) |

---

## Environments

| Environment | Reviewers | Deployable refs |
|---|---|---|
| `staging` | none | Protected branches |
| `production` | `@darisadam` | Tags matching `v*` |

`prevent_self_review` is `false` on `production` on purpose: the maintainer is the
only reviewer, so preventing self-review would deadlock every release — the same
class of bug as the original branch protection.

No environment secrets are needed. GHCR uses the ephemeral `GITHUB_TOKEN`, and
cosign signs keyless via Sigstore using the workflow's OIDC identity. The release
path contains no long-lived credential.

---

## Repository variables

```bash
gh variable list --repo darisadam/alertdam
```

`GO_VERSION`, `NODE_VERSION`, `FLUTTER_VERSION`, `GOLANGCI_LINT_VERSION`,
`GITLEAKS_VERSION`, `ACTIONLINT_VERSION`, `OSV_SCANNER_VERSION`, `REGISTRY`,
`IMAGE_NAME`.

Toolchain versions also appear in `.tool-versions` for humans and local tooling.
Where a workflow can read the version from the source of truth directly it does —
`go-version-file: backend/go.mod`, `node-version-file: .nvmrc` — which is better
than any variable.

---

## Labels

The taxonomy in [`.github/labels.yml`](../.github/labels.yml) is the single
source of truth, synced by `labels.yml` on every push to `main` that touches it.

Preview without applying:

```bash
gh workflow run labels.yml -f dry_run=true
```

`good first issue`, `help wanted` and `dependencies` are load-bearing names —
GitHub surfaces the first two in its contributor funnel and Dependabot applies the
third. Do not rename them.

---

## Auditing

Bypasses. With no bypass actors configured this should always be empty; an entry
means someone disabled a ruleset:

```bash
gh api "repos/darisadam/alertdam/rulesets/rule-suites?time_period=week" \
  --jq '.[] | select(.result == "bypass")'
```

Configuration drift — re-read the live state and compare it against this document:

```bash
gh api repos/darisadam/alertdam --jq \
  '{visibility, default_branch, allow_squash_merge, allow_merge_commit, allow_rebase_merge,
    allow_update_branch, delete_branch_on_merge, squash_merge_commit_title,
    has_wiki, has_discussions, security_and_analysis}'
```

Community health completeness:

```bash
gh api repos/darisadam/alertdam/community/profile --jq '{health_percentage, files: (.files | keys)}'
```

---

## Verified behaviour

Every claim above was tested against the live repository rather than assumed.
Re-run these after any ruleset change.

**Direct push to `main` is rejected, server-side, with the local hook bypassed.**
The local `pre-push` hook fires first, so it must be skipped to test the server:

```bash
git switch -c chore/scratch && echo x > .scratch && git add .scratch
git commit --no-verify -m "chore: scratch"
git push --no-verify origin HEAD:main
```

```
remote: error: GH013: Repository rule violations found for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - 4 of 4 required status checks are expected.
```

**The maintainer merges their own PR with zero approvals.** The `review-policy`
status reports `author darisadam is a maintainer; no approval required`, and the
merge succeeds with no review. Confirmed on PR #20 and on every PR in this
hardening series.

**The maintainer cannot bypass the ruleset.**

```bash
$ gh api repos/darisadam/alertdam/rulesets/20018536 --jq '{current_user_can_bypass, bypass_actors}'
{"bypass_actors":[],"current_user_can_bypass":"never"}
```

**The convention gate rejects real violations.** A PR titled `update feature`,
with a commit whose subject was `update feature` and whose trailers included
`Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`, a
`Generated with [Claude Code]` line and a 🤖 marker — all committed with
`--no-verify` to simulate a bypassed local hook — produced:

```
✗ header must be '<type>[(scope)][!]: <description>'
✗ AI-attribution trailer found (Co-Authored-By / Assisted-by / Generated-by naming an AI)
✗ AI-generation notice found ("Generated with ...")
✗ AI vendor no-reply address found
✗ robot emoji marker found
validated 2 commit message(s)
```

Note the gate fails fast: the PR title is checked before the body, and the body
before the commits, so fixing one violation can reveal the next. That is a
deliberate trade of completeness for a short feedback loop on the check that
matters most (the title, which becomes the commit on `main`).

**Dependabot auto-merge respects the major/minor split.** With the full config
live, patch and minor bumps (#10 chi 5.3.0→5.3.1, #17 intl 0.19→0.20.3) merged
themselves once CI was green, while every major bump (#9 postgres 16→18, #14
lucide-react 0.460→1.27, #15 @types/node 22→26, #18 flutter_secure_storage 9→10,
#19 flutter_local_notifications 17→22) was labelled `status/needs-review` and left
for a human.

> One caveat this surfaced: Dependabot classifies `0.19 → 0.20` as *semver-minor*,
> so it auto-merges. For `0.x` dependencies a minor bump can be breaking by
> convention. If that becomes a problem, add an `ignore` rule for
> `version-update:semver-minor` on the specific `0.x` packages that matter.

**`pull_request_target` workflows cannot run until they are on the base branch.**
`Conventions`, `Review policy`, `Labeler` and `Dependabot auto-merge` did not
execute on the pull request that introduced them, because that trigger reads the
workflow definition from the *base* ref. This is expected, and it is why
`Conventions` and `review-policy` were added to the required-check list only after
a subsequent PR proved they run. Anyone adding a new `pull_request_target`
workflow should expect the same one-PR delay.

## Known gaps

- **Bus factor is 1.** With no bypass actors and a single admin, the only recovery
  from a misconfigured ruleset is disabling it. Documented in GOVERNANCE.md.
- **`require_code_owner_review` is off.** With one code owner it would demand an
  approval only that person could give. Turn it on when a second maintainer joins.
- **The social preview image must be uploaded through the web UI.** There is no
  REST endpoint for it — the only part of this configuration that is not
  scriptable.
- **release-please needs a GitHub App before the first release.** Events created
  by `GITHUB_TOKEN` do not trigger workflows, so a release PR opened with it gets
  no CI and is unmergeable while required checks are on. See the comment at the
  top of `.github/workflows/release.yml`.
- **Ruleset configuration is not yet code.** Managing it with
  `terraform-provider-github` would make this document executable rather than
  descriptive.
