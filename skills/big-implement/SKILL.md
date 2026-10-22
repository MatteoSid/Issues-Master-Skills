---
name: big-implement
description: "Carries all the child issues of an /issue-flow:big-plan parent issue through in a single run — GitLab or GitHub — on the parent branch: one wave at a time, in the parent's order, with the children of a wave in parallel, each in its own git worktree and handed to an issue-runner subagent that does the round of /issue-flow:implement (one checkbox agent per phase, several at once too, checkboxes ticked, one commit per phase) and that of /issue-flow:close, which verifies, opens the merge request — pull request on GitHub — toward the parent branch and merges it on its own, one child at a time. At the end it opens the parent's MR/PR toward the target branch, which only the user merges. Triggers: /issue-flow:big-implement, “implement the whole project N”, “carry out the whole roadmap N”, “run all the children of N”; in Italian: «implementa tutto il progetto N», «porta avanti tutta la roadmap N», «esegui tutte le figlie di N»."
argument-hint: "<parent>"
hooks:
  Stop:
    - hooks:
        - type: command
          command: "${CLAUDE_PLUGIN_ROOT}/scripts/goal-stop.sh"
---

# /issue-flow:big-implement

`/issue-flow:implement <parent>` executes **one** child and stops: the next one starts only
after the previous one is merged, which the user does. This skill carries **the whole
project** through in one go, without waiting for anyone until the end, and with the children of
the same wave **in parallel**:

```
main ──────────────────────────────────────────────── ◀── MR/PR issue-20 (the user merges it)
  └─ issue-20 ──●──────────●────●──────────●──────
                ▲          ▲    ▲          ▲
            issue-21   issue-22 issue-23  issue-24
            wave 1     └── wave 2 ────┘   wave 3
                       (together, each in its own worktree;
                        they come back one at a time)
```

- the parent has its own branch, `${user_config.branch_prefix}<parent>`, created from the target
  branch, and the repo folder stays on that branch from start to finish;
- each child works in **its own worktree**, on a branch created from the updated parent branch.
  The children of a wave start together from the same commit; a wave starts when the previous
  one is fully merged;
- each child goes through `close`: verification on the final tree, documentation, MR/PR
  **toward the parent branch** — which here `close` **merges on its own**, because the parent
  branch is not the product: it is the project's work site, and the real review comes at the
  end. The children of a wave are implemented together but **integrated one at a time**: each
  one, before its merge, merges in what its siblings have already brought into the parent branch
  and redoes the verification on top of it;
- when the last child is merged, the parent's MR/PR toward the target branch is opened as usual
  and **is not merged**: the user approves and merges that one.

The execution rules are those of `implement` and `close` and are not repeated here:
`${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md` for the phases, the verification, the ticks,
the commits and goal mode; `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md` for the final
verification, the documentation, the MR/PR, the merge into the parent branch and the closing;
`${CLAUDE_PLUGIN_ROOT}/TRACKER.md` for the commands of the two platforms;
`${CLAUDE_PLUGIN_ROOT}/PARALLEL.md` for the roles, the agreement between parallel work and the
worktrees. **Read all four before the first command.** Below is only what changes.

## Usage

```
/issue-flow:big-implement <parent>   # runs, one wave at a time, all the children not yet merged
```

## You are the roadmap agent, for the whole project

You don't implement the children and you don't orchestrate their phases: you hand each child to
an Issue agent — an `issue-flow:issue-runner` subagent —, which does for it the round of
`implement` and of `close` up to the merge into the parent branch, and in turn hands each phase
to a checkbox agent — an `issue-flow:issue-phase` subagent:

```
you (big-implement, roadmap agent)   the project: waves, agreements, worktrees, parent branch, goal, parent's MR/PR
 └─ issue-runner, one per child      the child: phases, agreements between phases, verifications, ticks, commits, close, merge
     └─ issue-phase, one per phase   the phase: its checkboxes
```

The reason is context, as in `implement` but one level up: the phases of all the children in
your context would fill it halfway through the project. You keep the view of the project — which
wave is under way, which children, with which MR/PRs, how many are already in the parent branch,
what they changed along the way — and you check the outcome of each child on the tracker and on
git, not on the runner's story.

