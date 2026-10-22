---
name: close
description: "Takes the work of an already implemented issue to a merge request — pull request on GitHub: checks that the roadmap really is all ticked, redoes the verification on the final tree, pushes the branch and opens the MR/PR with Closes #number. Once merged, it closes the issue and, if it is a child of a /issue-flow:big-plan, ticks it on the parent. The child of a project that has the parent branch — the one from /issue-flow:big-implement — goes in an MR/PR to that branch and merges it by itself; the parent goes in an MR/PR to the target branch, which the user merges. Triggers: /issue-flow:close, “open the merge request for issue N”, “close issue N”; in Italian: «apri la merge request della issue N», «chiudi la issue N»."
argument-hint: "<number> [--merged]"
---

# /issue-flow:close

`/issue-flow:implement` leaves a branch with one commit per phase and the roadmap ticked. This
skill puts it in front of whoever has to read it: a merge request — a pull request, if the
tracker is GitHub — with a body that says what changes and how it was verified. Below,
“MR/PR” stands for whichever of the two applies in this repo; to the user you say the right
word, not the slash.

**Towards the target branch the MR/PR is opened and not merged.** The merge is requested by
the user, always: towards `${user_config.default_branch}` this skill never runs `glab mr merge`
or `gh pr merge`, in any case, not even if the pipelines are green.

The only exception is the child of a project that has the **parent branch** — the one opened
by `/issue-flow:big-implement`: its MR/PR targets the parent branch, which is the project's
work site and not the product, and this skill merges it by itself after the same checks as
always. The work reaches the target branch only with the parent's MR/PR, and that one is
merged by the user.

## Usage

```
/issue-flow:close <number>            # opens the issue's MR/PR
/issue-flow:close <child>             # with the parent branch: MR/PR to it, merged and closed here
/issue-flow:close <parent>            # with all children merged: MR/PR of the parent branch
/issue-flow:close <number> --merged   # once merged: closes the issue and aligns the Status
/issue-flow:close                     # infers the number from the current branch
```

The Italian argument of 1.x, `--chiudi`, is still accepted and means the same as `--merged`.

## 0. Which tracker, and does it answer

GitLab (`glab`) or GitHub (`gh`) according to `git remote get-url origin`; the command mapping
is in `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — the `TRACKER.md` file in this plugin's folder — to
be read before the first command.

```bash
glab auth status && glab issue view <number>          # GitLab
gh   auth status && gh   issue view <number>          # GitHub
```

On a 404, or on “could not determine base repo”, the remedy in `TRACKER.md` §2 applies: the
remote is an SSH alias the CLI does not recognize. If you are not authenticated, stop and ask
the user for `glab auth login --hostname gitlab.com` or `gh auth login --hostname github.com`:
it is interactive.

## 0b. Which case

Re-read the issue from the server and look at the head of the body. The case decides the
**base** — the branch the MR/PR targets — and who merges it:

| case | how you recognize it | base | merge |
|---|---|---|---|
| **issue** | no `**Type:**` nor `**Roadmap:**` | target branch | the user |
| **child** | `**Roadmap:** #<parent>`, and the parent branch is **not** on `origin` | target branch | the user |
| **child on the parent branch** | `**Roadmap:** #<parent>`, and the parent branch is on `origin` | parent branch | this skill, at step 3b |
| **parent** | `**Type:** roadmap`, and the parent branch is on `origin` | target branch | the user |

The target branch is `${user_config.default_branch}`, or whatever
`git symbolic-ref --short refs/remotes/origin/HEAD | sed 's#^origin/##'` returns. The parent
branch is `${user_config.branch_prefix}<parent>`, and it exists if:

```bash
git ls-remote --exit-code --heads origin <parent-branch>   # exit 0: it exists
```

A parent **without** its branch has nothing to take to an MR/PR: the children went one by one
into the target branch, and the parent closes by itself with the `--merged` of the last one.
Say so and stop.

Tell the user which case you recognized, before going on.

