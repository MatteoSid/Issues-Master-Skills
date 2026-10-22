---
name: implement
description: "Takes an issue from the repo's tracker — GitLab or GitHub — and implements its roadmap: one phase per subagent, the checkboxes ticked on the issue as the work closes, one commit per phase. It stops at the commit of the last phase: the merge request is opened by /issue-flow:close. With the number of a /issue-flow:big-plan parent issue it runs the first child not yet merged. Triggers: /issue-flow:implement, “implement issue N”, “finish issue N”, “work on issue N”; in Italian: «implementa la issue N», «porta a termine la issue N», «lavora la issue N»."
argument-hint: "<number> [--from N]"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:implement

`/issue-flow:plan` writes the work instruction, this skill executes it. Everything needed is in
the issue: plan, context, roadmap. No work is added that the issue does not foresee, and no
work it foresees is skipped.

## Usage

```
/issue-flow:implement <number>           # runs the issue from the first unticked phase
/issue-flow:implement <parent>           # big-plan parent issue: runs the first open child
/issue-flow:implement <number> --from 3  # restarts from phase 3, ignoring the checkboxes
/issue-flow:implement                    # infers the number from the current branch
```

The Italian argument of 1.x, `--da`, is still accepted and means the same as `--from`.

## You are the Issue agent and you stay one

You do not implement the phases: you assign them to the checkbox agents — one
`issue-flow:issue-phase` subagent per phase —, verify their outcome, tick the boxes and commit.
When the issue declares phases in parallel you assign them together, each in its own git
worktree, and it is you who agrees on their work before assigning it and integrates it
afterwards (`${CLAUDE_PLUGIN_ROOT}/PARALLEL.md`).

The reason is context. Each phase starts from a clean subagent that reads only the files it
needs, while you keep the view of the whole — where the roadmap stands, what the previous phase
decided, what is missing — without filling up with the details of every single file.

With `/issue-flow:big-implement` this same cycle goes down one level: for each child it is run
by an `issue-flow:issue-runner` subagent, which reads this skill as a reference and leaves the
goal to the main session.

## You work in goal mode

This skill behaves like a `/goal` with the condition already written: **it does not stop until
the roadmap is complete**. That is done by a plugin `Stop` hook (`scripts/goal-stop.sh`) which
at the end of every turn re-reads the issue from the tracker: as long as the Plan has a
`- [ ]`, or the last phase is not committed, it sends you back to work, telling you which phase
to restart from.

The hook reads the state from a folder inside `.git`, which never ends up in a commit:

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
```

- `$GOAL_DIR/goal` — the number of the issue being worked on. You write it at step 2; when the
  roadmap is complete the hook deletes it. As long as it is there, the turn does not end.
- `$GOAL_DIR/in-flight/` — the folder of the checkbox agents at work, one sentinel for each
  (`PARALLEL.md` §5). You create the sentinel right before delegating and delete it as soon as
  that agent returns: as long as the folder is not empty you can end the turn, because the
  notification of the next one to return wakes you up.

To stop before the end — the cases of “When to really stop”, or a checkbox that stays empty —
**you delete `$GOAL_DIR/goal` yourself** and tell the user why. This is intentional: stopping is
an explicit decision, not a turn that happens to end halfway through the roadmap. If you stop
before step 2, the file does not exist yet and there is nothing to delete.

## 0. Which tracker, and does it answer

The tracker is GitLab (`glab`) or GitHub (`gh`) depending on the remote:
`git remote get-url origin`. The full command mapping is in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md`
— the `TRACKER.md` file in this plugin's folder — to be read before the first command, because
the body field changes name between the two platforms and getting it wrong empties the issue.
If the issue has phases in parallel, read `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md` too.

```bash
glab auth status && glab issue view <number>          # GitLab
gh   auth status && gh   issue view <number>          # GitHub
```

It must show the issue, not a 404. If it gives a 404 or “could not determine base repo” the
remote is an SSH alias and the remedy is in `TRACKER.md` §2. If you are not authenticated, stop
and ask the user for `glab auth login --hostname gitlab.com` or
`gh auth login --hostname github.com`: it is interactive, you cannot do it yourself.

## 1. Read the issue, in full, from the server

```bash
# GitLab
glab issue view <number> --output json > "$SCRATCH/issue.json"
jq -r '.title'       "$SCRATCH/issue.json"
jq -r '.description' "$SCRATCH/issue.json" > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <number> --json title,body > "$SCRATCH/issue.json"
jq -r '.title' "$SCRATCH/issue.json"
jq -r '.body'  "$SCRATCH/issue.json" | sed 's/\r$//' > "$SCRATCH/roadmap.md"
```

