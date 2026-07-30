# 0003. Enforce the review policy as a status check, not a ruleset bypass

- **Status:** Accepted
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

Three requirements had to hold at once on a personal-account repository:

1. The maintainer can open a PR and merge it with **no** approvals.
2. Outside contributors need **CI green plus maintainer approval**.
3. **Nobody**, maintainer included, may push directly to `main`.

GitHub cannot express 1 and 2 together. An approval requirement applies to every
PR regardless of author, and GitHub forbids approving your own PR — so
`required_approving_review_count: 1` locks a sole maintainer out permanently.

This was not hypothetical. The repository already had a classic branch protection
with `required_approving_review_count: 1` and `enforce_admins: true`, which made
the owner unable to merge anything. The repository was simultaneously unprotected
(no status checks existed at all) and unmergeable.

## Decision

Use **one ruleset on `main` with no bypass actors**, requiring a pull request with
`required_approving_review_count: 0` plus required status checks. Encode the
author-conditional rule as a required status check, `review-policy`, implemented
in `scripts/ci/review-policy.sh`.

The `pull_request` rule's mere presence is what forbids direct pushes, so
requirement 3 holds for everyone at count 0. `review-policy` reads the PR author's
`author_association`: `OWNER`/`MEMBER`/`COLLABORATOR` passes; anyone else requires
an approving review from a `*` owner in `.github/CODEOWNERS`, on the current head
commit. It fails closed.

## Consequences

### Positive

- **No bypass actors anywhere in the system.** Nothing depends on a bypass
  behaving as hoped.
- Enforces something the native rule cannot: the maintainer cannot merge an
  external PR they never reviewed, because the check requires *their own recorded
  approval*, not merely their willingness to click merge.
- Stale approvals are handled explicitly — an approval is only honoured if its
  `commit_id` matches the current head.
- `CODEOWNERS` becomes the single source of truth for "who is a maintainer", used
  by both GitHub's review-request routing and this check.

### Negative

- It is custom code, so it is ours to maintain and ours to get wrong. Mitigated by
  failing closed: any error, unexpected association, or API failure produces a
  failing status.
- A shell script is now load-bearing for a security property. It has no unit tests
  yet — the practical verification is the end-to-end test with a second account.
- If the workflow itself is broken or the runner is unavailable, the status is
  never posted and PRs block. That is the correct direction to fail, but it does
  mean a broken workflow blocks all merges until fixed (see the break-glass
  procedure in GOVERNANCE.md).
- Uses `pull_request_target`, which is a genuinely dangerous trigger in general.
  Mitigated by checking out only the **base** ref and never fetching or executing
  fork code.

### Neutral

- Published as a **commit status** rather than relying on the job's own check run,
  so one workflow can update the same context whether it was triggered by a push
  or by a review being submitted.

## Alternatives considered

**Two rulesets, admin bypassing the review one in "for pull requests only" mode.**
The obvious design, and the one initially planned. Rejected: it puts the only
thing enforcing requirement 2 behind the only bypass in the system, and GitHub's
own documentation describes that bypass mode as letting the actor "bypass any
branch protections and merge that pull request" — too broad and too vague to build
a security property on. It also leaves the maintainer able to merge unreviewed
external work.

**Require signed commits as an additional control.** Rejected on a hard
incompatibility: with required commit signing, GitHub does not allow squash-merging
a PR you did not author, so the maintainer could never merge an outside
contribution through the UI. Signing is used locally for provenance instead.

**`require_code_owner_review: true`.** Requires an approval count ≥ 1, so it
reintroduces the self-approval deadlock while there is a single code owner. Turn it
on when a second maintainer joins.

**Accept requirement 1 being violated** — i.e. add a second account purely to
approve the maintainer's PRs. Rejected as theatre: a rubber-stamp account provides
no review value and misrepresents the project's actual review depth.
