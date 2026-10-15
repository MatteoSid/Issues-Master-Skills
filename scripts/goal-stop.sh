#!/usr/bin/env bash
# Stop hook of /issue-flow:implement and /issue-flow:big-implement: the roadmap's "goal".
#
# It does not let the turn end while one of the issues being worked on has open boxes in its Plan.
# The state lives in <git-dir>/issue-flow/, never committed:
#   goal       the numbers of the issues being worked on, one per line — a single one for
#              implement, all the children of the project plus the parent for big-implement
#              (the parent has no Plan: what counts are the boxes of its Issues section,
#              ticked when a child is merged into its branch); without it, the hook does nothing
#   in-flight  the folder of the subagents at work, one sentinel for each — checkbox agents for
#              implement, child runners for big-implement, possibly several at once (see
#              PARALLEL.md §5); while it is not empty, the notification of the next one to return
#              will wake the orchestrator up
#   blocks     how many times in a row the hook has blocked with the same state
#
# When in doubt it lets the turn end (exit 0): a goal that cannot be verified must not turn
# into an infinite loop.

MAX_BLOCKS=5

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD
cd "$cwd" 2>/dev/null || exit 0

dir=$(git rev-parse --path-format=absolute --git-path issue-flow 2>/dev/null) || exit 0
[ -f "$dir/goal" ] || exit 0
[ -d "$dir/in-flight" ] && [ -n "$(ls -A "$dir/in-flight" 2>/dev/null)" ] && exit 0

warn() { echo "issue-flow: $*" >&2; exit 0; }

numbers=$(grep -o '[0-9]\+' "$dir/goal")
[ -n "$numbers" ] || warn "$dir/goal contains no issue number: goal ignored"

# same choice as TRACKER.md §1: the remote tells which tracker
remote=$(git remote get-url origin 2>/dev/null)

# add up the open boxes of all the goal's issues; remember the first one that has some
open=0
first=""
for number in $numbers; do
  if [[ $remote == *github.com* ]]; then
    body=$(gh issue view "$number" --json body --jq '.body' 2>/dev/null | sed 's/\r$//')
  else
    body=$(glab issue view "$number" --output json 2>/dev/null | jq -r '.description // empty')
  fi
  [ -n "$body" ] || warn "cannot read issue #$number from the tracker: goal not verified"

  # only the Plan's boxes (## Piano in issues written by 1.x, TRACKER.md §6);
  # without a Plan section, the whole body
  plan=$(awk '/^## /{inside = ($0 ~ /^## (Plan|Piano)/)} inside' <<<"$body")
  [ -n "$plan" ] || plan=$body
  n=$(grep -c '^[[:space:]]*- \[ \]' <<<"$plan")
  if [ "$n" -gt 0 ] && [ -z "$first" ]; then
    first=$number
    phase=$(awk '/^### /{phase = substr($0, 5)} /^[[:space:]]*- \[ \]/{print phase; exit}' <<<"$plan")
  fi
  open=$((open + n))
done

if [ "$open" -eq 0 ] && [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  rm -f "$dir/goal" "$dir/blocks"
  exit 0
fi

# safety counter: if nothing changes between one block and the next, the turn is spinning
# idle and blocking it again is no use
state="$(git rev-parse HEAD 2>/dev/null) $open"
times=0
if [ -f "$dir/blocks" ] && [ "$(head -1 "$dir/blocks")" = "$state" ]; then
  times=$(sed -n 2p "$dir/blocks")
fi
times=$((times + 1))
printf '%s\n%s\n' "$state" "$times" >"$dir/blocks"
if [ "$times" -gt "$MAX_BLOCKS" ]; then
  rm -f "$dir/blocks"
  warn "#${first:-$numbers} stuck for $MAX_BLOCKS turns without progress: letting it stop"
fi

if [ "$open" -eq 0 ]; then
  reason="Roadmap fully ticked, but there are uncommitted changes: commit the last phase as /issue-flow:implement says."
else
  reason="Roadmap of #$first not complete: $open open boxes${phase:+, the first in “$phase”}. Continue as /issue-flow:implement says (or /issue-flow:big-implement, if you are carrying a project forward: the check of the children the runners have reported, the wave's integration, then the new runners for the next one)."
fi
reason+=" If you are in one of the cases of “When to really stop”, or you are leaving a box empty for a reason, remove $dir/goal and tell the user why you are stopping."

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
