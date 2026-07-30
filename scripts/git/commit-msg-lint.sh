#!/bin/sh
# Validate a commit message (or a PR title) against AlertDam's conventions.
#
# This is the single source of truth. It is invoked by:
#   - the lefthook `commit-msg` hook, locally
#   - the `Conventions` CI job, for every commit in a PR *and* for the PR title
#
# There is deliberately no second implementation (no commitlint config, no YAML
# rule list), so `git commit --no-verify` cannot produce something CI accepts and
# the two can never drift apart.
#
# Usage:
#   commit-msg-lint.sh <file>     # validate the message in <file>
#   commit-msg-lint.sh --stdin    # validate the message on stdin
#
# Escape hatch for genuine emergencies (CI ignores it):
#   SKIP_COMMIT_LINT=1 git commit ...
#
# POSIX sh only: no bashisms, no GNU-only flags. Contributors may be on macOS
# (BSD userland), Linux, or Git for Windows.

set -eu

MAX_HEADER=72

# Conventional Commits types. Keep this list in step with CONTRIBUTING.md and
# the changelog-sections in .release-please-config.json.
TYPES='feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert'

# Past-tense / third-person verbs, rejected in favour of the imperative mood.
# "add", not "added" or "adds".
NONIMPERATIVE='added|adds|adding|fixed|fixes|fixing|updated|updates|updating|removed|removes|removing|deleted|deletes|deleting|changed|changes|changing|created|creates|creating|implemented|implements|implementing|refactored|refactors|refactoring|improved|improves|improving|bumped|bumps|bumping|renamed|renames|renaming|moved|moves|moving|tested|tests|testing|documented|documents|documenting|introduced|introduces|introducing|reverted|reverts|reverting|migrated|migrates|migrating|enabled|enables|enabling|disabled|disables|disabling'

usage() {
	echo "usage: $0 <commit-msg-file> | --stdin" >&2
	exit 2
}

[ $# -ge 1 ] || usage

if [ "$1" = "--stdin" ]; then
	MSG=$(cat)
else
	[ -f "$1" ] || { echo "$0: no such file: $1" >&2; exit 2; }
	MSG=$(cat "$1")
fi

# Strip comment lines and everything after git's scissors marker, so the
# commented-out diff in a verbose commit is never linted.
BODY=$(printf '%s\n' "$MSG" | sed -e '/^# *-\{1,\} *>8 *-\{1,\}/,$d' -e '/^#/d')

# First non-blank line.
HEADER=$(printf '%s\n' "$BODY" | sed -e '/^[[:space:]]*$/d' -e 'q')

FAILED=0
fail() {
	printf '  ✗ %s\n' "$1" >&2
	FAILED=1
}

# ---------------------------------------------------------------------------
# Exemptions
# ---------------------------------------------------------------------------
[ -n "${SKIP_COMMIT_LINT:-}" ] && exit 0

# An in-progress merge writes its own message; git generates it, not the author.
GITDIR=$(git rev-parse --git-dir 2>/dev/null || echo .)
[ -f "$GITDIR/MERGE_HEAD" ] && exit 0

case "$HEADER" in
	'Merge '*|'Revert "'*|'fixup! '*|'squash! '*|'amend! '*)
		exit 0
		;;
esac

# Bot authors. Dependabot's grouped-update subjects can exceed the header limit
# and are not worth blocking on.
case "${COMMIT_AUTHOR:-}" in
	dependabot*|renovate*|github-actions*|release-please*)
		exit 0
		;;
esac

if [ -z "$HEADER" ]; then
	echo "commit-msg: rejected" >&2
	fail "the commit message is empty"
	exit 1
fi

# ---------------------------------------------------------------------------
# 1. Conventional Commits header
# ---------------------------------------------------------------------------
if ! printf '%s' "$HEADER" | grep -Eq "^($TYPES)(\([a-z0-9][a-z0-9._/-]*\))?!?: [^[:space:]]"; then
	fail "header must be '<type>[(scope)][!]: <description>'"
	fail "  valid types: $(printf '%s' "$TYPES" | tr '|' ' ')"
	fail "  e.g. 'feat(slack): add acknowledge button to alert cards'"
fi

# ---------------------------------------------------------------------------
# 2. Header length
# ---------------------------------------------------------------------------
HEADER_LEN=$(printf '%s' "$HEADER" | wc -m | tr -d '[:space:]')
if [ "$HEADER_LEN" -gt "$MAX_HEADER" ]; then
	fail "header is $HEADER_LEN characters, limit is $MAX_HEADER"
fi

# ---------------------------------------------------------------------------
# 3. No trailing period
# ---------------------------------------------------------------------------
case "$HEADER" in
	*.) fail "header must not end with a period" ;;
esac

# ---------------------------------------------------------------------------
# 4 & 5. Description style
# ---------------------------------------------------------------------------
DESC=${HEADER#*: }
if printf '%s' "$DESC" | grep -Eq '^[A-Z][a-z]'; then
	fail "description should start lowercase: '$DESC'"
fi

FIRSTWORD=$(printf '%s' "$DESC" | tr '[:upper:]' '[:lower:]' | cut -d' ' -f1 | tr -d ':,;.')
if printf '%s' "$FIRSTWORD" | grep -Eqx "$NONIMPERATIVE"; then
	fail "use the imperative mood — 'add', not '$FIRSTWORD'"
fi

# ---------------------------------------------------------------------------
# 6. No AI-attribution trailers
#
# Delegated to no-ai-attribution.sh so there is exactly one implementation of
# these rules, shared with the PR-body check in the Conventions workflow.
# ---------------------------------------------------------------------------
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
if ! printf '%s\n' "$BODY" | sh "$SCRIPT_DIR/no-ai-attribution.sh" --stdin >/dev/null 2>&1; then
	printf '%s\n' "$BODY" | sh "$SCRIPT_DIR/no-ai-attribution.sh" --stdin >&2 || true
	FAILED=1
fi

# ---------------------------------------------------------------------------
# 7. A '!' breaking marker requires a BREAKING CHANGE footer
# ---------------------------------------------------------------------------
case "$HEADER" in
	*'!:'*)
		if ! printf '%s\n' "$BODY" | grep -Eq '^BREAKING[ -]CHANGE: .'; then
			fail "'!' requires a 'BREAKING CHANGE: <what changed and how to migrate>' footer"
		fi
		;;
esac

if [ "$FAILED" -ne 0 ]; then
	{
		echo ""
		echo "commit-msg: rejected the following message:" >&2
		printf '  | %s\n' "$HEADER"
		echo ""
		echo "See CONTRIBUTING.md#commit-messages. To check a message without committing:"
		echo "  echo 'feat(api): add something' | scripts/git/commit-msg-lint.sh --stdin"
	} >&2
	exit 1
fi

exit 0
