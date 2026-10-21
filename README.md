# Issue Flow

From the request to the merge request, by way of an issue that holds the plan **and** the
roadmap that executes it. Seven skills that hand work to each other, that put several agents
to work together where possible, and that let several sessions work on the same project at
once, on **GitLab** (`glab`) or **GitHub** (`gh`) alike: the platform is inferred from the
remote.

The principle that holds it all together: *the issue must be executable by an agent that was
not present for the conversation.* From there follow the verified `file.ts:42` references, the
numbers measured rather than estimated, the decisions written down with their reasons, the
explicit out of scope.

| skill | what it does |
|---|---|
| `/issue-flow:roadmap` | **what do we do now**: reads the project's documentation — the [research-flow](https://github.com/MatteoSid/Research-Master-Skills) registers if there are any, otherwise README, CLAUDE.md, docs — plus the open issues and the code, and proposes the next steps with their sources; once approved, saves it to `ROADMAP.md` or creates its issues with `big-plan` |
| `/issue-flow:plan` | **one feature**: reconnaissance in the code, decision points asked to the user, then opens the issue with the plan and a checkbox roadmap inside |
| `/issue-flow:big-plan` | **a big development**: defines the project's roadmap in a parent issue — `[ROADMAP] …` in the title — and splits it into child issues in waves, with scopes and contracts for those that will work together; each child is written in full by a subagent, all in parallel |
| `/issue-flow:implement` | executes the roadmap one phase per subagent — the phases of a parallel group together, each in its own worktree —, ticks the boxes as it goes, one commit per phase; works like a `/goal` and does not stop until the roadmap is complete; then goes on with `close` by itself, so the MR/PR is there for you to preview — never merged; on a parent it takes the first open child |
| `/issue-flow:big-implement` | carries all the children of a parent in one go on the parent branch: one wave at a time, the children of a wave together, each in its own worktree and handed to a subagent that does the `implement` and `close` rounds, and `close` merges it into the parent branch on its own — a squash, one commit per child, fast-forwarded —, one at a time; at the end it opens the parent's MR/PR, which you merge |
| `/issue-flow:close` | verifies the final tree, opens the MR/PR with what changes and how to see it, and once merged closes the issue and ticks it on the parent; `implement` runs it by itself at the end, on its own it redoes or resumes; the child of a project with a parent branch it squash-merges there on its own |
| `/issue-flow:issue-master` | **several sessions at once**: the session that coordinates the other sessions of the project — one terminal per issue or roadmap, each running `implement` or `big-implement` —: it finds them, agrees on what each may touch before it starts, holds the ones that would collide, hands out numbered resources, tells the others when an MR/PR is merged; it never merges |

Plus three subagents: `issue-flow:issue-phase`, the checkbox agent, which executes a single
phase and cannot commit or touch the issue — the orchestrator does that, after verifying the
real output —;
`issue-flow:issue-runner`, which for `big-implement` takes a child from the branch to the merge
into the parent branch, orchestrating its phases with one `issue-phase` each, so the main
session's context stays the project's and does not fill up with the phases of all the children;
and `issue-flow:issue-writer`, which writes the body of a `big-plan` child issue to a file and
cannot create issues: the orchestrator creates them, in order, after checking them.

## Who works together

When possible, work is parallelized: and it is decided **when planning**, not when executing.
The roadmap and the issues already say what goes together, and whoever executes re-checks it
and follows it.

| role | who it is | assigns work to |
|---|---|---|
| **roadmap agent** | `big-plan`, and at execution `big-implement` | one `issue-writer` per child; one Issue agent per child |
| **Issue agent** | `implement`, or the `issue-runner` subagent | one checkbox agent per phase |
| **checkbox agent** | the `issue-phase` subagent | — completes the checkboxes of one phase |

- **In the roadmap** the children sit in **waves**: those of a wave do not depend on each other
  and run together, and the parent has a **Parallelism** section with the scope of each — the
  files it can touch, disjoint — and the **contract** between them: the types, the interfaces,
  the formats they share, with the exact names. `/issue-flow:roadmap` also marks which steps can
  go together.
- **In every issue** the Plan opens with the **Execution** line — `1 → 2 → [3 ∥ 4] → 5 → 6` —
  and every phase of a parallel group has its own **Scope** and its own **Contract**.
- **At execution** every agent that works alongside others has its own **git worktree**, on a
  branch of its own, inside `.git/issue-flow/wt/`: nobody writes in someone else's folder. The
  phases of a group are integrated with an in-order cherry-pick, the children of a wave with
  their `close`, one at a time; after each integration the verification runs on the merged tree.

