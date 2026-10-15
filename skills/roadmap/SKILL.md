---
name: roadmap
description: "Proposes the roadmap of a project's next steps by reading its documentation — the research-flow registers if the repo has them, otherwise README, CLAUDE.md, docs, a previous ROADMAP.md — plus the open issues on the tracker and the state of the code. Every step has its source, its order and its dependencies, and is sized like an issue. Once approved, saves it as ROADMAP.md at the repo root or hands it to /issue-flow:big-plan, which creates all its issues. Triggers: /issue-flow:roadmap, “what are the next steps?”, “propose a roadmap”, “what do we do now?”, “where do we pick up from?”; in Italian: «quali sono i prossimi passi?», «proponi una roadmap», «cosa facciamo adesso?», «da dove ripartiamo?»."
argument-hint: "[optional focus: an area, a goal, a milestone]"
---

# /issue-flow:roadmap

`/issue-flow:plan` and `/issue-flow:big-plan` start from a request: someone already knows what
they want to do. This skill comes before, when the question is **what do we do now**. It reads
what the project knows about itself — the documentation, the open issues, the code — and
proposes the next steps in order, each with the reason it sits there and the source it comes
from.

The approved roadmap has two outputs, at the user's choice:

- **a file**, `ROADMAP.md` at the repo root, to keep and re-read;
- **the issues**: the skill hands the roadmap to `/issue-flow:big-plan`, which turns it into a
  parent issue and one child per step, each written in full.

Read `${CLAUDE_PLUGIN_ROOT}/skills/plan/SKILL.md` — this plugin's `plan` skill — for how to
write and for the size of an issue, `${CLAUDE_PLUGIN_ROOT}/TRACKER.md` for the commands of the
two platforms and `${CLAUDE_PLUGIN_ROOT}/PARALLEL.md` §2 for when two steps can be executed
together. **Read them before the first command.**

## Usage

```
/issue-flow:roadmap                      # the project's next steps, from all the documentation
/issue-flow:roadmap <focus>              # only an area or a milestone: “the frontend”, “going live”
```

## The principle

**Every step of the roadmap has a source that can be re-checked.** A register ID, a section of a
document with its path, an issue, a `file:line`. What you propose on your own — a risk the
documentation does not see, a step missing between two that are there — can be proposed, but it
is declared as **our proposal**, with the reason: the user must be able to tell what the project
says about itself from what you infer from it.

The practical consequence: a roadmap is not written from memory of what was seen in the
conversation. It is written after reading the sources in this session.

## Process

### 0. Which tracker, and does it answer

Same as step 0 of `plan`. Here, though, the tracker is not indispensable: it serves to know what
is already open, and for the “issues” output. If it does not answer and authentication is the
problem, ask the user to do it; if the user prefers to go on without it, proceed, state in the
roadmap that the open issues were not looked at, and the “issues” output is not offered.

### 1. Work as in plan mode, without entering it

The same rules as step 1 of `plan`: **never `EnterPlanMode` or `ExitPlanMode`**, read-only until
approval, decision points asked as they come up with `AskUserQuestion`, approval with
`AskUserQuestion`, and **never offer to implement**.

### 2. The sources

They are read in this order, and each one says what is found and where.

#### a. research-flow, if the repo uses it

The signal is the `.research-flow.json` file at the repo root. **If it is not there, skip this
section**: the research-flow plugin is not a requirement, and without its registers the roadmap
is made from sources b–d.

If it is there, the configuration gives the folder (`dir`), the names of the five registers and
of the official document (`ufficiale`). They are the main source, because they are written
precisely to say what we know, what is missing and what is to be tested. From each one you need
only one part:

| document | what you take from it |
|---|---|
| official (`stato_progetto.md`) | §«Prossimi passi» (next steps), §«Cosa manca» (what is missing), §«Cosa è da testare» (what is to be tested), §«Dove potremmo sbagliare» (where we could be wrong), §«Cosa non abbiamo capito» (what we have not understood); §«Strade scartate» (discarded paths), so as not to propose again what an experiment has already rejected; the date at the top, **Aggiornato al** (updated on) |
| to do (`TODO`) | the open P0 and P1 items per phase, «In corso» (in progress) and the questions in «Da chiedere alle fonti» (to ask the sources) |
| experiments (`ESP`) | the proposed ones, with their success criterion |
| hypotheses (`IP`) | those still to verify that support a choice in force, with the impact if they are wrong |
| doubts (`DUB`) | the open ones that touch code the steps will work on |

The registers can be long: do not read them in full. If the research-flow plugin is installed,
its script gives the state without opening the files:

```bash
RF=$(jq -r '.plugins["research-flow@research-flow"][0].installPath // empty' \
       ~/.claude/plugins/installed_plugins.json 2>/dev/null)
python3 "$RF/scripts/registri.py" riepilogo   # items per register and per status
python3 "$RF/scripts/registri.py" check       # among other things: is the official document older than the registers?
python3 "$RF/scripts/registri.py" find TODO-012   # one item, who cites it, its status
```

