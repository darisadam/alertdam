#!/bin/sh
# Reject files containing unresolved merge-conflict markers.
#
# Usage: no-conflict-markers.sh <file>...
# Invoked by the lefthook pre-commit hook with the staged file list.

set -eu

[ $# -eq 0 ] && exit 0

STATUS=0

for f in "$@"; do
	[ -f "$f" ] || continue
	# Skip this script and its own documentation, which necessarily mention the
	# markers, and skip binary files.
	case "$f" in
		scripts/git/no-conflict-markers.sh|CONTRIBUTING.md) continue ;;
	esac
	grep -Iq . "$f" 2>/dev/null || continue

	if grep -nE '^(<{7}|={7}|>{7})( |$)' "$f" >/dev/null 2>&1; then
		echo "unresolved merge conflict markers in $f:" >&2
		grep -nE '^(<{7}|={7}|>{7})( |$)' "$f" >&2
		STATUS=1
	fi
done

exit "$STATUS"