The rule that holds everything up: **the work of two agents in parallel is agreed on by the
agent that assigns it**, before assigning it. Agents in parallel do not see each other: their
work fits because scopes and contract were decided by whoever is above, and whoever is above
re-confirms them on the current code before starting. If they no longer hold, that group goes
in sequence. A conflict at integration means the agreement did not hold: nobody resolves it by
hand, everything stops and the issues get corrected. The full rules are in `PARALLEL.md`.

One level further up, the same rule holds between **sessions**: see “Several sessions at once”
below, and `SESSIONS.md`.

## Installation

```
/plugin marketplace add https://github.com/MatteoSid/Issues-Master-Skills.git
/plugin install issue-flow@issue-flow
```

`marketplace add` clones with the machine's git credentials, so SSH works too:
`git@github.com:MatteoSid/Issues-Master-Skills.git`.

You need git 2.5 or later, for worktrees. You need `glab` or `gh` installed and authenticated —
the skills check it at step 0 and stop with the command to run if it is missing. Login is
interactive and Claude cannot do it. You also need `jq`, which the `implement` hook and the
session scripts use. `tmux` is optional: with it, the sessions rename and recolor themselves;
without it, they tell you the two commands to type.

## Configuration

All options are optional: without them, the skills infer what they need from the repo. They are
set when you enable the plugin, or with `claude plugin install --config key=value`.

| option | default | what it is for |
|---|---|---|
| `default_branch` | from the repo | the branch MR/PRs are merged into |
| `branch_prefix` | `issue-` | the work branch is `<prefix><issue number>-<short description>` — `issue-12-date-filter` |
| `roadmap_prefix` | `roadmap-` | the branch of a `[ROADMAP]` parent, the one `big-implement` works on, is `<prefix><parent number>-<short description>` — `roadmap-20-notifications` |
| `verify_commands` | from the project | the commands that must pass before a phase is closed |
| `docs_paths` | from the project | the documentation the wrap-up phase re-reads |
| `max_parallel` | `3` | how many agents work together under the same agent that assigns the work: children of a wave, phases of a group; `1` turns parallelism off |
| `figma_file` | empty | the id of the Figma file to align before the code; empty = no Figma phase |

When `verify_commands` and `docs_paths` are not set, `/issue-flow:plan` infers them during
reconnaissance — `package.json` scripts, `Makefile` targets, `pyproject.toml`, CI jobs — and
**writes them in the issue**, so the verification phase has real commands instead of a generic
“run the tests”. If the project has a `CLAUDE.md`, it usually already says them.

## Language

Issues, MR/PRs and `ROADMAP.md` come out in the language you talk to Claude in; commits follow
the language of the project's log, or yours if there is no history yet. Headings, bold labels
and status values stay in English (`## Plan`, `**Execution:**`, `**Status:** in progress — phase
2 of 6`), because the skills read them (`TRACKER.md` §6). Issues written by 1.x with Italian
markers are still recognized, and the 1.x Italian arguments — `--chiudi`, `--da`, `spunta`,
`rivedi` — still work.

## How it works

To know where to pick up from:

```
/issue-flow:roadmap                  →  proposes the next steps, each with its source
                                        approved: ROADMAP.md at the root, or
                                        big-plan turns it into the parent and one child per step
/issue-flow:roadmap the frontend     →  only the steps of an area or a milestone
```

`roadmap` reads the research-flow registers when the repo has `.research-flow.json` — the
project's state, the open TODOs, the proposed experiments, the hypotheses to verify — but
research-flow is not a requirement: without it, it relies on a previous `ROADMAP.md`,
`CLAUDE.md`, `README.md`, the `docs_paths` and the open issues. Every step cites the source it
comes from; what the documentation does not say and `roadmap` proposes on its own is marked as
such. The horizon stops at the first decision point that depends on an outcome not yet known:
beyond it, the two branches in one line.

For a feature:

```
/issue-flow:plan add a date filter to the list                   →  opens issue #12
/issue-flow:implement 12                                         →  branch issue-12-add-a-date-filter-to-the-list,
                                                                    one commit per phase, then the MR/PR
                                                                    opens by itself: you preview and approve
/issue-flow:close 12 --merged                                    →  once you have merged it, closes the issue
```

For a development that does not fit in one issue:

```
/issue-flow:big-plan notification system with user preferences   →  parent #20, children #21, then #22 ∥ #23
/issue-flow:implement 20                                         →  takes the first open child, #21, up to its MR/PR
/issue-flow:close 21 --merged                                    →  once merged: closes #21 and ticks it on #20
/issue-flow:implement 20                                         →  now it is #22's turn, and so on
```

