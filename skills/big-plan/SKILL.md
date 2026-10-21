---
name: big-plan
description: "Turns a large development — more than fits in one issue — into a project roadmap on the repo's tracker, GitLab or GitHub: a parent issue with goal, architecture and decisions, and the child issues that execute it in waves — the children of a wave together, with agreed scopes and contracts — each complete with plan and checkboxes and written by a dedicated subagent. Triggers: /issue-flow:big-plan, “plan the project…”, “split into issues…”, “make the roadmap for…”; in Italian: «pianifica il progetto…», «dividi in issue…», «fai la roadmap di…»."
argument-hint: "<description of the development>"
---

# /issue-flow:big-plan

`/issue-flow:plan` is for **one** feature: one issue, 5 to 8 phases, one merge request. When the
development doesn't fit — a new subsystem, a migration in several stages, a feature that cuts
across backend, data and interface — this skill makes it a **project**: a parent issue that
holds the overall roadmap, and the child issues that execute it in **waves** — the children of
a wave together, one wave after the other — each with its own branch and its own MR/PR.

Everything `plan` says applies here too, and is not repeated: `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md`
— this plugin's `plan` skill — for the principle (“the issue must be executable by an agent
that did not witness the conversation”), the host project, the reconnaissance, the phases, the
checkboxes, how to tick and how to write. `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` for the commands
of the two platforms and their traps. `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md` for when two
children, or two phases, can work together and for how it is written. **Read all three before
the first command.**

## Usage

```
/issue-flow:big-plan <description of the development>   # from the request to the parent and the children
/issue-flow:big-plan                                    # uses a roadmap already approved in the conversation
```

### When you come from `/issue-flow:plan`

`plan` always checks whether the request fits in one issue, and when it doesn't it warns the
user and proposes switching here. If the user accepts, this skill is loaded in the same
conversation, and some work is already done: the tracker verified, the reconnaissance up to the
point where `plan` stopped, a draft split into issues that the user has seen.

Don't redo it. Skip step 0, **complete** the reconnaissance of step 2 only where it isn't
enough for a roadmap — typically the overall architecture and the cross-cutting constraints,
because `plan` was looking closely at the first piece — and at step 3 start from `plan`'s draft
instead of from scratch: correct it where the full reconnaissance requires it, and in the
summary of step 4 say what changed compared to the draft the user had seen.

### When you come from `/issue-flow:roadmap`

`roadmap` proposes the project's next steps by reading its documentation, and when the user
chooses “Create the issues” it loads this skill in the same conversation. Here too some work is
done: the tracker verified, the sources read, a roadmap **approved** by the user, with one step
per child, the sources of each and the dependencies.

Skip step 0. The reconnaissance of step 2, instead, must be done: `roadmap` looked at **what**
to do, not **how** — the architecture touched and the cross-cutting constraints between the
steps are missing. At step 3 the roadmap's steps are the children: the roadmap's goal becomes
the parent's **Goal**, its **Waiting on**, **Later** and **Left out** go into the **Context**
and the **Out of scope**, and the sources of each step (registry IDs, document sections,
issues) are passed to the writer of its child, who cites them in the Context.

If the reconnaissance doesn't change the split, the roadmap is already approved: skip the
summary and the question of step 4 and go to step 5. If it changes it — a step must be split,
two must be merged, a dependency doesn't hold — step 4 is done, and the summary says what
changed compared to the approved roadmap and why.

In the hand-off of step 9, if the roadmap came from research-flow's registries, add the mapping
between children and entries (`#21 ← TODO-012, ESP-031`) and propose `/research-flow:annota`
to mark them `in corso` (in progress) with their issue: the registries are written by
research-flow, not by this skill.

## You are the roadmap agent

You define the roadmap, make the decisions with the user, open the parent, **delegate** the
writing of each child to a subagent and then check and create everything on the tracker. You
don't write the children's bodies yourself.

You are also the one who **agrees on the work**: the writers write the children all together,
and the children of a wave will be executed all together. Neither the writers nor whoever will
execute the children see each other: their work fits together only because you decided
beforehand who touches what and with which names — scopes and contracts, `PARALLEL.md` §1.

The reason is the same as for `/issue-flow:implement`: each child requires its own
reconnaissance in the code — files actually read, lines verified, numbers measured — and all of
them done in here would fill the context until the overall view is lost, which is the only
thing that only you have. The subagent starts clean, reads only what its issue needs, and hands
you a body to check.

## Process

### 0. Which tracker, and does it answer

Identical to step 0 of `plan`: `git remote get-url origin`, then `glab auth status` or
`gh auth status` and an `issue list` that answers. If authentication is missing, stop and ask
the user to do it: it is interactive.

### 1. Work as in plan mode, without entering it

The same rules as step 1 of `plan`: **never `EnterPlanMode` nor `ExitPlanMode`**, read-only
until the parent is opened, decision points asked as they come with `AskUserQuestion`, approval
with `AskUserQuestion` and not with `ExitPlanMode`, and **never offer to implement**.

### 2. Overall reconnaissance — not skippable