The chain uses all the depth Claude Code allows: below the main session, subagents can launch
others for two levels, and the third no longer has the `Agent` tool. That is why `issue-phase`
does not delegate, and the runner must never be launched by another subagent.

**Together only the children of the same wave**, and only after the agreement of step 4.1.
Children of different waves never: the first child of wave N+1 is created from the parent branch
**after** all of wave N has been merged into it, and starts from the code that wave left.

## 0. Which tracker, and does it answer

Identical to step 0 of `implement`.

## 1. Read the parent and work out the waves

Read the parent from the server as in step 1 of `implement`. If the head of the body does not
have `**Type:** roadmap`, it is not a parent: say so and propose `/issue-flow:implement <number>`.

From the **Issues** section, in order, take the `- [ ] #<n>` lines with their **Wave**: they are
the children to carry through. A parent written before waves existed has none: each child is a
wave of its own. The `- [x]` ones are already merged — into the parent branch or, from a round
done by hand, into the target branch — and are not touched. For each child to do, look on the
tracker at:

- **its state**: if it is already closed but the box is empty, the parent has fallen behind —
  report it, don't re-run it, and treat it as merged;
- **its dependencies** — `· depends on #<k>` in the parent, `**Depends on:**` in the child:
  each must be merged (box ticked or issue closed) **or** a child that this run carries through
  in a wave **before** its own. A dependency outside both cases — an open external issue, a
  sibling of the same wave or of a later one — is a roadmap that doesn't hold: stop and say so;
- **whether it has already started** in a previous round: the branch
  `${user_config.branch_prefix}<n>` exists, has a worktree (`git worktree list`), has ticked
  checkboxes, already has an MR/PR (`glab mr list --source-branch <branch>`,
  `gh pr list --head <branch>`). Resume from where it was left instead of starting over: from
  the first unticked phase, from the integration if the phases are all done, from the merge if
  the MR/PR is open.

Look at the **parent** too: if it already has an MR/PR open toward the target branch
(`glab mr list --source-branch <parent-branch>`, `gh pr list --head <parent-branch>`), the
project has already been delivered — say so and don't start again.

Then present the waves to the user and start without asking for confirmation:

```
issue-20  parent branch, created from main
wave 1   #21  issue-21  worktree, created from issue-20   MR/PR → issue-20, merged by close
wave 2   #22  issue-22  worktree, created from issue-20   ┐ together
         #23  issue-23  worktree, created from issue-20   ┘ merged one at a time: #22, then #23
wave 3   #24  issue-24  worktree, created from issue-20   MR/PR → issue-20, merged by close
issue-20  MR/PR → main, the user merges it
```

If there is no child left to do but the parent doesn't have its MR/PR yet, jump to step 5.

## 2. The parent branch

The parent branch is `${user_config.branch_prefix}<parent>` — with the default `issue-`, parent
#20 has `issue-20`. It is created from the updated target branch, and goes **straight to the
remote**: the children's MR/PRs point to it, and `close` recognizes the big-implement flow
precisely from its existence on `origin`.

```bash
git status --porcelain                 # must be empty
git fetch origin
git switch <parent-branch> 2>/dev/null \
  || git switch -c <parent-branch> --track origin/<parent-branch> 2>/dev/null \
  || { git switch <target> && git pull --ff-only && git switch -c <parent-branch>; }
git push -u origin <parent-branch>
```

If the branch already existed from a previous round, align it with `origin` with
`git pull --ff-only`. If the target branch has moved on in the meantime, you **don't** chase it:
the parent branch is realigned only once, at step 5 — in `close` on the parent —, where a
conflict is the user's decision.

From here to the end **the repo folder stays on the parent branch**, and clean: the children
work in their worktrees, and only their merges arrive here, with a `git pull --ff-only`.

Bring the parent's **Status:** line to `in progress — k of M issues merged into <parent-branch>`.

## 3. The goal covers the whole project

Goal mode is that of `implement`, with one difference: `$GOAL_DIR/goal` contains **all** the
children to carry through and **the parent**, one number per line. The `Stop` hook re-reads
each one from the tracker and doesn't let the turn end while any of them has a `- [ ]`: in the
Plan for the children, in the **Issues** section for the parent — which is ticked only when a
child is merged into its branch. This way the goal holds up to the last merge, not just up to
the last phase.

