#!/usr/bin/env bash
# session.sh — the session-level helpers of issue-flow (SESSIONS.md).
#
#   session.sh project                   the project this folder belongs to: root, name, kind, repo
#   session.sh name issue <n>            the session name for issue <n> here: issue-<n>, or
#                                        issue-<n>-<repo> when the project is a superproject
#   session.sh name master               the session name of this project's master: issue-master-<project>
#   session.sh peers                     the live Claude Code sessions of this project, from the
#                                        registry: name, pid, status, cwd, tmux pane — this one excluded
#   session.sh master                    the live master session of this project: its name, or exit 1
#   session.sh identify <name> <color>   rename this session and set its prompt color. Inside tmux it
#                                        is done for you as soon as the session is idle; outside, it
#                                        prints the two commands the user has to type
#
# "Project" is the folder whose name identifies the work site: the git root of a single repo —
# also for a session in one of its worktrees — or, for a superproject, the folder that holds the
# submodules, both from inside a submodule and from the container itself. kind is `single` or
# `super`; repo is the repository the folder is in (the submodule's name, in a superproject).
#
# The registry is the folder where every Claude Code session on this machine writes its record
# (pid, name, cwd, status): ~/.claude/sessions/, or $CLAUDE_CONFIG_DIR/sessions/. It is what
# ListAgents reads too; this script adds the cwd, which ListAgents does not show.

set -u

REG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
MASTER_PREFIX="issue-master"

die() { echo "session.sh: $*" >&2; exit 2; }

# project_of <folder> → root<TAB>name<TAB>kind<TAB>repo ; exit 1 if not a git folder
project_of() {
  local dir=$1 top super common root kind
  top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
  super=$(git -C "$dir" rev-parse --show-superproject-working-tree 2>/dev/null)
  if [ -n "$super" ]; then
    root=$super; kind=super
  else
    common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
    root=$(dirname "$common")
    if [ -f "$root/.gitmodules" ]; then kind=super; else kind=single; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$root" "$(basename "$root")" "$kind" "$(basename "$top")"
}

here() {
  HERE=$(project_of "$PWD") || die "$PWD is not inside a git repository"
  IFS=$'\t' read -r ROOT NAME KIND REPO <<<"$HERE"
}

cmd_project() {
  here
  printf 'root\t%s\nname\t%s\nkind\t%s\nrepo\t%s\n' "$ROOT" "$NAME" "$KIND" "$REPO"
}

cmd_name() {
  here
  case "${1:-}" in
    issue)
      [[ "${2:-}" =~ ^[0-9]+$ ]] || die "name issue <number>"
      if [ "$KIND" = super ]; then echo "issue-$2-$REPO"; else echo "issue-$2"; fi ;;
    master) echo "$MASTER_PREFIX-$NAME" ;;
    *) die "name issue <n> | name master" ;;
  esac
}

# every live session of this project, this one excluded: name<TAB>pid<TAB>status<TAB>cwd<TAB>tmux
list_peers() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
  here
  local f pid name cwd status tmux proot
  for f in "$REG"/*.json; do
    [ -f "$f" ] || continue
    pid=$(jq -r '.pid // empty' "$f" 2>/dev/null); [ -n "$pid" ] || continue
    [ "$pid" = "${CLAUDE_PID:-}" ] && continue
    kill -0 "$pid" 2>/dev/null || continue                      # stale record of a session that is gone
    cwd=$(jq -r '.cwd // empty' "$f"); [ -d "$cwd" ] || continue
    proot=$(project_of "$cwd" 2>/dev/null | cut -f1); [ "$proot" = "$ROOT" ] || continue
    name=$(jq -r '.name // empty' "$f"); status=$(jq -r '.status // empty' "$f"); tmux=$(jq -r '.tmux // empty' "$f")
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$pid" "$status" "$cwd" "$tmux"
  done
}

cmd_peers() { list_peers | sort; }

cmd_master() {
  local line
  line=$(list_peers | awk -F'\t' -v p="$MASTER_PREFIX" '$1 == p || index($1, p "-") == 1' | head -1)
  [ -n "$line" ] || exit 1
  cut -f1 <<<"$line"
}

# ---- identify: /rename and /color through tmux, when the session is idle -------------------

# the prompt line of the pane is empty: nothing typed, at most the placeholder hint
prompt_empty() {
  local line
  # the prompt is followed by a no-break space (c2 a0), turned into a plain one before matching
  line=$(tmux capture-pane -p -t "$1" 2>/dev/null | LC_ALL=C sed 's/\xc2\xa0/ /g' | grep -E '^(❯|>)' | tail -1 | sed -E 's/^(❯|>)//')
  [ -n "$line" ] || return 1                                       # no prompt on screen: a dialog, or scrolled away
  [[ "$line" =~ ^\ *$ ]] || [[ "$line" =~ ^\ *Try\ \" ]]
}

# the detached waiter: polls the registry until the session is idle and the prompt is empty,
# then types the commands and checks each one took; gives up after a while
wait_and_type() {
  local name=$1 color=$2 pane=$3 reg=$4 tries=0 deadline=$((SECONDS + 3600)) current
  while [ "$SECONDS" -lt "$deadline" ] && [ "$tries" -lt 6 ]; do
    [ -f "$reg" ] || exit 0                                        # the session ended
    if [ "$(jq -r '.status // empty' "$reg" 2>/dev/null)" = idle ] && prompt_empty "$pane"; then
      tries=$((tries + 1))
      current=$(jq -r '.name // empty' "$reg")
      if [ "$current" != "$name" ]; then
        tmux send-keys -t "$pane" "/rename $name" Enter
        sleep 4
        [ "$(jq -r '.name // empty' "$reg")" = "$name" ] || { sleep 10; continue; }
      fi
      if [ -n "$color" ]; then
        tmux send-keys -t "$pane" "/color $color" Enter
        sleep 4
        tmux capture-pane -p -t "$pane" | grep -q "Session color set to: $color" || { sleep 10; continue; }
      fi
      exit 0
    fi
    sleep 2
  done
  exit 1
}

cmd_identify() {
  local name=${1:-} color=${2:-} reg pane current
  [ -n "$name" ] || die "identify <name> [<color>]"
  command -v jq >/dev/null 2>&1 || die "jq is required"
  reg="$REG/${CLAUDE_PID:-0}.json"
  current=$(jq -r '.name // empty' "$reg" 2>/dev/null)
  pane=${TMUX_PANE:-$(jq -r '.tmux // empty' "$reg" 2>/dev/null | sed 's/.*\.//')}
  if [ -n "$pane" ] && command -v tmux >/dev/null 2>&1 && tmux display-message -p -t "$pane" '#{pane_id}' >/dev/null 2>&1; then
    pkill -f "^bash .*session.sh __wait .* $reg\$" 2>/dev/null          # one waiter per session
    LC_ALL=C.UTF-8 setsid nohup bash "$0" __wait "$name" "$color" "$pane" "$reg" >/dev/null 2>&1 </dev/null &
    echo "scheduled: this session becomes \"$name\"${color:+ in $color} as soon as it is idle (now: \"${current:-?}\")"
  else
    echo "not in tmux: ask the user to type these two commands"
    echo "/rename $name"
    [ -n "$color" ] && echo "/color $color"
  fi
}

case "${1:-}" in
  project)  cmd_project ;;
  name)     shift; cmd_name "$@" ;;
  peers)    cmd_peers ;;
  master)   cmd_master ;;
  identify) shift; cmd_identify "$@" ;;
  __wait)   shift; wait_and_type "$@" ;;
  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
