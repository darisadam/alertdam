#!/bin/sh
# Reject AI-attribution markers in a block of text.
#
# Applied to commit messages (via commit-msg-lint.sh) and, separately, to PR
# bodies — because this repository squash-merges with
# squash_merge_commit_message=PR_BODY, so the PR body lands verbatim in the
# commit message on main.
#
# The Conventional Commits grammar deliberately does NOT apply to a PR body;
# only these rules do.
#
# Rationale (also in CONTRIBUTING.md): `Co-Authored-By` is an authorship claim,
# and an AI is not an author and cannot hold copyright, so the trailer is
# meaningless at best and misleading at worst. Disclose AI assistance in prose
# in the PR description instead.
#
# Usage:
#   no-ai-attribution.sh --stdin
#   no-ai-attribution.sh <file>

set -eu

AI='claude|anthropic|copilot|chatgpt|openai|gpt-[0-9]|gemini|cursor|codeium|codex|devin|aider|windsurf|llm'

case "${1:---stdin}" in
	--stdin) TEXT=$(cat) ;;
	*)       TEXT=$(cat "$1") ;;
esac

STATUS=0
fail() {
	printf '  ✗ %s\n' "$1" >&2
	STATUS=1
}

if printf '%s\n' "$TEXT" | grep -Eiq "^[[:space:]]*(co-authored-by|assisted-by|generated-by|authored-by)[[:space:]]*:.*($AI)"; then
	fail "AI-attribution trailer found (Co-Authored-By / Assisted-by / Generated-by naming an AI)"
fi
if printf '%s\n' "$TEXT" | grep -Eiq "(generated|created|written) with .*($AI)"; then
	fail "AI-generation notice found (\"Generated with ...\")"
fi
if printf '%s\n' "$TEXT" | grep -Eiq 'noreply@anthropic\.com|noreply@openai\.com'; then
	fail "AI vendor no-reply address found"
fi
if printf '%s\n' "$TEXT" | grep -q '🤖'; then
	fail "robot emoji marker found"
fi

if [ "$STATUS" -ne 0 ]; then
	cat >&2 <<'EOF'

This text becomes part of a commit message on main, and AI-attribution markers
are not permitted there. See CONTRIBUTING.md#commit-messages.

Disclose AI assistance in prose in the PR description instead, e.g.
"Drafted with AI assistance; reviewed and tested by me."
EOF
fi

exit "$STATUS"
