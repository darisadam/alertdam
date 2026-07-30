#!/bin/sh
# pre-push guard: block direct pushes to protected branches and reject
# non-conforming branch names before they reach the remote.
#
# git feeds pre-push a set of lines on stdin:
#   <local-ref> <local-sha> <remote-ref> <remote-sha>
# stdin can only be read once, which is why branch-name validation and the
# protected-ref check live in this one script rather than two lefthook jobs.
#
# The server-side ruleset is the real enforcement; this just fails fast and
# locally, with a message that explains what to do instead.
#
# Emergency override (the server will still refuse):
#   ALLOW_PUSH_TO_MAIN=1 git push ...

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROTECTED='main'
ZERO='0000000000000000000000000000000000000000'
STATUS=0

# Nothing on stdin (e.g. invoked by hand) — fall back to the current branch.
if [ -t 0 ]; then
	sh "$SCRIPT_DIR/branch-name-lint.sh" || STATUS=1
	exit "$STATUS"
fi

# local_ref is read only to consume the field positionally; git's pre-push stdin
# format is fixed at four whitespace-separated fields per line.
# shellcheck disable=SC2034
while read -r local_ref local_sha remote_ref remote_sha; do
	[ -z "${remote_ref:-}" ] && continue

	branch=${remote_ref#refs/heads/}

	for p in $PROTECTED; do
		if [ "$branch" = "$p" ] && [ -z "${ALLOW_PUSH_TO_MAIN:-}" ]; then
			cat >&2 <<EOF
push rejected: direct pushes to '$p' are not allowed.

Every change lands through a pull request, including the maintainer's own.

  git switch -c feat/your-change
  git push -u origin feat/your-change
  gh pr create --fill

The '$p' ruleset enforces this server-side too, so bypassing this hook will
just move the failure to the remote.
EOF
			STATUS=1
		fi
	done

	# Branch deletions and rewrites of protected refs.
	if [ "$local_sha" = "$ZERO" ]; then
		for p in $PROTECTED; do
			if [ "$branch" = "$p" ]; then
				echo "push rejected: refusing to delete '$p'" >&2
				STATUS=1
			fi
		done
		continue
	fi

	# Validate the name of the branch actually being pushed.
	sh "$SCRIPT_DIR/branch-name-lint.sh" "$branch" || STATUS=1

	# Non-fast-forward to a protected ref.
	if [ "$remote_sha" != "$ZERO" ]; then
		for p in $PROTECTED; do
			if [ "$branch" = "$p" ] && ! git merge-base --is-ancestor "$remote_sha" "$local_sha" 2>/dev/null; then
				echo "push rejected: non-fast-forward push to '$p'" >&2
				STATUS=1
			fi
		done
	fi
done

exit "$STATUS"
