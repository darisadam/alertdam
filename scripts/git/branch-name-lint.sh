#!/bin/sh
# Validate a git branch name against AlertDam's trunk-based convention.
#
# Usage:
#   branch-name-lint.sh              # validate the current branch
#   branch-name-lint.sh <name>       # validate a specific name
#
# Shared by the lefthook `pre-push` hook and the `Conventions` CI job.

set -eu

BRANCH=${1:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')}

# The pattern mirrors the Conventional Commit types, so a branch name predicts
# the commit type and the auto-applied `type/*` label.
PATTERN='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|hotfix)/[a-z0-9][a-z0-9._-]*$'

# Branches that are created by tooling, or are the trunk itself.
case "$BRANCH" in
	main|HEAD|'')
		exit 0
		;;
	dependabot/*|renovate/*|release-please--*|revert-*|gh-readonly-queue/*)
		exit 0
		;;
esac

if printf '%s' "$BRANCH" | grep -Eq "$PATTERN"; then
	exit 0
fi

cat >&2 <<EOF
branch name rejected: $BRANCH

Branches must be <type>/<short-kebab-description>, where <type> is one of:
  feat fix docs style refactor perf test build ci chore revert hotfix

  ✓ feat/slack-acknowledge-button
  ✓ fix/escalation-duplicate-notifications
  ✓ chore/bump-go-1.24
  ✗ my-stuff
  ✗ Feature/NewThing
  ✗ patch-1

Rename the current branch with:
  git branch -m feat/your-description

See CONTRIBUTING.md#branching.
EOF
exit 1