Check that `roadmap.md` is not empty before going on: if it is, you picked the other
platform's field.

If the top of the body has `**Type:** roadmap`, it is the parent of a `/issue-flow:big-plan`
and is not implemented: go to step 1b. If it has `**Roadmap:** #<parent>`, it is a child:
everything that follows applies, plus step 1c before the branch.

Read all of it, not just the Plan: **Goal**, **Context** and **Out of scope** are what keeps
the subagents from reinventing decisions already made, and they must be passed on to them.

Then work out, and tell the user before starting:

- the working branch, `${user_config.branch_prefix}<number>` — with the default `issue-`,
  issue #12 is worked on `issue-12`;
- the list of phases (`###` inside `## Plan`) with how many checkboxes they have and how many
  are already ticked, and which phase you restart from;
- the execution order from the **Execution** line at the top of the Plan, with the parallel
  groups — `1 → 2 → [3 ∥ 4] → 5 → 6`. An issue written before the line existed does not have
  it: it is all in sequence;
- if the issue has no phases with checkboxes, **stop**: it is not an executable issue. Report it
  and propose `/issue-flow:plan revise <number>`.

## 1b. The parent: which child is next

Here the children run **one at a time, in order**. In the parent's **Issues** section, the
first unticked `- [ ] #<n>` line is the child to run — within a wave the order is free, and if
the first one has an open dependency you can take another child of the same wave:

```bash
grep -n '^[[:space:]]*- \[ \] #[0-9]' "$SCRATCH/roadmap.md" | head -1
```

Before taking it, check that the children it depends on — the `· depends on #<k>` line in the
parent, `**Depends on:**` in the child — are **closed** on the tracker
(`glab issue view <k> --output json --jq '.state'` → `closed`, `gh issue view <k> --json state
--jq '.state'` → `CLOSED`). A child with a dependency still open is not started: tell the user
and say which one must be closed first — usually it is an MR/PR awaiting merge.

If all the parent's boxes are ticked, the project is finished: say so, and if the parent is
still open propose closing it. If a box is empty but the child is already closed on the
tracker, the parent has fallen behind: point it out instead of running the child again.

Then tell the user “proceeding with #<n> — <title>” and start again from step 1 with the
child's number. **Never two children in the same run**: each has its own branch and its own
MR/PR, and the next one starts from the code this one will have merged.

To carry all the children forward in one go, without waiting for the merges, there is
`/issue-flow:big-implement <parent>`: the same execution on the parent branch, with the
children of a wave together, each in its own worktree — each child gets merged in by itself,
and only the parent's MR/PR reaches the target branch.

## 1c. Does the child still hold?

A child was written before the siblings it depends on were implemented: its `file:line`
references and the hook points marked “created by #<k>” described code that is now different.
Before delegating the first phase, check:

- the dependencies are **closed** on the tracker and their work is **in the base** of step 2
  (`git log --oneline <base> | grep '#<k>'`, or the files they were supposed to create exist);
- the hook points “created by #<k>” really exist, with the name the child expects;
- the `file:line` references of the first phase still point to what the issue describes.

If something does not hold in a substantial way — a file that does not exist, an interface
born with another shape, a decision the sibling changed along the way — **stop** and propose
`/issue-flow:plan revise <number>`. Lines merely shifted by a few positions are not a reason
to stop: the subagent re-verifies them anyway. The right remedy is to fix the issue before the
code.

## 2. The branch

The work never touches the target branch — `${user_config.default_branch}`, or the one
returned by `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'`.

```bash
git status --porcelain                # must be empty: one commit per phase makes sense
                                      # only if the commit contains the phase and nothing else
git switch <branch> 2>/dev/null \
  || { git switch <base> && git pull --ff-only && git switch -c <branch>; }
```

If there are uncommitted changes, stop and ask what to do with them.

On the right branch, activate the goal — with the number of the issue you are running, which
for a parent is the child's:

```bash
mkdir -p "$GOAL_DIR" && echo <number> > "$GOAL_DIR/goal" && rm -rf "$GOAL_DIR/in-flight"
```

The `rm` removes an `in-flight` left over from an interrupted session, which would otherwise
keep the goal switched off for good. For the same reason look at `git worktree list`: a phase
worktree left over from an interrupted round (`$WT/<branch>-phase-<N>`, `PARALLEL.md` §4)
either has a commit to integrate — the phase was verified and committed, and you restart from
the integration — or must be removed, and the phase redone.