Wider than `plan`'s, less deep: here you don't yet need all the `file:line` references of every
phase — the writer of each child finds those — but you do need to know how the piece of the
system the development crosses is made.

- **the architecture touched**: which modules, services, packages; where the boundaries between
  them run; who calls whom. Read the entry files, don't infer them from the names;
- **the cross-cutting constraints**, those that apply to several children and that none would
  see on its own: the data schema and its migrations, the mirrored fields between backend and
  frontend, the caches, the clients already out there, backward compatibility;
- **the measured numbers** that size the work: how many lines, how many callers, how many
  records, how many endpoints;
- the host project as in `plan`: target branch, verification commands, documentation to keep
  aligned, the command to set up a worktree and the resources a worktree does not isolate.
  Derive them once here and pass them to all the writers;
- **where the boundaries between the children run**: which files each would touch, and which
  magnet files (`PARALLEL.md` §2) more than one would touch. It is what decides the waves.

### 3. The breakdown

It is the work this skill does and `plan` doesn't. The rules:

- **an issue is an increment that merges on its own.** After the merge of each child the
  product compiles, the tests pass and nothing that worked has broken. No “half backend” issue
  that leaves the target branch broken until the sibling arrives: if two pieces don't stand up
  separately, they are a single issue, or the first one goes behind a flag;
- **each child fits in `plan`'s 5–8 phases**, verification and wrap-up included. If one
  doesn't fit, it must be split; if two together fit comfortably, they must be merged;
- **the order is explicit and the dependencies are declared.** A child starts from the code the
  children it depends on have merged. Put first what removes uncertainty — the data model, the
  interface between two modules — and after it what rests on it;
- **the children are in waves.** Two children that don't depend on each other and meet the
  conditions of `PARALLEL.md` §2 — disjoint scopes, neither needing the other's code, a written
  contract, no shared resource in verification — go in the same wave, and `big-implement` will
  execute them together. A wave starts when the previous one is all merged. Parallelism often
  comes from putting first a child that fixes the interface — the schema, the types, the API —
  and after it, in the same wave, those who rest on it from different sides: the backend that
  implements it and the frontend that consumes it. When in doubt, waves of a single child: a
  linear chain is always correct;
- **for every wave with several children, the scope and the contract.** The scope of each
  child: the modules, folders or files it may modify, and the magnet files of `PARALLEL.md` §2
  with their single owner. The contract: what the children of the wave share, with the exact
  name and shape. They are the lines the writers will receive as a constraint and that whoever
  executes will re-check;
- **for each child**: a title that says what changes for whoever uses the product, what it
  delivers, what it leaves to the following ones (types, interfaces, endpoints, files that will
  be created — with the name they will have), what stays out, its wave.

If the breakdown gives **a single** issue, the development isn't large: say so and propose
`/issue-flow:plan`, instead of opening a parent with a single child.

### 4. Present the roadmap and get it approved

With the decision points closed, write a summary in chat: the goal, the architecture in a few
lines, the cross-cutting constraints found, the decisions made on your own with their
rationale, and the list of children split by wave — one line each, with what it delivers and
what it depends on — and for every wave with several children the scopes, one line each. Then
`AskUserQuestion` with three options: “Open the issues” (Recommended), “Change something” (the
user says what, you correct and ask again), “Drop it” (you open nothing and stop).

If the roadmap has already been approved in this conversation — or it is `/issue-flow:big-plan`
without arguments — skip the summary and the question and go to step 5.

### 5. Open the parent

Follow `TEMPLATE.md`, the file next to this one. At this point the **Issues** section has the
lines with a placeholder instead of the number — `- [ ] #(1) title — what it delivers` —
because the children don't exist yet, and so does the **Parallelism** section; you put the
number in at step 8. The parent is opened first because the children must be able to cite it
from the very beginning.

```bash
glab issue create --title "[ROADMAP] <title>" --description-file "$SCRATCH/parent.md" --yes   # GitLab
gh   issue create --title "[ROADMAP] <title>" --body-file        "$SCRATCH/parent.md"         # GitHub
```

The parent's title starts with `[ROADMAP]`, and after it says what the product gains once the
project is finished, as for every issue. You read the number from the URL the command prints.

### 6. Write the children, one subagent per child

One invocation of the `Agent` tool with `subagent_type: "issue-flow:issue-writer"` **for each
child**. The writers read the code and write a file in the scratchpad, nothing more: they don't
step on each other's toes, so **launch them all together, in a single message**.

The writer hasn't seen the conversation: **what you don't write to it doesn't exist**. In the
prompt, in full and not summarized:

- the parent's number and its **Goal**, **Architecture**, **Decisions**, **Context** and
  **Out of scope** sections;
- the complete list of children, with the `#(k)` placeholder, the title and what each one
  delivers: the writer must know what the siblings do so as not to redo it and to say so in its
  out of scope;
- the position of its child — `#(3)`, third of 5, in wave 2 — and **what it will find already
  done** when its turn comes: the types, the interfaces, the files that the children of the
  earlier waves will have created, with the names decided;