```bash
GOAL_DIR=$(git rev-parse --path-format=absolute --git-path issue-flow)
mkdir -p "$GOAL_DIR" && printf '%s\n' 21 22 23 24 20 > "$GOAL_DIR/goal" && rm -rf "$GOAL_DIR/in-flight"
```

You write it after step 2, before the first child. `in-flight/` works as in `implement`
(`PARALLEL.md` §5), with one sentinel per **runner** at work: you create it right before
delegating the child — `touch "$GOAL_DIR/in-flight/child-<n>"` — and remove it as soon as that
runner returns, even if others are still at work. The runners don't touch `.git/issue-flow/`
outside `wt/`: the goal and `in-flight/` are yours alone.

When the last child is merged the hook lets you stop even if the parent's MR/PR is not open
yet. Don't stop there: the hand-off comes after step 5.

To stop before the end **you delete `$GOAL_DIR/goal` yourself** and tell the user why.

## 4. The round, one wave at a time

For each wave, in order: the agreement and the worktrees (4.1), the children delegated to the
runners all together (4.2), each child's round done by its runner (4.3), the integration one
child at a time (4.4), the check of each one (4.5). Then the next wave.

A wave with a single child does the same round, shorter: no agreement to confirm, and the runner
runs `close` straight after, without waiting for the go-ahead to integrate.

### 4.1 The agreement and the worktrees

The children of a wave were put together by whoever wrote the roadmap, but **you confirm the
agreement**, on the parent branch as it is now, before assigning them: the earlier waves have
changed the code, and those who implemented them may have deviated. Re-read the parent's
**Parallelism** section and the Plans of the wave's children, and check:

- that the scopes are still disjoint: no file, or section of a file, that appears in the Plan
  of two children of the wave — the magnet files of `PARALLEL.md` §2 included;
- that the **Contract** holds on the parent branch: the types, interfaces and files it relies
  on exist, with the name and shape it states — the deviations reported by the runners of
  earlier waves are the first place to look;
- that no child of the wave depends on another of the same wave.

If something doesn't hold, the wave **runs in sequence**, in the parent's order, one child at a
time: it is always correct, and you say so in the hand-off. If it held only with a more precise
contract — a name the parent left implicit —, fix it yourself, put it in the prompt of **all**
the runners of the wave and rewrite the parent's **Parallelism** section, re-reading it from the
server. Don't move work between children: that is a `/issue-flow:plan revise`.

Then, for each child of the wave, its worktree, from the updated parent branch
(`PARALLEL.md` §4):

```bash
git pull --ff-only                                           # you are on the parent branch
WT=$(git rev-parse --path-format=absolute --git-common-dir)/issue-flow/wt
git worktree add "$WT/<branch>" -b <branch> <parent-branch>  # or, if the branch already exists:
git worktree add "$WT/<branch>" <branch>                     #   it picks it up where it was
( cd "$WT/<branch>" && <setup command> )
```

The setup command is the one the child writes in its **Context**, or the project's.

### 4.2 Delegate the children, all together

One invocation of the `Agent` tool with `subagent_type: "issue-flow:issue-runner"` for each
child of the wave — at most `${user_config.max_parallel}` together, empty means 3; the others in
batches —, **all in a single message**. The runner has not seen the conversation: **what you
don't write to it doesn't exist**. In the prompt:

- the number and title of the child, the parent's number, the parent branch and the target
  branch;
- the **absolute path of its worktree**, and that it works only there: the repo folder is yours;
- the absolute paths of the instructions it must read:
  `${CLAUDE_PLUGIN_ROOT}/skills/big-implement/SKILL.md` — for step 4.3, its round —,
  `${CLAUDE_PLUGIN_ROOT}/skills/implement/SKILL.md`, `${CLAUDE_PLUGIN_ROOT}/skills/close/SKILL.md`,
  `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` and `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md`;
