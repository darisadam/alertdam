#!/bin/sh
# Refuse to commit files that should never be in version control.
#
# .gitignore already covers these, but a `git add -f` or a rule added after the
# file was tracked slips straight past it. This is a hard stop.
#
# Usage: reject-secrets-files.sh <file>...

set -eu

[ $# -eq 0 ] && exit 0

STATUS=0

for f in "$@"; do
	base=$(basename "$f")
	case "$base" in
		# Environment files, except the committed template.
		.env|.env.*)
			[ "$base" = ".env.example" ] && continue
			;;
		# Credential material.
		*.pem|*.key|*.p8|*.p12|*.pfx|*.jks|*.keystore) ;;
		# Cloud / mobile service credentials.
		service-account.json|google-services.json|GoogleService-Info.plist) ;;
		id_rsa|id_ed25519|id_ecdsa) ;;
		*) continue ;;
	esac

	echo "refusing to commit '$f' — this looks like credential material." >&2
	STATUS=1
done

if [ "$STATUS" -ne 0 ]; then
	cat >&2 <<'EOF'

If this is genuinely not a secret, rename it or add an explicit exception to
scripts/git/reject-secrets-files.sh with a comment explaining why.

To unstage:
  git restore --staged <file>
EOF
fi

exit "$STATUS"