- if its wave has several children: **its scope**, the scopes of the wave's siblings and the
  **contract** between them, in full from the parent's **Parallelism** section. The writer
  writes the child within its scope, respects the contract as it is, and if it needs a file
  outside its scope or a name the contract doesn't fix it doesn't take it: it writes it in the
  report, and you decide;
- the target branch, the verification commands, the documentation files and the worktree setup
  command derived at step 2;
- if `${user_config.figma_file}` is configured, the file id: the child that touches the
  frontend will have the Figma phase first;
- the language to write the body in — the user's, `TRACKER.md` §6: the writer does not know it;
- the exact path of the file to write the body in: `$SCRATCH/child-<k>.md`.

### 7. Check the bodies

When the writers come back, re-read **every** file — a subagent's report is a story, the file
is the proof:

- it is not empty, and it has all the sections of `plan`'s template, including “How to update
  this roadmap” in the right platform's variant;
- at the top it has `- **Roadmap:** #<parent>` and, if it has any, the
  `- **Depends on:** #(k)` lines;
- the phases are 5 to 8, with verification second to last and wrap-up last; the checkboxes are
  counted with the `grep`s of `TRACKER.md` §5;
- the Plan has the **Execution** line, and every phase of a parallel group has **Scope** and
  **Contract** (`PARALLEL.md` §3);
- it doesn't do a sibling's work, and doesn't contradict the parent's decisions;
- **the scopes of a wave hold**: line up the files that the children of the same wave name in
  their Plans — the file lines under each phase, the **Scope** lines — and check that no file,
  or section of a file, appears in two children, and that each stays within the scope you had
  given it. An overlap is decided here, not when two runners discover it in a conflict: the
  file goes to a single child, or one of the two moves to the next wave. If the breakdown
  changes, with the user.

If a writer reported a constraint the roadmap didn't foresee, **you decide** — with the user,
if it changes the breakdown — and don't leave it resolved silently inside a child. If a body
doesn't hold up, a **new** writer with the defect spelled out in full; never fix by hand pieces
of reconnaissance you didn't do.

### 8. Create the children and align the references

Create the children **in the roadmap's order**, one at a time, so the numbers grow with the
execution order. The title is the roadmap's; you read the number from the printed URL, you
don't infer it — on GitHub issues and pull requests share the sequence, and someone else may
open an issue in the meantime.

Then the placeholders become numbers:

- in every child that cites a sibling — `**Depends on:** #(2)`, “created by #(2)”, the out of
  scope — `#(k)` becomes `#<number>`;
- in the parent, the **Issues** section becomes `- [ ] #<number> title — what it delivers`, and
  the **Parallelism** section cites the children by their number;
- the **Planned branch** lines take their real name, from the script that decides every branch
  name of the plugin: in the parent `branch-name.sh roadmap <parent> "<title>"` —
  `roadmap-20-notification-preferences`, the branch `/issue-flow:big-implement` works on —, in
  every child `branch-name.sh issue <number> "<title>"` — `issue-21-the-schema`:

  ```bash
  BRANCH_PREFIX='${user_config.branch_prefix}' ROADMAP_PREFIX='${user_config.roadmap_prefix}' \
    "${CLAUDE_PLUGIN_ROOT}/scripts/branch-name.sh" issue <number> "<title>"
  ```

Every rewrite follows the usual rule: **re-read the body from the server**, replace, check the
file is not empty, send it back up (`TRACKER.md` §4). At the end, a `grep -n '#([0-9]\+)'` on
every body re-read must find no placeholders left.

### 9. Hand-off

In a few lines: the parent's link, the list of children with number, title and link in
execution order, split by wave, what you found in reconnaissance that the request didn't
foresee, the decisions made on your own with their rationale, and what was left out. Close with
how to start: `/issue-flow:implement <parent>`, which picks the first open child by itself, or
`/issue-flow:big-implement <parent>`, which carries them all forward, one wave after the other
and the children of a wave together. Don't paste the issues into the reply.

## How the project moves forward

Not with this skill. By hand, the children are executed **one at a time, in order** — within a
wave in any order — with the normal round:

```
/issue-flow:implement <child>           # or <parent>: picks the first child not yet merged, up to its MR/PR
/issue-flow:close <child> --merged      # once merged: closes the child and ticks it on the parent
```

and then the next child, which starts from the target branch with the work of the previous ones
inside. The parent's box is ticked **when the child is merged**, not when it is implemented:
`/issue-flow:close --merged` does it, and it also closes the parent when the last box is ticked.

Or all at once with `/issue-flow:big-implement <parent>`: the same round on the parent branch,
with the children of a wave executed together, each in its own worktree — every child is born
from there and goes back into it with its MR/PR, which `close` merges by itself after the usual
checks, one child at a time, as a single squash commit fast-forwarded onto the parent branch —
one commit per child, in order. At the end the parent's MR/PR brings everything into the target
branch, and the user merges it; then `/issue-flow:close <parent> --merged`.

If during execution a child discovers that the roadmap no longer holds — a decision of the
parent turns out to be wrong, a later child must be redone — the remedy is to fix the issues
before the code: `/issue-flow:plan revise <n>` for the child, and the parent rewritten by hand
with the usual rule.
