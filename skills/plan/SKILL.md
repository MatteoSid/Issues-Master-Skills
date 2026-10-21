---
name: plan
description: "Turns the request for a single feature into an issue on the repo's tracker — GitLab or GitHub, depending on the remote — containing the plan and its roadmap: reconnaissance in the code, design decision points asked to the user, phases with atomic checkboxes that the tracker makes tickable, and the instructions to tick them as the work goes. If the work needs more than one issue it notices, warns and proposes how to proceed, including the switch to /issue-flow:big-plan. Triggers: /issue-flow:plan, “open an issue for…”, “write the plan for…”, “tick the roadmap of issue N”; in Italian: «apri una issue per…», «scrivi il piano di…», «spunta la roadmap della issue N»."
argument-hint: "<description of the change>"
---

# /issue-flow:plan

Nothing gets implemented that is not written in an issue. The issue is not a reminder: it is
**the work instruction**, and it contains both the plan and the roadmap that executes it.
Whoever implements reads that and nothing else.

This skill is for **a single feature**: one issue, 5 to 8 phases, one merge request. If the
request is a development that does not fit — several increments, each merged on its own — the
right door is `/issue-flow:big-plan`, which defines the project roadmap and splits it into
issues. It is not up to the user to notice: step 2b always checks it, and if the request does
not fit in one issue you stop, warn and propose how to proceed.

The tracker is **GitLab** (`glab`) or **GitHub** (`gh`) depending on the remote, and the
difference is only in the command: `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` — the `TRACKER.md` file
in this plugin's folder — says which one is used here and how each command translates from one
to the other. Read it before running the session's first command: the commands below come in
both variants, but the traps (the body field that changes name, the `--limit` of
`gh issue list`, the CRLFs) are there. Also read `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md`: it says
when two phases can run together, and it is this skill that decides it and writes it in the
issue.

## Usage

```
/issue-flow:plan <description of the change>   # the normal case: from the request to the issue
/issue-flow:plan                               # uses a plan already approved in this conversation
/issue-flow:plan tick <n>                      # re-read the roadmap and update the ticks
/issue-flow:plan revise <n>                    # reopen an issue's plan and rewrite it
```

The Italian arguments of 1.x — `spunta` and `rivedi` — are still accepted and mean the same.

## The principle that decides everything else

**The issue must be executable by an agent that did not witness the conversation.**

When in doubt whether to write something or take it for granted, apply this test: would another
model, having opened the repo and read only the issue, know which files to touch, what to write
in them and how to tell whether it worked? If not, something is missing.

Everything else follows from this: verified `file.ts:42` references, numbers **measured** and
not estimated, decisions written with their rationale, an explicit out of scope.

## The host project

This plugin knows nothing about the project it runs on, and must not make it up. The things it
needs are derived like this, in this order:

**The target branch.** `${user_config.default_branch}` if the user configured it, otherwise
from the repo:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' \
  || git branch --show-current