- the configuration values: `${user_config.branch_prefix}`, `${user_config.default_branch}`,
  `${user_config.verify_commands}`, `${user_config.docs_paths}`, `${user_config.figma_file}`,
  `${user_config.max_parallel}` — empty ones included, stated as empty;
- the language to write the MR/PR and what goes into the issues in — the user's,
  `TRACKER.md` §6: the runner does not know it;
- if the wave has several children: **its scope**, those of its siblings and the **Contract**,
  verbatim from the parent's **Parallelism** section, with what you fixed at step 4.1; and that
  it stops at “ready for integration” and waits for your go-ahead before `close`;
- where to resume from, if step 1 found the child already started: the first unticked phase,
  the integration, the MR/PR already open, the merge;
- what the children of the earlier waves left behind, if they deviated from their issue — the
  child's writer knew them only as a plan. It is the “deviations” field of the previous
  runners' reports.

Each runner has its sentinel in `$GOAL_DIR/in-flight/`, created right before the invocation and
removed as soon as it returns, before the check.

Non-negotiable rules: **a new runner for each child**, never reuse one with `SendMessage` for
another child; never children of different waves together. While the runners work you don't
touch their worktrees or their issues; the repo folder stays on the parent branch, clean.

### 4.3 The child's round

The runner does this, and it is here because it is its reference. Three steps, all in the
worktree the prompt gives it.

#### The branch, from the parent

The worktree is already on the child's branch, created from the updated parent branch. The
check of step **1c** of `implement` is done against the parent branch: the dependencies are
closed and their work is there (`git log --oneline <parent-branch> | grep '#<k>'`), and the
“created by #<k>” hook points exist there. If they don't hold, you stop as `implement` says.

#### The phases

Step 3 of `implement`, with two variants: no `in-flight/` or `goal`, which belong to
`big-implement`; and the repo folder, for you, is your worktree — you create the worktrees of
the parallel phases with `git -C <your worktree> worktree add …`, in the same `$WT`, and you
integrate them into your worktree. A **new** `issue-flow:issue-phase` subagent for each phase
with the full context of the child, the phases of a group together after your agreement,
verification run by you, the tick on the issue re-reading it from the server, one commit per
phase with `(#<child>)` in the message. When the phases are done, the child's **Status:** line
as in step 4 of `implement`.

The child's phases stay within the **child's scope**: if a phase asks you for a file outside
it, you don't grant it — you stop and write it in the report, because that file belongs to a
sibling.

The prompt of each phase also carries what the already merged children left behind, if they
deviated from their issue.

If the wave has several children, when the phases are done **you stop**: report with “ready for
integration”. You do the rest when `big-implement` gives you the go-ahead, at step 4.4.

#### Close, up to the merge into the parent branch

All of `close` on the child, in its “child on the parent branch” case, in your worktree: the
checks of step 1 — which bring into the child's branch what the siblings have already merged
into the parent branch (`git merge origin/<parent-branch>`) and redo the verification on the
merged tree —, the documentation of step 2, the MR/PR of step 3 **toward the parent branch**,
then the merge and the closing of step 3b, which don't wait for the user. At the end:

- the child's MR/PR is merged into the parent branch;
- the child is closed, with **Status:** `closed — merged into <parent-branch> on YYYY-MM-DD`;
- its box on the parent is ticked, and the parent's **Status:** says `k of M`;
- the worktree stays where it is, with the child's branch: `big-implement` removes it.

A conflict in the merge with the parent branch means the work of two siblings was not
compatible: `git merge --abort`, you stop and write it in the report with the conflicting
files. You don't resolve it: the agreement was made by whoever is above, and it is up to them.

If `close` stops — an empty box, a red verification, a failed pipeline, an MR/PR the server
doesn't merge — the runner stops and writes it in the report.

### 4.4 The integration, one child at a time

The children of a wave come back into the parent branch **one at a time, in the parent's
order**, because each must run the verification on the tree with the already merged siblings in
it. When all the runners of the wave have come back “ready for integration”, for each child in
order:

1. give **its** runner the go-ahead with `SendMessage` — “integrate: run `close` as in step
   4.3” —, so it resumes with the child's context; if it no longer answers, a new runner with
   the same prompt as 4.2, the first one's report and the instruction to restart from `close`.
   Its sentinel in `in-flight/` comes back for as long as it works;
