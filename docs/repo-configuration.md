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
