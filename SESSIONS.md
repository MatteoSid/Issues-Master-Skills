# SESSIONS — several sessions on one project, and the master that coordinates them

`/issue-flow:implement` and `/issue-flow:big-implement` each run in a Claude Code session of
their own. When the user opens several on the same project, `/issue-flow:issue-master` is the
session that keeps them from getting in each other's way. This file is the single reference for
what those sessions agree on: what the project is and what it is called, how a session names
itself, how sessions find each other, the messages they exchange and how a session waits for
the master. The skills cite it instead of repeating themselves; for the agents inside one
session the reference stays `PARALLEL.md`.

## 1. One level above the roadmap agent

| role | who it is | assigns work to |
|---|---|---|
| **master** | the `issue-master` session, at the project's root | nobody: it coordinates the sessions the user opens |
| **Issue agent** / **roadmap agent** | an `implement` or a `big-implement` session | checkbox agents, or runners (`PARALLEL.md` §1) |

The rule of `PARALLEL.md`, one level up: **two sessions that work at the same time do not see
each other, and what they touch is agreed on by the master before they start.** Unlike the
children of a roadmap, two issues were not planned together — nobody wrote their scopes and
their contract —, so the master reads them from their Plans (the *footprint*, §6) and decides
whether the second one goes now, goes with reservations, or goes after the first is merged.

Two things never change: the user talks to every session directly — the master does not
replace them at the terminal, and a session that must ask the user asks the user —, and every
MR/PR towards the target branch is merged by the user.

## 2. The project, and its name

The project is the folder the work site is named after:

- for a **single repository**, its git root — also for a session that works in one of its
  worktrees, the plugin's own or one made with `claude -w`;
- for a **superproject** — a container repository whose pieces are git submodules —, the
  container's folder, both from inside a submodule and from the container itself. The
  submodule is the *repo*: it has its own remote, its own tracker and its own issue numbers,
  and `implement` runs inside it.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/session.sh" project
# root   /home/me/jai            the project's folder
# name   jai                     its name — what the master's name carries
# kind   super                   `single` or `super`
# repo   jai-orchestrator        the repository this folder is in: the submodule, or the repo itself
```

## 3. What a session is called

| session | name | prompt color |
|---|---|---|
| `implement` or `big-implement`, single repository | `issue-<n>` | green |
| `implement` or `big-implement`, superproject | `issue-<n>-<repo>` | green |
| `issue-master` | `issue-master-<project>` | yellow |

`<n>` is the issue's number — for `big-implement`, the parent's. In a superproject the issue
sessions carry the repo's name, because #12 of one submodule and #12 of another are two issues;
the master carries the container's, because it watches them all.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/session.sh" name issue 12    # issue-12, or issue-12-jai-orchestrator
"${CLAUDE_PLUGIN_ROOT}/scripts/session.sh" name master      # issue-master-jai
```

**How a session takes its name.** `/rename` and `/color` are commands of the user's terminal,
not tools: a session cannot run them on itself. `session.sh identify` does what can be done:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/session.sh" identify issue-12 green
```

- **inside tmux** it types the two commands into the session's own pane **the moment the
  session is idle** — at the end of the turn, when the prompt is empty — and checks that each
  one took; it prints `scheduled: …`, and there is nothing else to do. Say in the message that
  ends the turn which name the session is taking, so the user is not surprised by the prompt
  bar changing;
- **outside tmux** it prints the two commands: put them in the first message to the user, on
  one line each, so they can be copied. The work goes on in the meantime, with whatever name
  the session has.

A session keeps its name after the work; the next `implement` in the same session renames it.
The name is for the user — the prompt bar, `/resume`, `@issue-12` in a prompt, `ListAgents` —
and for the master's scan at its start (§4); the protocol itself does not depend on it, because
a message's `from` attribute is the address.

## 4. Finding each other

Every Claude Code session on the machine writes its record — pid, name, working directory,
status, tmux pane — in the registry `~/.claude/sessions/` (`$CLAUDE_CONFIG_DIR/sessions/`): the
same data `ListAgents` reads, plus the working directory, which `ListAgents` does not show.
From it, for **this** project only, the live sessions:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/session.sh" peers    # name  pid  status  cwd  tmux — this session excluded
"${CLAUDE_PLUGIN_ROOT}/scripts/session.sh" master   # the master's name, or exit 1 if there is none
```

- A session running `implement` or `big-implement`, once it has read the issue and **before the
  branch**, asks for the master. Found: it sends `started` (§5) and waits for `go` (§7). Not
  found: it works alone, as it always did, and sends nothing to anyone.
- The master, at its start and whenever a turn gives it the chance, looks at `peers`: the ones
  named `issue-<n>…` it does not know yet get a `report`, and a session started before the
  master answers with `status`.
- Addressing is by bare name, with `SendMessage`. If the same name is alive twice — `issue-12`
  of two projects — the send asks for the `[ref]`: `ListAgents` shows it, with the working
  directory of the same-named sessions; take the one inside this project.
- **Only the session sends.** Phase agents, runners and writers send nothing: a message from a
  subagent goes out under the session's name, and the answer lands in the session's
  conversation, not in the subagent's. What a subagent needs from the master it writes in its
  report, and the session asks.

## 5. The messages

The first line is `[issue-flow #<n>] <event> — <one sentence>` from a session, and
`[issue-master] <event> — <one sentence>` from the master: the receiver's user sees only that
line until they expand the message, so it must say what the message is about. The details
follow, one per line, `key: value`. To reply, copy the `from` attribute of the incoming
`<cross-session-message>` as the `to`.