## 1. Is the work really finished?

Three checks, before touching anything. If one fails **you stop and report it**: an MR/PR
opened on incomplete work costs more than one not opened.

**The roadmap is all ticked.** Re-read the issue from the server and count. The count in the
body is the only one that holds on both platforms — `task_completion_status` exists only on
GitLab:

```bash
# GitLab
glab issue view <number> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub
gh issue view <number> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # total
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # ticked
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # the ones left
```

For the **parent** the boxes are those of the **Issues** section, one per child, and they count
like the others: all ticked means all children merged into the parent branch. Also check that
every child is closed on the tracker; a ticked box on an open child, or the opposite, is a
parent left behind, to be fixed first.

If empty boxes remain, list them to the user and ask: either work is missing — and then it's
back to `/issue-flow:implement <number>` — or they were dropped and the line must be rewritten
to tell the truth. Don't tick them yourself to make the count add up.

**The branch is the right one and has nothing pending.** The working branch is
`${user_config.branch_prefix}<number>` — for the parent, the parent branch itself; the base is
the one from step 0b.

```bash
git fetch origin
git branch --show-current             # must be the issue's branch
git status --porcelain                # must be empty
git log --oneline origin/<base>..HEAD # the phases' commits, one per phase — for the parent, the
                                      # children's merges with their commits
git merge-base --is-ancestor origin/<base> HEAD   # exit 0: the branch contains the base
```

If the branch does not contain the base — the target branch moved ahead while the project was
on the parent branch, or the parent branch moved ahead while the child was working, for
example because a sibling of the same wave got in first — merge the base into the branch
(`git merge origin/<base>`) and redo the checks. If the merge has conflicts,
`git merge --abort` and stop: how to resolve them is a decision, not a typo — and between two
siblings of a wave it means the agreement between them did not hold.

If the working tree is dirty, stop: that work is in no commit and would not end up in the
MR/PR.

**Verification passes on the final tree.** The single commits were green one by one; here what
counts is the result of all of them together. Run the commands the issue lists in its
verification phase — or `${user_config.verify_commands}` — and look at the real output, not
the summary.

For the **parent** the verification is that of the whole project: the union of the commands of
the children's verification phases, or `${user_config.verify_commands}`, run on the tree of the
parent branch — it is the first time they all run together.

Then the manual check on what the issue promised would be visible. If something is red you
don't open the MR/PR: you fix it with a commit on the branch, or you stop and report it.

## 2. The documentation

Before the MR/PR, not after: the documentation must describe the new behavior, not the old
one. Re-read the files the issue's wrap-up phase named — or those in
`${user_config.docs_paths}` — and check them against the code as it is now. If one is missing,
update it and commit it before going on.

## 3. Open the MR/PR

```bash
git push -u origin <branch>

# GitLab
glab mr create \
  --related-issue <number> \
  --source-branch <branch> \
  --target-branch <base> \
  --title "<the same title as the issue>" \
  --description-file "$SCRATCH/mr.md" \
  --remove-source-branch \
  --yes

# GitHub — no `--related-issue` nor `--remove-source-branch`: the link is made by the
# `Closes #<number>` at the top of the body, and the branch is deleted after the merge
gh pr create \
  --head <branch> \
  --base <base> \
  --title "<the same title as the issue>" \
  --body-file "$SCRATCH/mr.md"
```

The MR/PR number is the one the command prints in the URL: read it from there. On GitHub it
won't be the issue's — issues and pull requests share the same number sequence.

For the **child on the parent branch**, `<base>` is the parent branch: on both platforms
`Closes #<number>` only acts on the default branch, so you close the child yourself at step 3b.
The body is the same, with one line under the `Closes`:
`Part of #<parent> — merges into <parent-branch>.`

The body is short and stands on its own — the issue has the plan, the MR/PR has the outcome.
Whoever reviews must not have to open two pages to understand what they're looking at:

```markdown
Closes #<issue number>

## What changes
[two or three lines on what happens differently for whoever uses the product, not the list of
files]

## How it was verified
[the commands run and what they actually printed, with the numbers; the manual check and what
was seen]

## Deviations from the plan
[the roadmap lines rewritten during implementation, with the why. “None” if there are none.]
```

For the **parent** the body carries `Closes #<parent>` and, between “What changes” and “How it
was verified”, one more section:

```markdown
## Children
- #21 <title> — !40        # on GitHub: — #40
- #22 <title> — !41
```

with the MR/PRs through which each child entered the parent branch
(`glab mr list --target-branch <parent-branch> --merged`, `gh pr list --base <parent-branch>
--state merged`). “Deviations from the plan” gathers those of the children.

The numbers in here are the ones you **read** at step 1, not the ones you expected: an MR/PR
that declares green tests never run is the fastest way to let an error through.

Then bring the issue's **Status:** line to `in review — !<MR number>` on GitLab, or
`in review — #<PR number>` on GitHub, always re-reading the body from the server before
rewriting it, because the update replaces the whole field and does not merge:

```bash
# GitLab
glab issue view <number> --output json --jq '.description' > "$SCRATCH/roadmap.md"
# GitHub
gh issue view <number> --json body --jq '.body' > "$SCRATCH/roadmap.md" && sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# you touch only the “**Status:**” line

glab issue update <number> --description-file "$SCRATCH/roadmap.md"   # GitLab
gh   issue edit   <number> --body-file        "$SCRATCH/roadmap.md"   # GitHub
```

For the **child on the parent branch** you don't stop here: go on with step 3b. In the other
cases the skill ends with the MR/PR open, and continues when the user comes back with
`--merged`.

## 3b. The merge into the parent branch

Only for the **child on the parent branch**, right after step 3, without asking: the checks
whoever reviews would have done, you did at steps 1 and 2.

**The pipelines, if there are any.** Wait for them to finish and look at the outcome:

```bash
# GitLab — `null` if the project has no pipelines on the MR
glab mr view <mr> --output json --jq '.head_pipeline.status'   # repeat until it is success/failed

# GitHub — “no checks reported” means no checks, and that is green
gh pr checks <pr> --watch --fail-fast
```

A red pipeline is a “When to really stop”, like a red verification at step 1.

**The merge**, tied to the commit you verified, so that nothing you haven't seen gets merged:

```bash
SHA=$(git rev-parse HEAD)

# GitLab — without `--auto-merge=false` glab postpones the merge to the end of the pipeline, and
# the next child would be born from a parent branch still without this one
glab mr merge <mr> --sha "$SHA" --auto-merge=false --remove-source-branch --yes

# GitHub — `--merge` keeps the phases' commits, with their `(#<number>)`, in the history of the
# parent branch
gh pr merge <pr> --merge --match-head-commit "$SHA" --delete-branch
```

Then re-read the state: it must be `merged`/`MERGED` **now**. If the server queued it or put it
in auto-merge, or refused it — conflicts, mandatory approvals, protected branch — stop and
report what it says.

**The closing**, without waiting for `--merged`: step 4 in full — the issue closed, the child's
**Status:** at `closed — merged into <parent-branch> on YYYY-MM-DD`, the working branch deleted
if the server hasn't already done it, and the box ticked on the parent as in “The parent, if the
issue is a child”. Locally you go back to the parent branch, updated:

```bash
git switch <parent-branch> && git pull --ff-only
```

If you work in a **worktree** — the one `/issue-flow:big-implement` gives each child
(`PARALLEL.md`) — you don't go back anywhere: the parent branch is in the repo's main folder,
and whoever gave you the worktree updates it, together with the worktree they remove. In the
same way the child's local branch, which the worktree keeps checked out, is deleted by them. You
notice you are in a worktree because `git rev-parse --git-dir` and `git rev-parse
--git-common-dir` don't match.

## 4. After the merge — `--merged`

Only when the user says the MR/PR has been merged — or, for the child on the parent branch,
from step 3b as soon as the merge is confirmed. You verify it is true, then close:

```bash
# GitLab — the state is lowercase
glab mr view <number-or-branch> --output json --jq '.state'    # must say "merged"
glab issue close <number>

# GitHub — the state is uppercase, and the issue may already be closed by the `Closes #<number>`
gh pr view <number-or-branch> --json state --jq '.state'       # must say "MERGED"
gh issue view <number> --json state --jq '.state'              # if it is already "CLOSED", don't close it again
gh issue close <number>
```

and bring the **Status:** line to `closed — merged on YYYY-MM-DD`, with today's date — for the
parent, `closed — completed on YYYY-MM-DD`. Locally: `git switch <base> && git pull --ff-only`.
The working branch is deleted only if the server hasn't already done it: on GitLab
`--remove-source-branch` does it, on GitHub the repo's “Automatically delete head branches”
option, and if neither removed it, `git push origin --delete <branch>`.

If the MR/PR state is not `merged`/`MERGED`, close nothing and say so.

### The parent, if the issue is a child

If the head of the issue body has `**Roadmap:** #<parent>`, the child just closed must be
ticked on the parent: it is the only place where you can read how far the project has got.

```bash
# GitLab
glab issue view <parent> --output json --jq '.description' > "$SCRATCH/parent.md"
# GitHub
gh issue view <parent> --json body --jq '.body' > "$SCRATCH/parent.md" && sed -i 's/\r$//' "$SCRATCH/parent.md"

# turn into `- [x]` ONLY the `- [ ] #<number>` line of the Issues section
# bring the parent's “**Status:**” line to `in progress — k of M issues merged`

glab issue update <parent> --description-file "$SCRATCH/parent.md"   # GitLab
gh   issue edit   <parent> --body-file        "$SCRATCH/parent.md"   # GitHub
```

The usual rules: re-read from the server, check the file is not empty, touch only those two
lines. The child's MR/PR carries `Closes #<child>` and **never** the parent's number: the
parent does not close when a child is merged.

For the **child on the parent branch** the parent's **Status:** becomes
`in progress — k of M issues merged into <parent-branch>`, and the parent **does not close**
even when the last box is ticked: the work is in the parent branch, not yet in the target
branch. In the hand-off name the next child — or, if that was all of them, the next step:
`/issue-flow:close <parent>`, which opens the parent's MR/PR.

For the **child** merged directly into the target branch, if after the tick all the boxes of the
Issues section are `- [x]`, the project is finished: bring the parent's **Status:** to
`closed — completed on YYYY-MM-DD` and close it (`glab issue close <parent>`,
`gh issue close <parent>`). Otherwise, in the hand-off, name the next child: the first
`- [ ] #<n>` left, to be started with `/issue-flow:implement <n>` — or
`/issue-flow:implement <parent>`, which finds it by itself.

### The parent

`--merged` on the **parent**, with the parent's MR/PR merged: step 4 as it is, with the parent
branch as the working branch. The children are already closed and ticked; what's left is to
close the parent, if `Closes #<parent>` hasn't already done it, and to delete the parent
branch.

## 5. Hand-off

The MR/PR link, what you verified with the real numbers, the documentation files you had to
update, and what you found out of place and fixed to be able to open it. After a `--merged` on
a child — or a merge at step 3b — how far the parent has got (`k of M issues merged`) and which
child comes next. If you stopped, the reason in one line and what is needed to unblock.

## When to really stop

Stop and ask, instead of opening the MR/PR, if: unticked checkboxes remain; the working tree is
dirty; a verification is red and the cause is not an obvious typo; the branch is behind the
base in a way that merging it brings conflicts to decide; the issue is already closed or
already has an open MR/PR — except, for the child on the parent branch, an MR/PR opened by an
interrupted round, which resumes from step 3b; a pipeline is red, or the server does not merge
the child's MR/PR into the parent branch.