For a child of a big-plan the branch is **always** created from the branch where the siblings
already merged are, freshly updated — the `git pull --ff-only` above:

- the **parent branch**, `${user_config.branch_prefix}<parent>`, if it exists on `origin`
  (`git ls-remote --exit-code --heads origin <parent-branch>`): the project is being carried
  forward by `/issue-flow:big-implement`, and the siblings are merged there;
- the target branch otherwise.

Never from the branch of a sibling not yet merged.

## 3. The cycle, one step of the Execution line at a time

For each step of the **Execution** line not yet completed, in order. A step is a single phase
or a parallel group, `[3 ∥ 4]`. A single phase goes through the four steps below, in the repo
folder, on the issue's branch. A group goes through the same four steps for each of its phases,
in its worktree, plus two: the agreement before (3.1) and the integration after (3.2).

### Delegation

One invocation of the `Agent` tool with `subagent_type: "issue-flow:issue-phase"`. The
subagent has not seen the conversation and has not read the issue: **what you do not write to
it does not exist**. The prompt contains, in full and not summarized:

- number and title of the issue, and the branch being worked on;
- the issue's **Goal**, **Context** and **Out of scope** sections;
- the phase number and its **full text**: intro, list of files, all the checkboxes with the
  code fragments under them, the “Done when” line;
- what the previous phases left behind, if they deviated from the written plan.

Right before the invocation
`mkdir -p "$GOAL_DIR/in-flight" && touch "$GOAL_DIR/in-flight/phase-<N>"`, and as soon as the
subagent returns `rm -f "$GOAL_DIR/in-flight/phase-<N>"`, before the verification.

Non-negotiable rules:

- **a new subagent for every phase.** Never reuse one with `SendMessage` for the next phase,
  never hand it two at once, **never two phases in parallel that the Execution line does not
  put in the same group**, and never two agents in the same folder: phase N+1 starts from the
  code phase N left behind, and two agents in the same working tree step on each other's toes;
- if the roadmap has a Figma phase, it is a phase like the others and goes to its own
  subagent, which will use the `figma:figma-use` skill and the `use_figma` tool on the file
  `${user_config.figma_file}`. It goes **before** the code, always, because the code adapts to
  the Figma and not the other way round;
- the wrap-up phase — documentation and commit — you keep for yourself: it is coordination,
  not implementation.

### Verification

When the subagent returns, **you** run the phase's commands and look at the real output. A
subagent's report is a story, not a proof.

If the phase carries no commands of its own, the project's commands for the part touched
apply: those the issue lists in the verification phase, or `${user_config.verify_commands}`.

If the verification fails: a second pass with a **new** subagent, to which you give the error
output and what had been attempted. If it fails again, stop and report — two failures on the
same phase say the issue is wrong, not the subagent.

### Tick the boxes on the issue

As soon as the verification passes, not when the work is finished. It is the step that makes
the issue readable for whoever picks it up after a `/clear`: without it, the roadmap lies.

