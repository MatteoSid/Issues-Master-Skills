#!/usr/bin/env bash
# footprint.sh — the files an issue's Plan names: what a session working on it may touch.
#
#   footprint.sh <n> [<n>…]      from the tracker (GitLab or GitHub, from the remote)
#   footprint.sh --file <body.md> from a body already on disk
#
# One path per line, sorted, `path:line` references reduced to the path. For a [ROADMAP] parent
# the footprint is the union of its still open children's, each line prefixed by `#<child> `.
# It is an approximation read from the text — the backticked paths of the Plan section —, good
# enough to see where two pieces of work meet; the session that runs the issue knows better.

set -u
die() { echo "footprint.sh: $*" >&2; exit 2; }

body_of() {
  case "$(git remote get-url origin 2>/dev/null)" in
    *github*) gh issue view "$1" --json body --jq '.body' 2>/dev/null | sed 's/\r$//' ;;
    *gitlab*) glab issue view "$1" --output json 2>/dev/null | jq -r '.description // empty' ;;
    *) die "the remote is neither GitHub nor GitLab" ;;
  esac
}

# the Plan section (## Piano in 1.x issues), or the whole body if it has none
plan_of() {
  local plan
  plan=$(awk '/^## /{inside = ($0 ~ /^## (Plan|Piano)/)} inside' <<<"$1")
  [ -n "$plan" ] && printf '%s\n' "$plan" || printf '%s\n' "$1"
}

paths_of() {
  grep -oE '`[^`]+`' <<<"$1" | tr -d '`' \
    | grep -E '^[A-Za-z0-9_@./-]+(:[0-9]+)?$' | grep -E '/|\.' \
    | grep -vE '^\.+$|^[0-9.]+$' | sed -E 's/:[0-9]+$//' | sort -u
}

footprint_of_body() {
  local body=$1 n=$2 child
  if grep -qE '^\*\*(Type|Tipo):\*\* *roadmap' <<<"$body" || grep -qE '^- \*\*(Type|Tipo):\*\* *roadmap' <<<"$body"; then
    for child in $(grep -oE '^[[:space:]]*- \[ \] #[0-9]+' <<<"$body" | grep -oE '[0-9]+$'); do
      paths_of "$(plan_of "$(body_of "$child")")" | sed "s/^/#$child /"
    done
  else
    paths_of "$(plan_of "$body")"
  fi
}

[ $# -gt 0 ] || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
if [ "$1" = --file ]; then
  [ -f "${2:-}" ] || die "--file <body.md>"
  footprint_of_body "$(sed 's/\r$//' "$2")" file
else
  for n in "$@"; do
    [[ "$n" =~ ^[0-9]+$ ]] || die "not an issue number: $n"
    body=$(body_of "$n"); [ -n "$body" ] || die "cannot read issue #$n from the tracker"
    footprint_of_body "$body" "$n"
  done
fi