```

**The verification commands.** `${user_config.verify_commands}` if configured. If they are not,
you derive them from the project during reconnaissance and **write them in the issue**, so the
verification phase has real commands and not a generic “run the tests”: the scripts in
`package.json`, the targets of the `Makefile`, `pyproject.toml`/`tox.ini`, the CI jobs in
`.gitlab-ci.yml` or `.github/workflows/`. The project's `CLAUDE.md`, if there is one, almost
always states them already.

**What must be kept aligned at the end.** `${user_config.docs_paths}` if configured, otherwise
the documentation files the project actually has — `README.md`, `docs/`, a changelog — and that
the change would make false.

**How to prepare a fresh checkout.** Only needed if the issue has parallel phases, each working
in its own git worktree: a worktree is born without installed dependencies and without the
files git ignores. The command — `npm ci`, `uv sync`, `poetry install`, copying a
`.env.example` — is derived like the verification ones, tried if it is cheap, and written in
the issue's **Context**.

If one of these cannot be derived and is needed, ask the user: it is a single question, and it
holds for all the issues to come.

## Process

### 0. Which tracker, and does it answer

First thing, the platform: `git remote get-url origin` — `github` in the URL means `gh`,
`gitlab` means `glab`. Then that it really answers:

```bash
glab auth status && glab issue list --all              # GitLab
gh   auth status && gh   issue list --state all        # GitHub
```

Authentication is interactive and **you cannot do it**: if it is missing, stop and ask the user
for `glab auth login --hostname gitlab.com` or `gh auth login --hostname github.com`. If
instead the command gives a 404 or “could not determine base repo”, the remote is an SSH alias,
and the remedy is in `TRACKER.md` §2 — one line per platform. If the remote is neither GitHub
nor GitLab, or the CLI that would be needed is not installed, stop and say so: an issue is not
opened by hand.

### 1. Work as in plan mode, without entering it

**Never call `EnterPlanMode` or `ExitPlanMode`.** `ExitPlanMode` ends with the proposal to
implement the plan, and here the plan is not implemented: it is written in the issue, and
implementing it is the job of `/issue-flow:implement`. The way of working, however, is the same
as plan mode, and it holds from here until the issue is created:

- **read only.** Until step 5 you modify nothing in the repo: no `Edit` or `Write` on the
  project's files, no commands that change state. You read, search, measure. The only file you
  write is the issue body, in the scratchpad;
- **questions are asked as you go.** The decision points of step 3 are asked with
  `AskUserQuestion` as soon as reconnaissance brings them up, as plan mode would: do not pile
  them up for a single burst at the end, and do not leave them implicit;
- **the plan is presented before opening the issue.** Once the decision points are settled,
  write a summary of the plan in chat: what changes, the constraints found in reconnaissance,
  the decisions taken on your own with the rationale, the phases with one line each. Then ask
  with `AskUserQuestion` — this is the place for approval, not `ExitPlanMode` — with three
  options: “Open the issue” (Recommended), “Change something” (the user says what, you fix the
  plan and ask again), “Drop it” (you open nothing and stop);
- **only “Open the issue” leads to step 5.** Never offer to implement, neither as an option of
  the question nor in the hand-off message.

If the plan has already been approved in this conversation — the user used plan mode on their
own and approved it, or it is `/issue-flow:plan` with no arguments — skip the summary and the
approval question: the reconnaissance is done, run the check of step 2b and, if the request
fits in one issue, go to steps 4 and 5.

### 2. Reconnaissance in the code — not skippable

A request is an intention; the issue is an instruction. This step makes the difference.
**Before writing a line of plan:**

- identify the files the change will touch and **actually read them**, do not infer them from
  their names;
- note the line numbers the issue will have to cite, and verify them;
- **measure, do not estimate.** What the project already has on disk is real data: how many
  lines the file you are about to split has, how many calls the function you are about to
  change has, how many records have the field populated, how big the bundle is today. A number
  measured in reconnaissance is worth ten sentences of plan, and it is what makes the final
  phase verifiable;
- look for the implicit constraints the plan will have to respect: invariants written in
  comments, serializations that cannot digest certain types, caches or files on disk that would
  be invalidated, schema migrations, imports that would create a cycle, **mirrored fields**
  between backend and frontend that must change together or will not compile;
- **backward compatibility is almost always a constraint**: data already written, responses
  already cached, clients already out there must keep working after the change. Every new
  field is born with a default, every rename carries its readers along.

Every constraint you discover that the request did not foresee goes in the issue, not resolved
silently.

### 2b. Does it fit in one issue? — not skippable

This check is not optional and does not wait for the end: you do it **during** reconnaissance,
and as soon as the answer is no you stop, without completing a detailed reconnaissance that
would serve an issue that will not be opened. It also holds when the plan arrives already
approved from the conversation, and in `revise <n>` when the rewrite makes the issue grow.

The request does **not** fit in one issue if even one of these holds:

- the phases, verification and wrap-up included, would be more than 8;
- the work naturally splits into increments that can be merged one at a time, each leaving the
  product working — the data model, then the API, then the interface;
- it touches several areas of the system that are reviewed separately — services, packages,
  backend and frontend with a new contract between them;
- the final merge request would touch so many files that it could no longer be reviewed in one
  reading.

**Do not compress** a big development into huge phases to make it fit in eight: a phase that
does not close in one subagent does not close. And do not decide on your own to split it: the
choice is the user's.

#### The warning

Before the question, write a short, concrete warning in chat:

- **that the request does not fit in one issue**, said up front and without beating around the
  bush;
- **why**: the signals above that apply, with the numbers measured in reconnaissance — how many
  areas, how many files, how many phases it would take — and not impressions;
- **the split you propose**: the issues that would come out of it, in execution order, one line
  each with what it delivers and which one it depends on. It is a draft, not the roadmap: it
  serves the user to understand what size we are talking about and to choose.

#### The question

Then `AskUserQuestion`, with these options — in the description of each, write concretely what
happens next, with the numbers of the draft:

- **“Switch to /issue-flow:big-plan”** (Recommended): a parent issue with the roadmap and the N
  children of the draft, executed in waves;
- **“Open only the first issue”**: this skill continues with the first increment of the draft;
  the rest goes into the issue's **Out of scope**, one point for each of the following issues,
  so it is not lost;
- **“Narrow the scope”**: the user says what goes in; you restart from the check with the new
  scope;
- **“Keep a single issue”**: the user takes responsibility for it. You continue even beyond 8
  phases, and the issue's **Context** must state that the size is a declared choice, with the
  numbers that would have made it split.

#### How to proceed

- with **big-plan**: load the `issue-flow:big-plan` skill right away with the `Skill` tool, in
  the same conversation, passing it the original request. The reconnaissance done so far is not
  thrown away: `big-plan` picks it up from where you got to and starts from the draft split.
  From that moment `big-plan` applies, not this skill;
- with **only the first issue** or **narrow**: go back to reconnaissance for the new scope —
  the issue's `file:line` references and numbers must concern what the issue actually does —
  and continue from step 3;
- with **a single issue**: continue from step 3.

### 3. Ask only the real decision points

Use `AskUserQuestion` when two readings of the request would lead to different work — the
layout of a table, which columns, whether something goes in or stays out. Not for choices with
an obvious default: those you take yourself and **declare** in the final message, with the
rationale, so the user can overturn them.

For layout choices add a `preview` with an ASCII sketch: they can be compared at a glance and
the user answers in two seconds.

### 4. Title and branch

The title says **what changes for whoever uses the product**, not which file is touched: a short
lowercase sentence, with no final period. The number is the one the tracker assigns, and it is
read from the URL the creation command prints.

The working branch is `${user_config.branch_prefix}<number>-<short description>` — with the
default `issue-`, issue #12 “add a date filter to the list” is worked on
`issue-12-add-a-date-filter-to-the-list`. The short description comes from the title — lowercase
ASCII, words joined by `-`, cut at 40 characters on a word boundary — and the script that
decides every branch name of the plugin builds it:

```bash
BRANCH_PREFIX='${user_config.branch_prefix}' "${CLAUDE_PLUGIN_ROOT}/scripts/branch-name.sh" issue <number> "<title>"
```

The number exists only after the issue is created, so the **Planned branch** line of the body
is filled in at step 5, right after the creation.

### 5. Write the issue

Follow `TEMPLATE.md`, the file next to this one, which describes its sections one by one. Write
the body in a temporary file and create the issue from there:

```bash
glab issue create --title "<title>" --description-file <file> --yes   # GitLab
gh   issue create --title "<title>" --body-file        <file>         # GitHub
```

The file avoids passing a long body inside shell quotes. The assigned number is the one the
command prints in the URL: read it from there, do not infer it.

Then the **Planned branch** line, which the body could not carry before the number existed:
the name from `branch-name.sh issue <number> "<title>"` (step 4), written with the usual round
— re-read the body from the server, replace the line, check the file is not empty, send it
back up (`TRACKER.md` §4). It is the name `/issue-flow:implement` will use, and the one the
user can look for in `git branch`.

### 6. Hand-off

In a few lines: the link, what you found in reconnaissance that the request did not foresee,
the decisions you took on your own with their rationale, and what you left out of scope. Do not
paste the issue into the reply: it is a page, the user opens it.

## The roadmap

It is the reason the issue exists, and it lives **inside the issue**, in the Plan section, as
phases with checkboxes. Both GitLab, which shows “0 of N tasks completed” and counts them in
`task_completion_status`, and GitHub, which shows “0 of N tasks” at the top of the issue,
recognize them as task lists and make them clickable. The count via API, however, exists only
on GitLab: the method that holds on both is counting the lines in the body, and it is the one
`/issue-flow:implement` and `/issue-flow:close` use (`TRACKER.md` §5).

### The phases

A phase is **a piece of work that closes**: it leaves the repo in a coherent and verifiable
state. Not a day, not a thematic area. 5 to 8 phases is the normal range.

Two phases are mandatory and always go at the bottom, in this order:

- **the second to last is verification**, and includes the project's commands — those
  configured in `${user_config.verify_commands}` or those you derived in reconnaissance — plus
  a manual check on what the issue promised would be visible. If the change touches the
  interface, also the keyboard check, responsiveness and accessibility;
- **the last is the wrap-up**: the documentation files that must be rewritten, named one by
  one, and the commit on the issue's branch. The MR/PR **is not a roadmap checkbox**: it is
  opened by `close`, which `/issue-flow:implement` runs by itself when all the phases are
  closed.

A third is conditional: if `${user_config.figma_file}` is configured and the change touches the
frontend, **the first phase is Figma**. You work with the `figma:figma-use` skill and the
`use_figma` tool; Figma is aligned **before** the code, not after, because the code adapts to
Figma and not the other way round; existing components are restructured in place and not
recreated, otherwise the instances get detached. If the configuration is empty, this phase does
not exist: do not invent it.

### Parallel phases

When possible, the phases run together: each with its own checkbox agent, each in its own
worktree. Whether it is possible is decided by **you, here**, because you are the only one who
did the reconnaissance: whoever executes the issue finds it written and does not reinvent it.
The conditions are those of `PARALLEL.md` §2 — disjoint scopes, no phase that needs the other's
code, a written contract, no shared resource in verification — and they must be checked against
the files read in reconnaissance, not against the phase titles.

How it is written is in `PARALLEL.md` §3 and in the template: the **Execution** line at the top
of the Plan, always, and for each phase of a group the **Scope** — exhaustive: the phase touches
those files and nothing else — and the **Contract** with the sibling phases of the group, with
the exact names and shapes of what they share. You write the contract: two agents in parallel do
not see each other, and their work fits together only if you decided it beforehand.

Parallelism is often obtained by moving the boundary: a phase that fixes the interface — the
type, the signature, the schema — and after it two phases that rest on it from different sides.
Do not invent it where there is none: verification, wrap-up and Figma always stay in sequence,
and **when in doubt, in sequence**.

### The checkboxes

- **Total coverage.** Every piece of work has its own: code, models, mirrored types between
  backend and frontend, interface strings, documentation lines, verifications. Work that does
  not have a checkbox is work that will be forgotten.
- **Atomic.** One checkbox = one thing that can be ticked without reservations. If to tick it
  you have to say “yes, but halfway”, it should have been split in two.
- **Verifiable from the outside.** `- [ ] every new field has default ""` can be checked;
  `- [ ] understand how the filter works` cannot: it is not a checkbox, it is a thought.
- **Imperative and concrete.** Name the file, the function, the line: better
  `- [ ] src/api/user.ts:104, UserOut gains the five fields with default ""` than
  `- [ ] update the API`.
- **Self-contained.** It must not depend on something said only in chat.

When the decision is already taken and the how is already established, put under it the code
fragment that defines it: a checkbox followed by three lines is worth a paragraph.

## How to tick — and why it goes in the issue

Every issue produced by this skill **must contain the “How to update this roadmap” section** of
the template. It is not ceremony: the roadmap serves whoever picks up the work after a
`/clear`, and a roadmap that does not state its own status is useless.

The rule, which holds both for the user and for you:

- you tick **as you go**, at the end of each piece, not when the work is finished;
- you tick **at the same moment** the work is done and verified, and the tick goes into that
  phase's commit;
- if a decision changes during implementation, you **rewrite the line** of the roadmap: a
  roadmap that lies is worse than no roadmap.

The round to update it, which is also what `/issue-flow:plan tick <n>` does:

```bash
# GitLab — the body field is called `description`
glab issue view <n> --output json --jq '.description' > "$SCRATCH/roadmap.md"

