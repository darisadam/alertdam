#!/bin/sh
# Validate every commit message in a pull request.
#
# Reads the commit list through the GitHub API rather than checking out the PR
# head, so no fork-controlled code is fetched or executed.
#
# Required environment:
#   GH_TOKEN   a token with pull-requests: read
#   REPO       owner/repo
#   PR_NUMBER  the pull request number

set -eu

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
LINT="$SCRIPT_DIR/../git/commit-msg-lint.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# base64-encode each record so embedded newlines survive line-based reading.
gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/commits" \
	--jq '.[] | {sha, author: (.author.login // .commit.author.name), msg: .commit.message} | @base64' \
	> "$WORK/commits.txt"

STATUS=0
COUNT=0

while IFS= read -r encoded; do
	[ -z "$encoded" ] && continue
	entry=$(printf '%s' "$encoded" | base64 -d)
	sha=$(printf '%s' "$entry" | jq -r '.sha')
	author=$(printf '%s' "$entry" | jq -r '.author')
	COUNT=$((COUNT + 1))

	if ! printf '%s' "$entry" | jq -r '.msg' \
		| COMMIT_AUTHOR="$author" sh "$LINT" --stdin; then
		echo "::error::commit ${sha} (by ${author}) has an invalid commit message"
		STATUS=1
	fi
done < "$WORK/commits.txt"

echo "validated $COUNT commit message(s)"

if [ "$STATUS" -ne 0 ]; then
	cat >&2 <<'EOF'

Individual commit messages are validated as well as the PR title. Only the
squashed PR title reaches main, but a readable branch history is worth keeping
and it is what reviewers read.

To fix:
  git rebase -i origin/main    # reword the offending commits
  git push --force-with-lease
EOF
fi

exit "$STATUS"
