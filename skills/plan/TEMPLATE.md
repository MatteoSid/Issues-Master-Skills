# TEMPLATE — the body of an issue

The title stays outside the body: a short lowercase sentence that says what changes for whoever
uses the product.

The sections are these, in this order, all mandatory except where stated. The text in square
brackets is an instruction for the writer and must not be copied. The headings, bold labels and
status values below are markers: copy them in English verbatim; write the rest in the user's
language — `TRACKER.md` §6.

The issue lives on **one** platform: where the template gives two variants — GitLab and GitHub —
you copy only one, the repo's, and use its word (merge request or pull request) without
slashes. Which one it is, `TRACKER.md` says.

---

- **Status:** to do
- **Planned branch:** `issue-<number>`
- **Roadmap:** #<parent number>   [only for the children of `/issue-flow:big-plan`]
- **Depends on:** #<number>       [only for the children, one line per sibling it depends on]

## Goal

[Two or three paragraphs. The first says what happens today and why it is not enough —
concrete, with the reference to the code that produces that behavior. The last says, in a single
sentence, what will happen afterwards. No list of files: that comes later.]

## Context

[The part that makes the issue executable by someone who did not witness the conversation. They
are paragraphs with a **bold title** each, one per fact discovered in reconnaissance. They go
here, when they exist:]

**How much material there is.** [The measured numbers, stating where: “847 lines in
`src/store.ts`”, “the function has 23 callers”, “coverage on existing records: 886 of 886”.]

**What already exists and we are not using.** [Fields that reach the interface and are not
shown, data computed and then thrown away. It is almost always the part that reduces the work.]

**The non-obvious technical constraint.** [The type a serialization cannot digest, the cache
that would be invalidated, the import that would create a cycle, the mirrored field between
backend and frontend that must change together. With the why, not just the what.]

**Compatibility with what already exists.** [Which data, cached responses or old clients must
keep working, and what they will show.]

**What stays as it is, and why.** [The adjacent code one is tempted to fix and that this issue
does not touch — with the reason it does not touch it.]

**How to prepare a worktree.** [Only if the Plan has parallel phases: the command that makes
verification runnable in a fresh checkout — `npm ci`, `uv sync`, copying `.env.example` — and
the resources a worktree does not isolate (fixed ports, local database), if verification uses
them.]

## Plan

[The phases. Each one is a `###`, with a title that says what it does, and under it: a line
naming the files touched, then the checkboxes. The mandatory phases — verification second to
last, wrap-up last, and Figma first if the project has one configured — are described in
`SKILL.md`.]

**Execution:** [the order of the phases, with the parallel groups in square brackets:
`1 → 2 → [3 ∥ 4] → 5 → 6`. Always present: without groups, `1 → 2 → 3 → 4 → 5 → 6`. When two
phases can be in a group is stated in `PARALLEL.md` §2.]

### Phase 1 — [title]

`path/to/file.ts`.

- [ ] [atomic, imperative checkboxes that name file and line]

**Done when:** [the observation that proves the phase is finished.]

### Phase 3 — [title of a phase in a parallel group]

**Scope:** `path/a.ts`, `path/a.test.ts` — only these.
**In parallel with:** Phase 4. **Contract:** [what the phases of the group share, with exact
names and shapes — the type born in phase 2 that both use as it is, the name of the key one
writes and the other reads —, and what this phase leaves alone because it belongs to phase 4.]

- [ ] […]

**Done when:** [observable in the phase's worktree, without the work of phase 4.]

[...the other phases...]

### Phase N-1 — Verification

- [ ] [the new tests, stated by what they must prove, not by what they are called]
- [ ] [the project's verification commands, one per checkbox, stating which outcome is
      expected: “`npm test` green, the 214 tests from before keep passing”]
- [ ] [the manual check: what you open, what you do, what you must see — concretely]
- [ ] [if it touches the interface: by keyboard, at 390 wide, clean accessibility]
- [ ] [if there are old data or clients: one of them is read again without errors]

### Phase N — Wrap-up

- [ ] `<documentation file>`: [what must be rewritten, not “update the docs”]
- [ ] commit on the issue's branch

[The MR/PR does not go among the checkboxes: it is opened by `/issue-flow:close <number>` after
the last phase, and it is not merged — the user asks for the merge.]

## How to update this roadmap

[Mandatory section, copied as it is — in the user's language, like the rest.]

The boxes above can be ticked: the tracker counts them and shows the progress at the top of the
issue. **They must be ticked as you go**, at the end of each piece of work and not when the work
is finished, in the same commit that brings that piece. Whoever picks the issue up again must be
able to tell from the state of the boxes where it stands, without asking anyone.

If a decision changes during implementation, the roadmap line is rewritten instead of just
being ticked: a roadmap that lies is worse than no roadmap.

From the command line, always re-reading the version on the server before rewriting it — the
update replaces the whole body and does not merge:

[Copy only the block for this repo's platform.]

```bash
# GitLab
glab issue view <number> --output json --jq '.description' > roadmap.md
glab issue update <number> --description-file roadmap.md
```

```bash
# GitHub
gh issue view <number> --json body --jq '.body' > roadmap.md
sed -i 's/\r$//' roadmap.md
gh issue edit <number> --body-file roadmap.md
```

When the work is finished: all the boxes ticked, then `/issue-flow:close <number>` opens the
merge request — the pull request on GitHub — and brings the **Status:** to
`in review — !<MR number>` on GitLab, `in review — #<PR number>` on GitHub. Once it is merged,
`glab issue close <number>` or `gh issue close <number>`, and the **Status:** becomes
`closed — merged on YYYY-MM-DD`. On GitHub the issue may have closed by itself: the PR carries
`Closes #<number>` and the merge closes it.

## Out of scope

[Bulleted list of what this issue does **not** do, with the why. Above all the things that
would be little work and that someone might add on their own initiative: stating them here is
the way not to find them implemented.]