# GitHub — it is called `body`, and it often arrives with CRLF terminators
gh issue view <n> --json body --jq '.body' > "$SCRATCH/roadmap.md"
sed -i 's/\r$//' "$SCRATCH/roadmap.md"

# turn the done `- [ ]` into `- [x]`, touch the “Status:” line if the phase is closed

glab issue update <n> --description-file "$SCRATCH/roadmap.md"    # GitLab
gh   issue edit   <n> --body-file        "$SCRATCH/roadmap.md"    # GitHub
```

**Always re-read the body from the server before rewriting it**, never from a copy kept in the
conversation. The update replaces the whole field and does not merge: if the user ticked a box
from the page while you were working, rewriting an old version erases it. For the same reason,
check that the file you just wrote is not empty: a `jq` on the wrong field gives `null`, and
sending it back empties the issue.

When all of an issue's checkboxes are ticked and the work is merged, it gets closed —
`glab issue close <n>` or `gh issue close <n>` — and the “Status:” line goes to
`closed — merged on YYYY-MM-DD`. On GitHub it may have closed by itself, if the PR carried
`Closes #<n>`: check the state before saying you closed it.

## Who executes the issue

Not this skill: `/issue-flow:implement <n>` takes it, sends one phase per subagent and ticks the
boxes as it goes, then goes on by itself with `/issue-flow:close <n>`, which verifies the final
tree and opens the MR/PR for the user to preview; once they have merged it, `--merged` closes
the issue. Write the roadmap knowing that it will be read by an agent
that witnessed nothing — that is the reason the phases must be self-contained.

The same rules hold for the child issues of `/issue-flow:big-plan`: they are written by the
`issue-flow:issue-writer` subagent following this skill and `TEMPLATE.md`, with the **Roadmap**
and **Depends on** lines added at the top. `/issue-flow:plan revise <n>` works on them too: if
the child has the **Roadmap** line, re-read the parent before rewriting it and do not
contradict its decisions.

## How to write

Dense prose, in the user's language with the markers verbatim in English (`TRACKER.md` §6),
technical terms and identifiers in the original. Sentences that carry information: the *why* of
a choice, not its paraphrase.

- no estimates in hours or days, no story points, no percentages;
- no `TBD`, “to be defined”, “consider whether”: if a decision is not taken, take it now or
  write it as an open question with who must answer it;
- code references always as `path/file.ts:42`, verified in reconnaissance;
- numbers always measured, stating **where** they were measured;
- bold only where a decision changes, not at random.
