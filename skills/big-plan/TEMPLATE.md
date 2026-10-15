# TEMPLATE — the body of the parent issue

The parent is not implemented: it holds the project roadmap and the list of the children that
execute it. The plan with the phases and the work checkboxes lives in the children, which follow
`skills/plan/TEMPLATE.md`.

The title stays outside the body: a short lowercase sentence that says what the product gains
once the project is finished.

The sections are these, in this order, all mandatory except where stated. The text in square
brackets is an instruction for the writer and must not be copied. Where the template gives two
variants — GitLab and GitHub — you copy only one, the repo's, and use its word (merge request or
pull request) without slashes. The headings, bold labels and status values below are markers:
copy them in English verbatim; write the rest in the user's language — `TRACKER.md` §6.

---

- **Type:** roadmap
- **Status:** to do

## Goal

[Two or three paragraphs. What happens today and why it is not enough, with the reference to the
code that produces that behavior; what will be true when the last child is merged. It is the
sentence every child must be able to trace back to itself.]

## Architecture

[How the pieces fit together once the project is finished: the modules touched, the boundaries
between them, the data that flows. An ASCII diagram if it helps. Name the entry files with
verified `path/file.ts:42`, and the files that will be born with the name they will have.]

## Decisions

[One entry per decision taken — with the user or on your own — with its rationale. They are the
choices the children must not call back into question: the writer of each child receives them
and respects them.]

## Context

[The facts discovered in reconnaissance that hold for several children, one paragraph with a
**bold title** each, as in the `plan` template: the measured numbers stating where, the
cross-cutting constraints — data schema, mirrored fields, caches, compatibility with data and
clients already out there — with the why.]

## Issues

[The children in execution order, split by wave: the children of a wave run together, a wave
starts when the previous one is fully merged. When the parent is created, the placeholder `#(k)`
stands in place of the number; it becomes `#<number>` when the children are opened. A wave with
a single child is normal: a linear chain is always correct.]

**Wave 1**

- [ ] #13 [title] — [what it delivers, in one line]

**Wave 2** — in parallel

- [ ] #14 [title] — [what it delivers] · depends on #13
- [ ] #15 [title] — [what it delivers] · depends on #13

**Wave 3**

- [ ] #16 [title] — [what it delivers] · depends on #14, #15

## Parallelism

[One subsection for each wave with more than one child; if there are none, one line: “No
parallel wave: the children run one at a time.” It is the agreement among the children that work
together, decided by whoever wrote the roadmap: whoever writes them and whoever executes them
respects it without renegotiating it. The conditions are those of `PARALLEL.md` §2 in the
plugin's repo.]

### Wave 2 — #14 ∥ #15

- **#14 touches:** [modules, folders or files — or sections of shared files — that it can modify
  or create, and nothing else]
- **#15 touches:** [same; disjoint from #14]
- **Touched by neither:** [the magnet files — lockfiles, migrations, registries, indexes,
  changelog — with who touches them afterwards; or their single owner in the wave]
- **Contract:** [what they share, with exact names and shapes: the type born with #13 that both
  use as it is, the endpoint #14 exposes and #15 calls, with the format of the response. Neither
  of the two changes it.]

## How to proceed

[Mandatory section, copied as it is — in the user's language, like the rest.]

By hand, the children run **one at a time, in the order above** — within a wave in any order —,
each with its own branch and its own merge request — pull request on GitHub:

```
/issue-flow:implement <child>         # or this issue's number: takes the first open child
/issue-flow:close <child>             # opens the child's merge request
/issue-flow:close <child> --merged    # once merged: closes the child and ticks it here
```

Or all at once, without waiting for the merges, with `/issue-flow:big-implement <this issue>`:
this issue has its own branch, each child is born from there — those of a wave together, each in
its own worktree — and goes back into it with a merge request merged automatically, one at a
time, after the checks of `/issue-flow:close`; at the end the merge request of this issue brings
the whole project into the target branch, and only whoever approves it merges it. Once it is
merged, `/issue-flow:close <this issue> --merged`.

A box of this issue is ticked **when the child is merged** — into the target branch, or into
this issue's branch — not when it is implemented. The next child starts from there, with the
work of the previous ones in it.

When the last piece of work reaches the target branch — with the last child, or with the merge
request of this issue — this issue gets closed, and the **Status:** becomes
`closed — completed on YYYY-MM-DD`. Until then it is `in progress — k of M issues merged`.

If during execution the roadmap stops holding — a decision turns out to be wrong, a child must
be split or redone — the issues are fixed before the code: this one, re-reading it from the
server before rewriting it, and the affected children with `/issue-flow:plan revise <number>`.

## Out of scope

[Bulleted list of what the project does **not** do, with the why: the natural extensions that
someone might add on their own initiative in one of the children.]
