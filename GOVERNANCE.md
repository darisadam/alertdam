# Governance

This document describes how decisions get made in AlertDam. It is deliberately
short and deliberately honest about the project's current size.

## Current model: single maintainer

AlertDam has one maintainer ([@darisadam](https://github.com/darisadam)), who
has final say on scope, design and releases. There is no committee, no voting,
and no pretence of one.

That is the appropriate structure for a project at this stage, but it has real
consequences worth stating plainly:

* **Reviews are one-deep.** Every merged change was reviewed by at most one
  person, who is also its most likely author.
* **The bus factor is 1.** If the maintainer becomes unavailable, nothing merges.
  See [Continuity](#continuity).
* **Code-of-conduct enforcement has no internal appeal.** See the conflict-of-
  interest section in [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## How decisions are made

| Decision | Who decides | How |
|---|---|---|
| Bug fixes, docs, tests | Anyone may propose; maintainer approves | Pull request |
| New features | Maintainer, after discussion | Open an issue or discussion **before** writing code, so nobody's afternoon is wasted on something out of scope |
| Breaking changes | Maintainer | Requires a `!` commit and a `BREAKING CHANGE:` footer; called out in the release notes |
| Architecture changes | Maintainer | Recorded as an ADR in [`docs/adr/`](docs/adr/) |
| Releases | Maintainer | release-please opens a release PR; merging it tags and publishes |
| Roadmap | Maintainer | The phase table in the README |

Disagreement is resolved by discussion in the issue or PR. If discussion does
not converge, the maintainer decides and explains why in the thread. "Because I
said so" is not an acceptable rationale; "this conflicts with the single-binary
constraint, which is a design commitment" is.

## Becoming a maintainer

There is no application process. The path is:

1. Land two or more non-trivial pull requests that needed little rework.
2. Review other people's pull requests usefully and consistently over a few
   months.
3. Show judgement about what belongs in the project, including saying no.

The maintainer will then offer commit access. Maintainers are added to
[MAINTAINERS.md](MAINTAINERS.md) and to the `*` rule in
[`.github/CODEOWNERS`](.github/CODEOWNERS) — the latter matters mechanically,
because `scripts/ci/review-policy.sh` reads that rule to decide who is allowed
to approve an outside contributor's PR.

**When the second maintainer joins**, two things should change:

* Turn on `require_code_owner_review` in the `main` ruleset. It is off today
  because with a single code owner it would demand an approval only that person
  could give, and GitHub forbids self-approval — making every maintainer PR
  permanently unmergeable.
* Remove the conflict-of-interest caveat from the Code of Conduct.

Maintainers who go inactive for twelve months are moved to an "emeritus" section
of MAINTAINERS.md, with thanks. This is bookkeeping, not a demotion, and it is
reversible on request.

## Repository configuration is part of governance

Branch rules, required status checks and the review policy are not incidental
CI plumbing — they are the mechanism by which this document is enforced. They are
documented in [`docs/repo-configuration.md`](docs/repo-configuration.md) and
changes to `.github/` and `scripts/` require maintainer review via CODEOWNERS.

Notably, the `main` ruleset has **no bypass actors**. Nobody, including the
maintainer, can merge to `main` without a pull request and green required checks.

## Break-glass

Because there are no bypass actors, a misconfigured ruleset can lock the
repository out entirely — including locking out the fix. The only recovery path
is for a repository admin to disable the ruleset:

```bash
# List rulesets to find the id
gh api repos/darisadam/alertdam/rulesets --jq '.[] | "\(.id)\t\(.name)\t\(.enforcement)"'

# Disable it (does not delete it)
gh api --method PUT repos/darisadam/alertdam/rulesets/<id> -f enforcement=disabled

# ... fix the problem, then re-enable
gh api --method PUT repos/darisadam/alertdam/rulesets/<id> -f enforcement=active
```

Any use of this should be stated in the PR that follows. Bypasses are auditable:

```bash
gh api "repos/darisadam/alertdam/rulesets/rule-suites?time_period=week" \
  --jq '.[] | select(.result == "bypass")'
```

With no bypass actors configured, that query should always return nothing. An
entry means someone disabled a ruleset.

## Continuity

If the maintainer becomes unreachable for six months and the project has other
active contributors, those contributors may:

1. Open a discussion proposing new maintainership, and leave it open for 30 days.
2. If there is no response from the current maintainer, fork the project under a
   new name, keeping attribution per the Apache-2.0 licence and
   [TRADEMARKS.md](TRADEMARKS.md) (the AlertDam name and logo do not transfer
   with the code).
3. Ask GitHub Support about transferring the original repository, which is
   entirely at GitHub's and the maintainer's discretion.

If the project is abandoned outright, the maintainer will archive the repository
with a pointer to any recommended successor rather than leaving it looking
maintained.

## Changing this document

Via pull request, approved by the maintainer.