If `$RF` is empty or the script is missing, work on the files the configuration points to, with
`grep` on the statuses and on the section headings: the registers are markdown, readable without
it too.

**If the official document is older than the registers** — `check` flags it, or the date at the
top predates the latest items — the registers win: the roadmap starts from them, you say so in
the summary, and you propose `/research-flow:stato` to realign the official document. Do not
rewrite it yourself: research-flow's documents are written by research-flow's skills.

In an exploratory project part of the next steps is not code: an experiment, a measurement, a
question to a source. Experiments and measurements that need scripts or code changes **are**
steps, and become issues like the others; questions to the sources and waits (data to
accumulate, an answer that has to arrive) are not: they go under **Waiting on**, and the steps
that depend on them say so.

#### b. The project's documentation

Always, with or without research-flow:

- `ROADMAP.md` at the root, if there is one: it is the roadmap of a previous round. **Compare it
  with today's state** — which steps were done (issues closed, code present), which were
  dropped, which remain — and say so in the summary;
- `CLAUDE.md` and `README.md`: the project's goal, the phases or the roadmap if they declare
  them, the constraints;
- `${user_config.docs_paths}` if configured, otherwise `docs/`, a `TODO.md`, a `CHANGELOG` if
  there are any: for the things announced and not yet done.

#### c. The tracker

The open issues, with a high `--limit` on GitHub (`TRACKER.md` §5):

- the open **parents** — `[ROADMAP]` at the start of the title, `**Type:** roadmap` at the top
  of the body; parents opened by earlier versions have only the latter — with children not yet
  ticked: it is work already planned. It is not proposed again: the roadmap cites it as
  **already open** and starts after it, or builds on it as a dependency;
- the open single issues: if a step you are about to propose already has its issue, the step
  cites it instead of duplicating it.