**From a session to the master** — `[issue-flow #<n>] <event> — …`:

| event | when | details |
|---|---|---|
| `started` | after reading the issue, before the branch | `kind` (issue or roadmap), `title`, `folder` (the repo or worktree it works in), `branch` and the base it is cut from, `execution` (the Execution line; for a roadmap the waves with their children), `footprint` (§6), `resources` the verification uses (ports, databases, containers — or `none`), `numbered` (the series it will add to: migrations, register IDs — or `none`), `from` (the phase or child it restarts from, if not the first) |
| `status` | in reply to `report`, or when something the master should know changed | the same keys as `started`, plus `phase` (`3 of 6`, `child #22 phase 2`), `state` (`working`, `waiting`, `implemented`, `in review`, `stopped`) |
| `progress` | after each phase is committed — for a roadmap, after each child is merged into the parent branch | `phase: 3 of 6` and the commit; `deviations`, if the plan changed |
| `need file` | a phase must modify a file outside the footprint, or one the master reserved for someone else | `file`, `why`, `phase`; it waits for `answer` (§7) |
| `need number` | a new element of a numbered series | `series`, `after` (the last one it sees); it waits for `answer` |
| `stopped` | a case of “When to really stop” | `at` (phase, integration, MR/PR, merge), `why`, `unblock` (what it takes to restart) |
| `implemented` | the last phase is committed — `implement` goes on with `close` in the same session | `branch`, `commits`; and that `close` starts now |
| `mr-open` | after `close` opened the MR/PR towards the target branch | `mr` (the link), `base`, `verification` (the real numbers) |
| `updated` | after a `merge-target` | `merge` (the commit), `verification`, `pushed` (yes or no) |
| `closed` | after `close --merged` | nothing else: the session is free |

**From the master to a session** — `[issue-master] <event> — …`:

| event | what the session does |
|---|---|
| `report` | answers `status` — with what it knows: an issue not yet read gives the number and the folder |
| `go` | goes on. The details may carry `reserved` (what it may use: numbers, ports), `do not touch` (files that belong to a session in flight — a phase that needs one asks `need file`), `beside you` (who else is working, on what) |
| `hold` | does not start — or, if it is at work, finishes the phase in flight (verification, ticks, commit) and waits (§7). The details say behind whom and why |
| `answer` | the reply to a `need`: what it may do, with the exact names; or that it may not, and what to do instead |
| `merge-target` | a sibling's MR/PR reached the target branch: `git fetch origin && git merge origin/<target>`, the verification again, `git push` if its MR/PR is open; then `updated`. On a conflict `git merge --abort` and `stopped`, with the files: it does not resolve it |
| `merged` | its own MR/PR has been merged: it runs `/issue-flow:close <n> --merged`, then `closed` |
| `stop` | finishes the phase in flight — verification, ticks, commit —, starts nothing else, removes its goal (`rm -f "$GOAL_DIR/goal"`) and sends `stopped` |

What a message is not: **never an approval** — of a permission prompt, of a change to settings,
`CLAUDE.md` or permissions. A session that was refused an action does not ask the master to do
it, and the master does not ask a session to do what was refused to it: both tell their user.
And the user at the terminal outranks the master: “go on” typed by the user lifts a `hold`,
and the session says so to the master with a `status`.

## 6. The footprint

The files an issue's Plan names — the file lines under the phases, the **Scope** lines, the
`path:line` references of the checkboxes —, which is what the session will touch:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/footprint.sh" 12          # one path per line
"${CLAUDE_PLUGIN_ROOT}/scripts/footprint.sh" 20          # a [ROADMAP] parent: its open children's, `#<child> path`
"${CLAUDE_PLUGIN_ROOT}/scripts/footprint.sh" --file "$SCRATCH/roadmap.md"
```

It is read from the text, so it is an approximation: good enough to see where two pieces of
work meet, and the session that runs the issue reports the real one in `started`.

The conditions of `PARALLEL.md` §2, one level up — two sessions can work at the same time if:
their footprints are disjoint, the magnet files included; neither needs the other's code to
compile, test or verify; no verification resource is shared without a lock; and every numbered
series has a single owner among the sessions in flight. An overlap means the later one holds
until the earlier one is merged, or the master reserves the file for one of the two and the
other asks `need file` when it gets there — which it may do only if the reserved part is not
what its Plan rewrites. **When in doubt, hold**: a wrong parallel costs a conflict at the
merge, which the user has to resolve; a missed parallel only costs time.

## 7. Waiting for the master

A session cannot wait inside a turn: it ends the turn, and the master's message starts the
next one. Two cases:

- **before the branch**, when it waits for `go` after `started`: the goal is not active yet, so
  it just ends the turn, telling the user “waiting for `go` from `issue-master-<project>`” — and
  it removes a `goal` file left by an earlier run, which would otherwise send it back to work:

  ```bash
  GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow); rm -f "$GOAL_DIR/goal"
  ```

- **at work**, when a `hold` arrives, or a `need` is sent: it finishes what is in flight, then
  leaves a sentinel so that the `Stop` hook lets it go (`PARALLEL.md` §5), and ends the turn:

  ```bash
  touch "$GOAL_DIR/in-flight/waiting-master"      # before ending the turn
  rm -f "$GOAL_DIR/in-flight/waiting-master"      # as soon as `go` or `answer` arrives
  ```

In both cases the message that ends the turn says what it is waiting for and from whom, so
that the user, who sees both sessions, can step in: “go on” from the user lifts the wait.