```bash
# GitLab
glab issue view <number> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <number> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# turn into `- [x]` ONLY the checkboxes of the phase just closed
# bring the “**Status:**” line to `in progress — phase N of M`

glab issue update <number> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <number> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

**Always re-read the body from the server before rewriting it**, never from a copy kept in the
conversation: the update replaces the whole field and does not merge, so an old version wipes
out what the user ticked on the page while you were working. And check that the file is not
empty before sending it back up.

If a decision changed during the implementation, **rewrite the line** instead of ticking it:
the roadmap must say what was really done. If the subagent could not complete a checkbox, it
stays `- [ ]` and the reason must be told to the user at the end. With an empty checkbox the
roadmap never turns out complete: at the end of the work you delete `$GOAL_DIR/goal`
yourself, otherwise the hook sends you back.

### Commit

The phase and nothing else:

```bash
git add -A && git commit -m "<type>(<scope>): <what changes for the user> (#<number>)"
```

Messages follow the convention already in the project's log — format and language: look at it
with `git log --oneline -20` before the first commit, instead of imposing your own; with no
history to follow, the user's language. Never commit with a failed verification, never a
commit covering two phases.

### 3.1 A parallel group: the agreement, then all together

The phases of a group were declared parallel by whoever wrote the issue, but **you confirm the
agreement**, on the code as it is now, before assigning them: you are the agent that assigns
the work, and what two checkbox agents do together must fit the way you decided, not by
chance. Check:

- that the **Scopes** of the group's phases are disjoint and cover all the files their
  checkboxes name — including the magnet files of `PARALLEL.md` §2, such as a lockfile for a
  new dependency;
- that the **Contract** holds on the code: the names and types it relies on exist, with that
  shape, in the issue's branch as it is now;
- that no phase of the group needs another's code for its verification.

If something does not hold, **run the group in sequence**, in numeric order, and tell the user
in the hand-off: it is always correct, and it only costs time. If it held only with a more
precise contract — a name the issue left implicit —, fix it yourself, write it in the prompt
of **all** the group's phases and rewrite the Contract line in the issue.

Then, for each phase, the worktree of `PARALLEL.md` §4 — created from the commit the issue's
branch is at, and prepared with the command from the **Context** — and the usual
**Delegation**, with in addition in the prompt:

- the absolute path of the worktree, and that it works only there;
- its **Scope**, and that it modifies nothing outside it;
- the **Contract** and what the sibling phases do, with their scopes: it must neither redo
  nor touch that.

All the phases of the group — at most `${user_config.max_parallel}`, empty means 3; the others
in batches — start **in a single message**, each with its own sentinel in
`$GOAL_DIR/in-flight/`. When each one returns remove its sentinel, and run the
**Verification** in its worktree (`cd <worktree> && …`), plus the check that it stayed within
its scope:

```bash
git -C "$WT/<branch>-phase-<N>" status --porcelain    # only files in the Scope
```

A phase that went outside its scope is not integrated: a second pass with a new agent in the
same worktree, told which files it had to leave alone. A green phase is **committed in its
worktree** (`git -C "$WT/…" add -A && git -C "$WT/…" commit -m …`), one commit per phase as
always. The boxes are not ticked yet.

### 3.2 A parallel group: the integration

When all the group's phases are committed in their worktrees, you bring them into the issue's
branch, in the repo folder, **in numeric order**:

```bash
git cherry-pick <branch>-phase-3 <branch>-phase-4
```

Then the **Verification on the merged tree** — the commands of all the group's phases, plus
the project's ones for the part touched —: each was green on its own, but it is the first time
they run together. Only now do you tick the boxes of **all** the group's phases, in a single
rewrite of the body re-read from the server, and remove the worktrees with their branches
(`PARALLEL.md` §4).

A conflict in the cherry-pick, or a red verification on the merged tree while the phases were
green on their own, means the work was not compatible: `git cherry-pick --abort`, and you stop
— see “When to really stop”. You do not resolve it by picking one of the two versions: the
remedy is in the issue, in the scopes or in the contract.

## 4. Where this skill ends

At the commit of the last phase, with all the boxes ticked on the issue. **You do not open the
MR/PR here**: it is opened by `/issue-flow:close <number>`, which redoes the verification on
the final tree and writes its body. Telling the user in the hand-off is part of the work —
otherwise they are left with a ready branch and nobody to take it to its destination.

Bring the issue's **Status:** line to `implemented — awaiting merge request` (on GitHub:
`awaiting pull request`), so that whoever reopens the page knows where it stands without
looking at the git log.

## 5. Hand-off

A few lines: the closed phases with their commits (`git log --oneline`), the groups run in
parallel and those you brought back to sequence with the reason, the checkboxes left empty
with the reason, the deviations written in the roadmap, the problems the subagents saw outside
their scope, and how to go on: `/issue-flow:close <number>`. Do not paste the issue or the
diff.

If it was a child of a big-plan, say that too: which is the next child in the parent, and that
it starts only after this one's merge, with `/issue-flow:close <number> --merged` ticking the
box on the parent — or that `/issue-flow:big-implement <parent>` carries all the remaining
children forward without waiting for the merges. If the child was created from the parent
branch, `/issue-flow:close <number>` merges it there by itself, and there is no merge to wait
for.

## When to really stop

Stop and ask, instead of going on, if: the same phase fails twice; a phase requires a
decision the issue did not make; the work substantially touches files the issue did not
foresee; a verification cannot be run on this machine (missing port, service or credential);
the issue contradicts the code you find; two phases of a parallel group do not integrate — a
conflict, or the merged tree red. In this last case leave the worktrees where they are, with
their commits: they serve whoever has to understand what did not fit.

Before stopping, `rm -f "$GOAL_DIR/goal"`: otherwise the hook sends you back to work.

The right remedy is almost always to fix the issue before fixing the code.