2. on its return, the check of step 4.5;
3. update the repo folder and remove the worktree:

```bash
git pull --ff-only                                   # the parent branch, with the child in it
git worktree remove "$WT/<branch>"
git branch -D <branch> 2>/dev/null                   # merged, and already deleted on the server
```

Then the next child of the wave. Never two integrations together: the second would be verified
on a parent branch without the first.

If a runner stopped before the integration, or a child doesn't integrate, the wave stops there:
the children already merged stay merged, the others stay in their worktrees with their commits
— see “When to really stop”.

### 4.5 Check how it ended

The runner's report is a story, not a proof. Before moving on to the next child you check
yourself, on the server and on git:

```bash
# the child's MR/PR is merged into the parent branch
glab mr list --source-branch <branch> --target-branch <parent-branch> --merged   # GitLab
gh   pr list --head <branch> --base <parent-branch> --state merged               # GitHub

# the child is closed, with all the boxes of the Plan ticked
glab issue view <child> --output json --jq '.state'    # "closed"
gh   issue view <child> --json state --jq '.state'     # "CLOSED"

# its box is ticked on the parent: re-read the parent from the server

# the repo folder is on the parent branch, clean, and after the pull it has the child's commits
git branch --show-current && git status --porcelain
git fetch origin && git status -sb | head -1              # no “behind”
git log --oneline <parent-branch> | grep '(#<child>)'
```

If the runner stopped, or one of these checks doesn't add up, the project stops: see “When to
really stop”. A runner that says “merged” when the server says otherwise is not retried: the
child needs looking at.

Keep the report's deviations: they go into the prompt of the next wave's runners, into your
agreement at step 4.1 and into the hand-off.

When the whole wave is merged, move on to the next wave.

## 5. The parent's MR/PR

When all the boxes of the parent's **Issues** section are ticked, `close` on the parent, in its
“parent” case: it redoes the verification on the final tree of the parent branch, aligns the
documentation, pushes and opens the MR/PR `parent branch → target branch` with
`Closes #<parent>`. **Never the merge**: the user approves and merges this one, like every MR/PR
toward the target branch.

Before that, `git worktree list`: no worktree of this project must be left in `$WT`.

## 6. Hand-off

The link to the parent's MR/PR, at the top: it is the only thing the user has to do. Then a
table, in the order in which the children entered the parent branch:

```
wave  child  MR/PR  phases  merged into
1     #21    !40    6/6     issue-20
2     #22    !41    7/7     issue-20   in parallel with #23
2     #23    !42    5/5     issue-20   in parallel with #22
3     #24    !43    6/6     issue-20
```

Then the waves and phase groups you ran in sequence instead of in parallel, with the reason;
the checkboxes left empty with the reason, the deviations written in the roadmaps, the problems
the subagents saw outside their scope. And how to continue: once the parent's MR/PR is merged,
`/issue-flow:close <parent> --merged`, which closes the parent and deletes its branch.

Don't paste the issues or the diff.

## When to really stop

All the “When to really stop” cases of `implement` and of `close` — which for a child the
runner runs into, and reports to you —, plus two:

- **if a child stops, the project stops with it.** The next wave would be created from a parent
  branch without its work, so you don't skip ahead. The siblings of the same wave that are still
  working you let finish — they are in their worktrees, they bother no one — and you integrate
  those that arrive ready, but you don't open the next wave;
- **if two children of a wave don't integrate** — a conflict in the merge with the parent
  branch, or the verification red on the merged tree while each was green on its own —, the
  agreement didn't hold. No runner resolves it: tell the user with the children, the files and
  the part of the contract involved, and propose correcting the issues — the parent's
  **Parallelism** section, `/issue-flow:plan revise <child>` — before the code.

In the hand-off say which child stopped, at what point — phase, integration, MR/PR, merge —,
why, which worktrees remain (`git worktree list`) and that it resumes with
`/issue-flow:big-implement <parent>` once fixed: step 1 finds again the children already merged
and the leftover worktrees, and restarts from there.

Before stopping, `rm -f "$GOAL_DIR/goal"`: otherwise the hook sends you back to work.
