#!/bin/sh
# Sync GitHub labels from .github/labels.yml.
#
# Uses only `gh` and `python3`, both preinstalled on GitHub runners — no
# third-party action, so this is one fewer entry in the repository's
# allowed-actions list and one fewer trust relationship.
#
# Usage:
#   REPO=owner/name sh scripts/ci/sync-labels.sh            # apply
#   REPO=owner/name DRY_RUN=1 sh scripts/ci/sync-labels.sh  # report only
#   REPO=owner/name PRUNE=1 sh scripts/ci/sync-labels.sh    # also delete extras
#
# PRUNE is off by default: deleting a label removes it from every issue and
# pull request that carries it, irreversibly.

set -eu

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${REPO:?REPO is required}"

MANIFEST=${MANIFEST:-.github/labels.yml}
[ -f "$MANIFEST" ] || { echo "$MANIFEST not found" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Parse the manifest without a YAML dependency: the schema is a fixed
# name/color/description triple per entry.
python3 - "$MANIFEST" > "$WORK/desired.tsv" <<'PY'
import re, sys

text = open(sys.argv[1], encoding="utf-8").read()
entries, current = [], None
for raw in text.splitlines():
    line = raw.strip()
    if line.startswith("#") or not line:
        continue
    m = re.match(r'^-\s*name:\s*"(.*)"$', line)
    if m:
        current = {"name": m.group(1), "color": "", "description": ""}
        entries.append(current)
        continue
    if current is None:
        continue
    for key in ("color", "description"):
        m = re.match(rf'^{key}:\s*"(.*)"$', line)
        if m:
            current[key] = m.group(1)

if not entries:
    sys.exit("no labels parsed from manifest")

for e in entries:
    if not e["color"]:
        sys.exit(f"label {e['name']!r} has no color")
    print("\t".join([e["name"], e["color"].lstrip("#").upper(), e["description"]]))
PY

echo "manifest declares $(wc -l < "$WORK/desired.tsv" | tr -d ' ') labels"

gh label list --repo "$REPO" --limit 200 --json name,color,description \
	--jq '.[] | [.name, (.color | ascii_upcase), (.description // "")] | @tsv' \
	> "$WORK/existing.tsv"

CREATED=0
UPDATED=0
UNCHANGED=0
DELETED=0

while IFS="$(printf '\t')" read -r name color desc; do
	[ -z "$name" ] && continue
	existing=$(awk -F'\t' -v n="$name" '$1 == n { print $2 "\t" $3; exit }' "$WORK/existing.tsv")

	if [ -z "$existing" ]; then
		echo "  + create  $name"
		CREATED=$((CREATED + 1))
		[ -n "${DRY_RUN:-}" ] || gh label create "$name" --repo "$REPO" \
			--color "$color" --description "$desc" >/dev/null
		continue
	fi

	ex_color=$(printf '%s' "$existing" | cut -f1)
	ex_desc=$(printf '%s' "$existing" | cut -f2)

	if [ "$ex_color" = "$color" ] && [ "$ex_desc" = "$desc" ]; then
		UNCHANGED=$((UNCHANGED + 1))
		continue
	fi

	echo "  ~ update  $name (color $ex_color -> $color)"
	UPDATED=$((UPDATED + 1))
	[ -n "${DRY_RUN:-}" ] || gh label edit "$name" --repo "$REPO" \
		--color "$color" --description "$desc" >/dev/null
done < "$WORK/desired.tsv"

while IFS="$(printf '\t')" read -r name _color _desc; do
	[ -z "$name" ] && continue
	if ! awk -F'\t' -v n="$name" '$1 == n { found = 1 } END { exit !found }' "$WORK/desired.tsv"; then
		if [ -n "${PRUNE:-}" ]; then
			echo "  - delete  $name"
			DELETED=$((DELETED + 1))
			[ -n "${DRY_RUN:-}" ] || gh label delete "$name" --repo "$REPO" --yes >/dev/null
		else
			echo "  ! extra   $name (not in manifest; set PRUNE=1 to delete)"
		fi
	fi
done < "$WORK/existing.tsv"

printf '\n%s: created=%d updated=%d unchanged=%d deleted=%d\n' \
	"${DRY_RUN:+DRY RUN }sync-labels" "$CREATED" "$UPDATED" "$UNCHANGED" "$DELETED"
