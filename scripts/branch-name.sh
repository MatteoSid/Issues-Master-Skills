#!/usr/bin/env bash
# branch-name.sh — the one place where issue-flow's branch names are decided.
#
#   branch-name.sh issue <n> [<title>]     the branch of issue <n>:  issue-<n>-<short description>
#   branch-name.sh roadmap <n> [<title>]   the parent branch of a [ROADMAP] issue: roadmap-<n>-<short description>
#   branch-name.sh number [<branch>]       the issue number a branch name carries (default: the current branch)
#
# The prefixes come from the plugin's configuration, passed as environment variables:
# BRANCH_PREFIX (default `issue-`) and ROADMAP_PREFIX (default `roadmap-`).
#
# A branch that already exists wins: local or on origin, `<prefix><n>-*` — or the plain
# `<prefix><n>` of issues started before 2.2 —, phase worktree branches (`…-phase-3`) excluded.
# Otherwise the name is built from the issue's title, read from the tracker when not given:
# lowercase ASCII, words joined by `-`, cut at 40 characters on a word boundary.

set -u
BRANCH_PREFIX=${BRANCH_PREFIX:-issue-}
ROADMAP_PREFIX=${ROADMAP_PREFIX:-roadmap-}

die() { echo "branch-name.sh: $*" >&2; exit 2; }

tracker() {
  case "$(git remote get-url origin 2>/dev/null)" in
    *github*) echo gh ;;
    *gitlab*) echo glab ;;
    *) echo "" ;;
  esac
}

title_of() {                                       # from the tracker, empty if it cannot be read
  case "$(tracker)" in
    gh)   gh issue view "$1" --json title --jq '.title' 2>/dev/null ;;
    glab) glab issue view "$1" --output json 2>/dev/null | jq -r '.title // empty' ;;
  esac
}

slug() {
  local s=$1
  s=$(sed -E 's/^\[[^]]*\][[:space:]]*//' <<<"$s")                     # drop a leading [ROADMAP]
  s=$(printf '%s' "$s" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null || printf '%s' "$s")
  s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  if [ "${#s}" -gt 40 ]; then
    s=${s:0:40}; s=${s%-*}                                              # cut on a word boundary
  fi
  printf '%s' "$s"
}

existing() {                                       # $1 prefix, $2 number → the branch already there, if any
  git for-each-ref --format='%(refname:short)' \
      "refs/heads/$1$2" "refs/heads/$1$2-*" "refs/remotes/origin/$1$2" "refs/remotes/origin/$1$2-*" 2>/dev/null \
    | sed 's#^origin/##' | grep -vE -- '-phase-[0-9]+$' | awk '!seen[$0]++'
}

cmd_name() {
  local prefix=$1 n=$2 title=${3:-} found s
  [[ "$n" =~ ^[0-9]+$ ]] || die "the issue number must be a number"
  found=$(existing "$prefix" "$n")
  if [ -n "$found" ]; then
    if [ "$(wc -l <<<"$found")" -gt 1 ]; then
      echo "branch-name.sh: several branches for #$n, taking the first: $(tr '\n' ' ' <<<"$found")" >&2
    fi
    head -1 <<<"$found"; return
  fi
  [ -n "$title" ] || title=$(title_of "$n")
  s=$(slug "$title")
  if [ -n "$s" ]; then echo "$prefix$n-$s"; else echo "$prefix$n"; fi
}

cmd_number() {
  local branch=${1:-$(git branch --show-current 2>/dev/null)} p r
  p=$(sed 's/[][\.*^$/]/\\&/g' <<<"$BRANCH_PREFIX"); r=$(sed 's/[][\.*^$/]/\\&/g' <<<"$ROADMAP_PREFIX")
  sed -nE "s/^($p|$r)([0-9]+)(-.*)?$/\2/p" <<<"$branch" | grep . || exit 1
}

case "${1:-}" in
  issue)   shift; cmd_name "$BRANCH_PREFIX" "$@" ;;
  roadmap) shift; cmd_name "$ROADMAP_PREFIX" "$@" ;;
  number)  shift; cmd_number "$@" ;;
  *) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
