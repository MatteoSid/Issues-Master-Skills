# PARALLEL — who works together, and how they stay out of each other's way

The skills of this plugin make several agents work together **when possible**: the writers of
the children in `/issue-flow:big-plan`, the children of the same wave in `/issue-flow:big-implement`,
the phases of the same group in `/issue-flow:implement`. This file is the single reference for
when it is possible, for how it is written in the issues and for how it is executed with git
worktrees; the skills cite it instead of repeating themselves.

## 1. Who assigns work to whom

| role | who it is | assigns work to |
|---|---|---|
| **roadmap agent** | the `big-plan` session — and, at execution time, the `big-implement` one | the `issue-writer`s, one per child; the Issue agents, one per child |
| **Issue agent** | the `implement` session, or the `issue-runner` subagent of `big-implement` | the checkbox agents, one per phase |
| **checkbox agent** | the `issue-phase` subagent | nobody: it completes the checkboxes of **one** phase |

One level further up — several **sessions** on the same project, each with its own issue or
roadmap, and the `issue-master` session that keeps them apart — the reference is `SESSIONS.md`.

The rule that holds everything together: **the work of two agents working together is agreed
on by the agent that assigns it, before assigning it.** Two agents in parallel do not talk to
each other and do not see each other: if their work has to fit together, it fits because the
one above decided in advance who touches what and with which names. Never let them find out
on their own, and never let one of the two “adapt” to what it believes the other is doing.

## 2. When two pieces of work go in parallel

Two children, or two phases, can run together only if **all** of these hold:

- **disjoint scopes.** Each has a scope — the files it may modify or create, or the section of
  a file when the file is shared (“`README.md` §API, that section only”) — and the scopes do
  not overlap. Reading a file outside the scope is fine; modifying it is not;
- **neither needs the other's code** to compile, for its tests or for its manual check. If B
  calls a function that comes with A, B goes after A — or the signature comes first, in an
  earlier phase or child, and both rely on it;
- **a written contract.** What the two share — a type, a name, a signature, a data format, an
  enumeration — is decided by whoever assigns them and written in the issue, with the exact
  name and shape. Each respects it without seeing the other;
- **no shared resource in the verification** that a worktree does not isolate: a fixed port, a
  local database, a container with a fixed name, a cache folder outside the repo. If both
  verifications use it, either they go in sequence or the issue says so and the verification
  is run by the agent that assigned them, one at a time.

**Magnet files.** These are the ones almost every change touches, and the first to make two
parallel pieces of work conflict: lockfiles (`package-lock.json`, `poetry.lock`, `uv.lock`),
numbered migrations, route or plugin registries, index files that re-export (`index.ts`,
`__init__.py`), translation files, the changelog, the CI configuration. In a parallel group
each one has **a single** owner, or is touched only by whoever comes after the group — the
wrap-up phase, the next child. A new dependency means a touched lockfile: the phase or child
that adds it does not go in parallel with another one doing the same.

**When in doubt, in sequence.** A wrong parallel costs a conflict, a red verification on the
merged tree and a wasted round; a missed parallel only costs time. The verification and wrap-up
phases, and the Figma phase, never go in parallel with anything.

## 3. How it is written in the issues

Parallelism is decided **when planning**, not when executing: whoever executes finds it
written, re-checks it against the code and follows it.

**In the parent** of `big-plan` the children are in **waves**. The children of the same wave
do not depend on each other and run together; a wave starts when the previous one is entirely
merged. The **Issues** section is split by wave, and the **Parallelism** section states, for
every wave with more than one child, the scope of each and the contract between them
(`skills/big-plan/TEMPLATE.md`).

**In every issue** the Plan opens with the **Execution** line, which gives the order of the
phases with the parallel groups in square brackets:

```
**Execution:** 1 → 2 → [3 ∥ 4] → 5 → 6
```

An issue without parallel phases has the line all the same — `1 → 2 → 3 → 4 → 5 → 6` — so
whoever executes knows that sequential is a choice and not an oversight. Every phase of a
parallel group has, under its title, in place of the files line:

```
**Scope:** `src/a.ts`, `src/a.test.ts` — these only.
**In parallel with:** Phase 4. **Contract:** [what they share, with exact names and shapes;
what this phase leaves alone because it belongs to 4]
```

## 4. How it is executed: the worktrees

Several agents writing code together **never work in the same folder**: each one has its own
git worktree, on its own branch, born from the same commit. The repo's main folder stays with
whoever assigned them.

### Where

All of the plugin's worktrees live inside the common git folder, which never ends up in a
commit and does not dirty `git status`:

```bash
WT=$(git rev-parse --path-format=absolute --git-common-dir)/issue-flow/wt
```

`--git-common-dir` and not `--git-path`: inside a worktree `--git-path` points to that
worktree's private folder, and a runner working in a worktree would end up creating them in a
different place from where the one above looks for them. The name is the branch's:
`$WT/issue-21-schema` for a child, `$WT/issue-21-schema-phase-3` for a phase.

### The round

It is done by whoever assigns the work — the Issue agent for phases, the roadmap agent for
children — never by whoever receives it:

```bash
# 1. create: one local branch per piece, all from the same commit
git worktree add "$WT/<branch>-phase-3" -b <branch>-phase-3 HEAD

# 2. prepare: a worktree is born without installed dependencies or git-ignored files
#    (node_modules, .venv, .env). The setup command is given by the issue, in the Context;
#    if it is not, the project's one: npm ci, uv sync, poetry install…
( cd "$WT/<branch>-phase-3" && <setup command> )

# 3. assign: one agent per worktree, all in the same message, each with the absolute path
#    of its worktree, its scope and the contract

# 4. when each one returns: verify in ITS worktree, and check it stayed within its scope
git -C "$WT/<branch>-phase-3" status --porcelain     # only files in the scope

# 5. commit in its worktree, one commit per phase as always
git -C "$WT/<branch>-phase-3" add -A
git -C "$WT/<branch>-phase-3" commit -m "<phase message> (#<number>)"
```

Integration into the issue's branch, in the Issue agent's folder, **in phase order** and only
when the whole group is verified:

```bash
git cherry-pick <branch>-phase-3 <branch>-phase-4    # one commit per phase, linear history
```

and then the verification **on the merged tree**: every phase was green on its own, but it is
the first time they run together. At the end everything is removed — the phase branches are
local and never go to `origin`:

```bash
git worktree remove "$WT/<branch>-phase-3" && git branch -D <branch>-phase-3
```

The children of a wave follow the same round one level up, with two differences: the branches
are the children's real ones (`issue-21-schema`, born from the parent branch) and they are integrated
with their `close`, one at a time, instead of with a cherry-pick — each rebased onto the parent
branch and merged as a single squash commit, so that the parent branch reads as one commit per
child (`skills/big-implement/SKILL.md`).

### A conflict means the contract did not hold

If the integration cherry-pick or merge conflicts, or the verification on the merged tree is
red while the pieces were green on their own, **the work was not compatible**: a violated scope
or an incomplete contract. It is not resolved by hand by picking one of the two versions:

```bash
git cherry-pick --abort     # or: git merge --abort
```

and you stop, saying which pieces, which files, which part of the contract. The remedy is to
fix the issue — scopes, contract, or the group split into a sequence — before the code.

### How many at once

At most `${user_config.max_parallel}` agents at once for each assigning agent — empty means
3. A larger group runs in batches, in the issue's order. `1` turns parallelism off:
everything in sequence, as if the issues did not declare it.

## 5. The goal with several agents in flight

The `Stop` hook (`scripts/goal-stop.sh`) lets the turn end while a subagent is working. With
several subagents at once, `in-flight` is a **folder** with one sentinel for each:

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR/in-flight" && touch "$GOAL_DIR/in-flight/phase-3" "$GOAL_DIR/in-flight/phase-4"
# when each one returns, its own and only its own
rm -f "$GOAL_DIR/in-flight/phase-3"
```

As long as the folder is not empty the hook does not block: the notification of the next one
to return wakes you up. A forgotten sentinel turns the goal off, so you remove it **as soon
as** that agent returns, before verifying its work. The same folder holds `waiting-master`, the
sentinel of a session that waits for the master's answer (`SESSIONS.md` §7).