By hand, the children run one at a time, each with its own branch and its own MR/PR, and each
starts from the target branch with the previous ones already merged in. Or all at once, without
waiting for the merges and with the children of a wave in parallel:

```
/issue-flow:big-implement 20      →  branch roadmap-20-notification-system from main; #21, then #22
                                     and #23 together, each in its own worktree, branch off it and
                                     come back into it on their own, one at a time, each as one
                                     squash commit; then the MR/PR roadmap-20-notification-system → main
/issue-flow:close 20 --merged     →  after you have merged the parent's MR/PR: closes #20
```

Every child goes through `close` as always — verification on the final tree, documentation,
MR/PR — but towards the parent branch, and there the plugin merges it on its own, as a single
squash commit fast-forwarded onto the previous children: the parent branch reads as one commit
per child, because it is the project's work site, not the product. Only the parent's MR/PR
reaches the target branch, and that one the plugin never merges: you approve it and you merge
it. You do not need to know in
advance which of the two to use: `/issue-flow:plan` always checks whether the request fits in
one issue, and when it does not it stops, warns with the measured numbers and a draft split, and
proposes how to proceed — switch to `big-plan` (which picks up from the reconnaissance already
done), open only the first issue, narrow the scope, or keep a single issue anyway.

Each of them restarts on its own after a `/clear`: the state lives in the issue's checkboxes,
not in the conversation. `/issue-flow:implement` without a number infers it from the current
branch.

`/issue-flow:implement` and `/issue-flow:big-implement` do not need `/goal`: they bring along a
`Stop` hook (`scripts/goal-stop.sh`) that at the end of every turn re-reads the issue from the
tracker and sends the session back to work as long as a box is still open in the Plan or the
last phase is not committed. It stops earlier only on an explicit decision — a phase that failed
twice, a choice the issue did not make — and says so. With `big-implement` the goal covers all
the children of the project and the parent, up to the last merge into the parent branch. The
goal's state lives in `.git/issue-flow/`, outside the commits.

## Several sessions at once

Each `implement` or `big-implement` runs in a Claude Code session of its own, and you can open
as many as you have issues ready — and, in a superproject, as many as you have submodules with
work to do. To keep them from stepping on each other, open one more and run
`/issue-flow:issue-master` in it:

```
terminal 1   /issue-flow:issue-master        →  issue-master-app, yellow: the coordinator
terminal 2   /issue-flow:implement 12        →  issue-12, green: reports to the master, waits for its go, works
terminal 3   /issue-flow:implement 14        →  issue-14, green: overlaps #12 on src/api/list.ts → held until #12 is merged
terminal 4   /issue-flow:big-implement 20    →  issue-20, green: the whole roadmap, as one row of the board
```

Every session names itself — `issue-<n>` in a single repository, `issue-<n>-<repo>` in a
superproject, `issue-master-<project>` for the master — and sets its prompt color, so that the
prompt bar and `/resume` say what each terminal is doing. Inside tmux the sessions do it by
themselves, as soon as they are idle; outside, each one tells you the two commands to type.

The master keeps a board of who works on what and where, agrees before each start on what the
session may touch — the files its Plan names, the magnet files, the numbered series such as
migrations, the ports and databases the verification uses —, holds a session that would rewrite
what another one is rewriting, answers the sessions that need a file or a number, tells the
others to bring the target branch in when you merge an MR/PR, and tells you what stopped. It
never merges, it never implements, and it never speaks for you: you still talk to every session
in its own terminal. Without a master the sessions work as they always did. The names, the
messages and the waits are in `SESSIONS.md`.

## The three rules the plugin does not negotiate

**Tick as you go.** At the end of each phase, in the same commit that carries it — not when the
work is done. A roadmap that does not tell its own state is useless, and one that lies is worse
than no roadmap: if a decision changes, the line gets rewritten instead of ticked.

**The body is re-read from the server before rewriting it.** The update replaces the whole field
and does not merge: starting from a copy kept in the conversation wipes out the boxes someone
ticked from the page in the meantime.

**The MR/PR is opened, not merged.** The merge is the user's call, always — not even green
pipelines change that. `implement` ends with the MR/PR open and a hand-off that says what
changes and how to see it running: the preview is yours to look at before approving.

## GitLab and GitHub

`TRACKER.md`, in the plugin folder, has the full command mapping and the differences that bite:
the body field called `description` on one side and `body` on the other, the `--limit` of
`gh issue list` stuck at 30, `task_completion_status` that exists only on GitLab, the CRLFs in
bodies written from GitHub's web UI, `gh pr create` that has no `--related-issue`.

## License

MIT.
