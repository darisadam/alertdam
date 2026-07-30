#!/bin/sh
# Enforce the author-conditional review policy, and publish the result as a
# commit status named `review-policy` on the pull request's head commit.
#
# WHY THIS EXISTS
#
# The requirements are:
#   - the maintainer can open a PR and merge it with no approvals;
#   - an outside contributor's PR needs CI green *and* maintainer approval.
#
# GitHub cannot express that natively on a personal-account repository: an
# approval count applies to every PR regardless of author, and GitHub forbids
# approving your own PR — so `required_approving_review_count: 1` would lock the
# sole maintainer out permanently (which is exactly the bug this repository had).
#
# The obvious workaround — a second ruleset the admin bypasses — puts the only
# thing enforcing the external-contributor rule behind the only bypass in the
# system. GitHub's own wording for that bypass mode is that the actor "can then
# choose to bypass any branch protections", which is a blast radius nobody should
# rely on.
#
# So the rule lives here instead, as a required status check with no bypass
# actors anywhere. It also closes a hole the native rule cannot: it stops the
# maintainer from merging an external PR they never actually reviewed.
#
# FAIL-CLOSED: any unexpected state, any API error, any unknown author
# association results in a failing status. A check that errors open would be
# worse than no check at all.
#
# Required environment:
#   GH_TOKEN, REPO, PR_NUMBER, HEAD_SHA, AUTHOR_LOGIN, AUTHOR_ASSOCIATION

set -eu

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
: "${AUTHOR_LOGIN:?AUTHOR_LOGIN is required}"
: "${AUTHOR_ASSOCIATION:?AUTHOR_ASSOCIATION is required}"

CONTEXT='review-policy'
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${REPO}/actions/runs/${GITHUB_RUN_ID:-0}"

publish() {
	state=$1
	description=$2
	# Commit-status descriptions are truncated at 140 characters.
	gh api --method POST "repos/$REPO/statuses/$HEAD_SHA" \
		-f state="$state" \
		-f context="$CONTEXT" \
		-f description="$(printf '%.140s' "$description")" \
		-f target_url="$RUN_URL" \
		--silent
	echo "published status: $state — $description"
}

pass() { publish success "$1"; exit 0; }
deny() { publish failure "$1"; echo "::error::$1"; exit 1; }

# Anything unexpected below this point should fail the check, not skip it.
trap 'publish error "review-policy could not be evaluated; see the workflow log"' EXIT

# ---------------------------------------------------------------------------
# Maintainers come from the CODEOWNERS catch-all rule, so there is one source of
# truth for who can approve.
# ---------------------------------------------------------------------------
if [ ! -f .github/CODEOWNERS ]; then
	trap - EXIT
	deny "no .github/CODEOWNERS file — cannot determine who may approve"
fi

MAINTAINERS=$(awk '$1 == "*" { for (i = 2; i <= NF; i++) if ($i ~ /^@/) print substr($i, 2) }' \
	.github/CODEOWNERS | sort -u)

if [ -z "$MAINTAINERS" ]; then
	trap - EXIT
	deny "CODEOWNERS has no '*' catch-all owners — cannot determine who may approve"
fi

echo "maintainers: $(printf '%s' "$MAINTAINERS" | tr '\n' ' ')"
echo "PR #$PR_NUMBER by $AUTHOR_LOGIN (association: $AUTHOR_ASSOCIATION), head $HEAD_SHA"

# ---------------------------------------------------------------------------
# Trusted authors need no approval.
#
# OWNER      — the account that owns the repository
# MEMBER     — a member of the owning organisation
# COLLABORATOR — granted push access explicitly
#
# Everything else (CONTRIBUTOR, FIRST_TIME_CONTRIBUTOR, FIRST_TIMER, NONE, MANNEQUIN)
# requires a maintainer approval.
# ---------------------------------------------------------------------------
case "$AUTHOR_ASSOCIATION" in
	OWNER|MEMBER|COLLABORATOR)
		# Belt and braces: the association must also correspond to a real
		# maintainer or an actual push-capable collaborator.
		if printf '%s\n' "$MAINTAINERS" | grep -Fxq "$AUTHOR_LOGIN"; then
			trap - EXIT
			pass "author $AUTHOR_LOGIN is a maintainer; no approval required"
		fi
		if gh api "repos/$REPO/collaborators/$AUTHOR_LOGIN/permission" \
			--jq '.permission' 2>/dev/null | grep -Eq '^(admin|maintain|write)$'; then
			trap - EXIT
			pass "author $AUTHOR_LOGIN has write access; no approval required"
		fi
		trap - EXIT
		deny "author association is $AUTHOR_ASSOCIATION but $AUTHOR_LOGIN has no write access — maintainer approval required"
		;;
esac

# ---------------------------------------------------------------------------
# Outside contributor: require an approving review from a maintainer, on the
# current head commit.
# ---------------------------------------------------------------------------
REVIEWS=$(gh api --paginate "repos/$REPO/pulls/$PR_NUMBER/reviews" \
	--jq '.[] | [.user.login, .state, (.commit_id // "")] | @tsv' || true)

if [ -z "$REVIEWS" ]; then
	trap - EXIT
	deny "external PR needs an approving review from a maintainer (none submitted yet)"
fi

APPROVER=''
STALE_APPROVER=''

# Later reviews supersede earlier ones from the same user, so walk in order and
# keep the last state per maintainer.
while IFS="$(printf '\t')" read -r login state commit_id; do
	[ -z "${login:-}" ] && continue
	printf '%s\n' "$MAINTAINERS" | grep -Fxq "$login" || continue

	case "$state" in
		APPROVED)
			if [ "$commit_id" = "$HEAD_SHA" ]; then
				APPROVER="$login"
			else
				STALE_APPROVER="$login"
			fi
			;;
		CHANGES_REQUESTED)
			trap - EXIT
			deny "maintainer $login requested changes"
			;;
		DISMISSED)
			[ "$APPROVER" = "$login" ] && APPROVER=''
			;;
	esac
done <<EOF
$REVIEWS
EOF

if [ -n "$APPROVER" ]; then
	trap - EXIT
	pass "approved by maintainer $APPROVER on the current head commit"
fi

if [ -n "$STALE_APPROVER" ]; then
	trap - EXIT
	deny "approval from $STALE_APPROVER is stale — new commits were pushed after it; re-approval required"
fi

trap - EXIT
deny "external PR needs an approving review from a maintainer"
