# TEMPLATE — the ROADMAP.md file

The file that `/issue-flow:roadmap` writes at the root of the repo when the user chooses to
save the roadmap instead of opening the issues. It is rewritten in full every time: it describes
today's next steps, and the previous versions live in git history.

The sections are these, in this order. The text in square brackets is an instruction for the
writer and is not copied. Sections marked optional are omitted when empty. The headings, bold
labels and status values below are markers: copy them in English verbatim; write the rest in
the user's language — `TRACKER.md` §6.

---

# Roadmap

**Updated on YYYY-MM-DD** by `/issue-flow:roadmap`[ — focus: <focus>, if there was one].

## Where we are

[Three or four lines: what exists today, what is being worked on, what the next milestone is.
Every statement with its source.]

**Sources read:** [the list: the documents with their path — for research-flow the official
document with its date and the registers —, the previous ROADMAP.md if there was one, the open
issues looked at (or “tracker not consulted”).]

## Next steps

[In execution order. Every step is the size of an issue, and can be opened with
`/issue-flow:plan` by copying its title and its description. The steps of the same wave do not
depend on each other, touch different parts of the code and can be executed together.]

**Waves:** [in one line: `1 → [2 ∥ 3] → 4`. With no parallel steps, `1 → 2 → 3 → 4`.]

### 1. [title: what changes for whoever uses the product]

- **Delivers:** [what exists once the step is done, in one or two lines]
- **Why now:** [the reason for its position, with the sources: `TODO-012`, `ESP-031`,
  `README.md` §Roadmap, `#45`, `path/file.py:88`. **Our proposal** if it does not come from a
  source]
- **Afterwards we know:** [optional: what we will know — the hypothesis that holds or falls, the
  success criterion that gets measured]
- **Depends on:** [the step, an item of Waiting on, an issue already open, or “nothing”]
- **In parallel with:** [optional, only if the wave has other steps: which ones, and where this
  one touches the code — the modules or folders —, so whoever turns them into issues sees the
  boundary]

### 2. [title]

[…]

## Already open

[Optional. The issues and parents already on the tracker this roadmap builds on, with their
number and what is missing to close them.]

## Waiting on

[Optional. What is not our work but blocks or conditions some steps: questions to the sources,
data to accumulate, someone else's decisions. One line each, with the steps that depend on it.]

## Later

[Optional. What comes beyond the horizon, one line per item. After a decision point, the two
branches: “if ESP-031 is positive → …; if it is negative → …”.]

## Left out

[What the sources give as to do and this roadmap does not contain, with the reason: already done
(and the source to correct), superseded, out of focus, low priority.]

## Inconsistencies found

[Optional. Sources that do not match the code or the tracker: open items already done, forgotten
issues, documents older than the registers. Each with who has to correct it.]
