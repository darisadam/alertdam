#!/bin/sh
# Tests for commit-msg-lint.sh.
#
# The validator is the only thing standing between the project and a mangled
# history, and it is a pile of regexes — so it gets a test suite. Run locally
# with `sh scripts/git/commit-msg-lint_test.sh`; CI runs it in the Conventions job.

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
LINT="$SCRIPT_DIR/commit-msg-lint.sh"

PASS=0
FAIL=0

# Unset any ambient escape hatch so the tests exercise the real thing.
unset SKIP_COMMIT_LINT 2>/dev/null || true
unset COMMIT_AUTHOR 2>/dev/null || true

ok() {
	desc=$1
	msg=$2
	if printf '%s' "$msg" | sh "$LINT" --stdin >/dev/null 2>&1; then
		PASS=$((PASS + 1))
	else
		FAIL=$((FAIL + 1))
		printf 'FAIL (expected accept) %s\n      message: %s\n' "$desc" "$(printf '%s' "$msg" | head -1)"
	fi
}

no() {
	desc=$1
	msg=$2
	if printf '%s' "$msg" | sh "$LINT" --stdin >/dev/null 2>&1; then
		FAIL=$((FAIL + 1))
		printf 'FAIL (expected reject) %s\n      message: %s\n' "$desc" "$(printf '%s' "$msg" | head -1)"
	else
		PASS=$((PASS + 1))
	fi
}

# --- accepted ---------------------------------------------------------------
ok "plain type"                 'feat: add discord integration'
ok "with scope"                 'fix(escalation): prevent duplicate notifications on retry'
ok "nested scope"               'feat(chat/slack): add acknowledge button'
ok "scope with dots"            'chore(deps.go): bump chi'
ok "all types accepted"         'refactor: extract dedup key builder'
ok "docs"                       'docs: add self-hosting guide'
ok "style"                      'style: apply gofumpt'
ok "perf"                       'perf(queue): batch notify payloads'
ok "test"                       'test(alert): cover malformed payloads'
ok "build"                      'build(docker): cross-compile via TARGETARCH'
ok "ci"                         'ci: add codeql workflow'
ok "revert type"                'revert: feat(slack): add acknowledge button'
ok "breaking with footer"       'feat!: drop v1 events endpoint

BREAKING CHANGE: POST /v1/events is replaced by /v2/events.'
ok "body and footer"            'fix(api): return 400 on empty routing_key

Previously an empty routing_key produced a 202 and the event was dropped.

Closes #42'
ok "exactly 72 chars"           'feat(scheduling): add multi-timezone rotation handoff support xxxxx'
ok "merge commit exempt"        'Merge branch main into feat/x'
ok "revert commit exempt"       'Revert "feat: add thing"'
ok "fixup exempt"               'fixup! feat: add thing'
ok "comments are stripped"      'feat: add thing
# this comment line is ignored'
ok "scissors content ignored"   'feat: add thing
# ------------------------ >8 ------------------------
diff --git a/x b/x
Co-authored-by: Claude <noreply@anthropic.com>'

# --- rejected: format -------------------------------------------------------
no "no type"                    'update feature'
no "unknown type"               'feature: add discord integration'
no "uppercase type"            'Feat: add discord integration'
no "missing colon"              'feat add discord integration'
no "missing space after colon"  'feat:add discord integration'
no "empty description"          'feat: '
no "empty message"              ''
no "uppercase scope"            'feat(Slack): add button'
no "trailing period"            'feat: add discord integration.'
no "capitalised description"    'feat: Add discord integration'
no "too long"                   'feat(scheduling): add support for multi-timezone rotation handoffs and overrides'

# --- rejected: mood ---------------------------------------------------------
no "past tense"                 'feat: added discord integration'
no "third person"               'fix: fixes the retry loop'
no "gerund"                     'chore: updating dependencies'

# --- rejected: breaking without footer -------------------------------------
no "bang without footer"        'feat!: drop v1 events endpoint'
no "bang with scope, no footer" 'feat(api)!: drop v1 events endpoint'

# --- rejected: AI attribution ----------------------------------------------
no "co-authored claude"         'feat: add thing

Co-Authored-By: Claude <noreply@anthropic.com>'
no "co-authored lowercase"      'feat: add thing

co-authored-by: claude opus <x@y.z>'
no "co-authored copilot"        'feat: add thing

Co-authored-by: GitHub Copilot <copilot@github.com>'
no "generated with claude code" 'feat: add thing

🤖 Generated with [Claude Code](https://claude.com/claude-code)'
no "generated with, no emoji"   'feat: add thing

Generated with Claude Code'
no "anthropic noreply anywhere" 'feat: add thing

Reported-by: someone <noreply@anthropic.com>'
no "robot emoji"                'feat: add thing

🤖 automated'
no "assisted-by chatgpt"        'feat: add thing

Assisted-by: ChatGPT'

# --- exemptions -------------------------------------------------------------
# NOTE: the env var must be set on the *script* invocation, not on `printf` —
# `VAR=x printf ... | sh script` exports VAR to printf only.
if printf '%s' 'chore(deps): bump the go-minor-patch group with 5 updates across 3 directories' \
	| COMMIT_AUTHOR='dependabot[bot]' sh "$LINT" --stdin >/dev/null 2>&1; then
	PASS=$((PASS + 1))
else
	FAIL=$((FAIL + 1))
	echo 'FAIL (expected accept) dependabot author is exempt'
fi

if printf '%s' 'totally invalid' | SKIP_COMMIT_LINT=1 sh "$LINT" --stdin >/dev/null 2>&1; then
	PASS=$((PASS + 1))
else
	FAIL=$((FAIL + 1))
	echo 'FAIL (expected accept) SKIP_COMMIT_LINT escape hatch'
fi

# And the inverse: without the exemption, that same dependabot subject is too
# long, which is exactly why the exemption exists.
no "long subject without bot exemption" 'chore(deps): bump the go-minor-patch group with 5 updates across 3 directories'

# --- summary ----------------------------------------------------------------
printf '\ncommit-msg-lint: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