- **the issues the sources cite** — “in progress (#29)”, “#48 still to merge” — are checked on
  the tracker one by one: a source that gives as in progress an issue that is already closed is
  an inconsistency to flag, and the step that depended on it may already be unblocked.
  `registri.py check` does not see it: it checks the consistency of the registers among
  themselves, not with the tracker.

#### d. The code and the history

It serves to verify, not to invent steps:

- `git log --oneline -30` and the open branches: what is being worked on right now;
- for every candidate step, **check in the code that it is not already done.** A TODO left open
  in the register, a README line never updated, a forgotten open issue are the normal case, not
  the exception. A step that turns out to be already done does not go in the roadmap: you flag
  it in the summary, because the source that listed it as to do needs correcting.

The `file:line` reconnaissance of every phase is not needed here: `big-plan` and its writers do
it, if the roadmap becomes issues.

### 3. The focus, if there is one

With an argument, the roadmap covers only that area or that milestone. All the sources are read
anyway — a step outside the focus can be a dependency of one inside it — but only the focus's
steps and their dependencies, declared as such, go into the roadmap.

Without an argument, if the sources point in more directions than fit in a single roadmap — two
project phases open at once, two areas that do not touch — ask with `AskUserQuestion` which one
to concentrate on, with one line per direction and the sources that support it.

### 4. Build the roadmap

The rules:

- **a step is an issue.** Every step is the size of a `plan` issue: an increment that merges on
  its own, 5 to 8 phases. If a step is bigger, split it; if two are small and touch the same
  thing, merge them. It is the condition for `big-plan` to make one child per step;
- **first what removes uncertainty.** The P0s, the high-impact hypotheses other steps rest on,
  the experiments whose outcome decides between two paths, the data model before whoever uses
  it. Then what gets built on top;
- **the order is explicit and the dependencies are declared**, and the steps sit in **waves**
  like the children of `big-plan`: two steps that do not depend on each other and touch
  different parts of the code — looked at in the code, not from the title — go in the same
  wave, and will become children that `big-implement` executes together. Here the coarse
  boundary is enough: the modules or folders of each, and the files both would touch
  (`PARALLEL.md` §2). Exact scopes and contracts are fixed by `big-plan` after its
  reconnaissance, and it can change the waves. When in doubt, single-step waves;
- **operational constraints weigh on the order.** A test that is running and must not be
  interrupted, an environment that cannot be restarted, a freeze before a release: look for them
  in the sources and see which steps touch them — in the code, not from the title. If a
  constraint blocks half the steps, how to order them is a decision point to ask the user about,
  not a choice to make on your own;
- **the horizon stops at the first decision point that cannot be decided now.** If a step
  depends on the outcome of an experiment or on a source's answer, the roadmap goes up to there
  and after it writes the two branches, one line each, under **Later**. Planning in detail
  beyond an outcome nobody knows yet is guessing;
- **3 to 8 steps.** Fewer than 3 is not a roadmap: with a single step propose
  `/issue-flow:plan`, with two consider whether they are a single issue. More than 8 means the
  horizon is too long: the steps beyond the eighth go under **Later**;
- **for every step**: a title that says what changes for whoever uses the product — like the
  title of an issue —, what it delivers, why it sits there with the sources (`TODO-012`,
  `ESP-031`, `README.md` §Roadmap, `#45`, `backend/app/x.py:88`), which step it depends on, its
  wave and — if the wave has other steps — where it touches the code, whether it closes or makes
  verifiable something (a hypothesis, a doubt, a success criterion).

Set aside, for the summary and for the file:

- **Waiting on**: the questions to the sources, the data to accumulate, the decisions that are
  up to someone else, with the steps that depend on them;
- **Later**: what comes beyond the horizon, one line per item;
- **Left out**: what the sources give as to do and you did not put in the roadmap, with the
  reason (already done, superseded by a decision, out of focus, low priority). It is the section
  that lets the user say “no, this goes in”.

### 5. Present it and get it approved

Write a summary in the chat:

- **the sources read**: whether there was research-flow and what date the official document
  has, the previous `ROADMAP.md` and what is left of it, the open issues found; if you read
  documents with uncommitted changes, say so (`git status`), because the roadmap rests on that
  version;
- **where we are**, in three or four lines;
- **the steps**, numbered and split by wave, one line each with what it delivers, the sources
  and the dependency;
- the **Waiting on**, the **Later** and the **Left out**, brief;
- the inconsistencies found between sources and code (steps already done but open in the
  registers, forgotten issues), so that someone corrects them.

Then `AskUserQuestion`, with these options — in the description of each one write concretely
what happens next, with the roadmap's numbers:

- **“Create the issues with big-plan”**: a parent with the roadmap and one child per step,
  written by `big-plan`;
- **“Save to ROADMAP.md”**: the file at the repo root, nothing on the tracker;
- **“Change something”**: the user says what, you correct it and ask again;
- **“Drop it”**: you write nothing and stop.

**Recommended** goes to “Create the issues” when all the steps are concrete, decided work, to
“Save to ROADMAP.md” when the roadmap is mostly exploratory — steps waiting on outcomes,
decision points close by — and opening issues now would mean rewriting them soon. If the user
asks for both, with the free-text answer, first save the file and then move on to `big-plan`. If
the tracker is missing, “Create the issues” is not offered.

### 6a. Save to `ROADMAP.md`

The file is `ROADMAP.md` at the repo root (`git rev-parse --show-toplevel`), and it follows
`TEMPLATE.md`, the file next to this one.

If it already exists, you read it in step 2: it is **rewritten**, not appended to — it describes
today's next steps, and the old version stays in git history. In the hand-off summary say what
changed compared with it.

Do not commit: the file stays in the working tree, and tell the user so. If the project uses
research-flow and the roadmap diverges from §«Prossimi passi» of the official document, propose
`/research-flow:stato` to align it; do not touch its documents yourself.

### 6b. Create the issues with `big-plan`

Load the `issue-flow:big-plan` skill with the `Skill` tool, in the same conversation. From that
moment `big-plan` is in charge: it knows it comes from here (its section “When you come from
`/issue-flow:roadmap`”) and reuses what you have already done: the verified tracker, the sources
read, the approved roadmap as the draft of the split into children.

In the handover it must receive, already written in the conversation in the step 5 summary:

- the roadmap's goal, which becomes the parent's **Goal**;
- the steps with title, what they deliver, sources, dependencies, wave and where they touch the
  code: one child per step, and the waves as a draft of the parent's;
- **Waiting on**, **Later** and **Left out**, which end up in the parent's **Context** and **Out
  of scope**;
- if the roadmap comes from research-flow, the mapping between steps and register items
  (`step 2 ← TODO-012, ESP-031`), so that the hand-off says which items to mark `in corso` with
  their issue.

### 7. Hand-off

For the file output: the file's path, what changed compared with the previous roadmap, the
inconsistencies found between sources and code, and how to start — `/issue-flow:plan` on the
first step, or `/issue-flow:roadmap` again with “create the issues” once the decision points are
decided.

For the issues output, the hand-off is done by `big-plan`.

Do not paste the roadmap in the final answer: the user already saw it in step 5, and the file or
the parent is where it gets re-read.

## How to write

As in `plan`: dense prose, in the user's language with the markers in English (`TRACKER.md`
§6), identifiers in the original, no estimates in hours or days, no `TBD`. In addition:

- sources are **always** cited with their precise reference — ID, path and section, issue
  number — never “as the documentation says”;
- **our proposal** in bold where a step or a reason does not come from a source;
- the steps of an exploratory project say **what we will know** afterwards, not only what we
  will do: “after this step we know whether IP-014 holds” is worth more than “implement the
  backtest”.
