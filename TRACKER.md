# TRACKER — GitLab or GitHub, and what changes

The skills of this plugin — `/issue-flow:roadmap`, `/issue-flow:plan`, `/issue-flow:big-plan`,
`/issue-flow:implement`, `/issue-flow:big-implement`, `/issue-flow:close` — work on a tracker that can be **GitLab** (`glab`) or **GitHub**
(`gh`). The plan, the roadmap, the writing rules and the way boxes are ticked do not
change: the command and a couple of words do. This file is the single reference, and the
skills cite it instead of repeating themselves. What concerns parallel agents and worktrees
lives in its twin, `PARALLEL.md`.

## 1. Which tracker — inferred, not asked

```bash
git remote get-url origin
```

`github` in the URL → `gh`; `gitlab` → `glab`. The string match holds even when the remote
points to an SSH alias (`git@github.com-work:owner/repo.git`), which is exactly the case where
the CLI alone cannot tell where it is.

```bash
case "$(git remote get-url origin)" in
  *github*) TRACKER=gh   ;;
  *gitlab*) TRACKER=glab ;;
  *)        TRACKER=     ;;   # neither one nor the other: stop and ask
esac
command -v "$TRACKER"          # if the CLI is missing, stop: it cannot be installed silently
```

Two cases where you **stop and ask** instead of guessing: the remote is neither GitHub nor
GitLab (self-hosted on its own domain, or no remote at all), and the CLI you would need is not
installed. In that second case say so with the remedy: `gh` installs from
<https://cli.github.com>, `glab` from <https://gitlab.com/gitlab-org/cli>, then `auth login`.

If there are several remotes and `origin` is not the tracker's, the remote the user names is
the one that counts: it is a case to ask about, not to infer.

## 2. The tracker answers — step 0 of every skill

| | GitLab | GitHub |
|---|---|---|
| authentication | `glab auth status` → “Logged in to gitlab.com” | `gh auth status` → “Logged in to github.com” |
| the repo resolves | `glab issue list --all` gives no 404 | `gh issue list --state all` gives no error |
| login (interactive, **you cannot do it**) | `glab auth login --hostname gitlab.com` | `gh auth login --hostname github.com` |

**When the repo does not resolve** it is almost always the remote's SSH alias, which the CLI
does not recognize as a host:

- GitLab: `glab config set host gitlab.com` inside the repo, which writes to
  `.git/glab-cli/config.yml`;
- GitHub: `gh repo set-default OWNER/REPO` inside the repo, which writes `gh-resolved` into
  `.git/config`. Alternatively, for a single command, `GH_REPO=OWNER/REPO gh ...`.

## 3. The vocabulary

| concept | GitLab | GitHub |
|---|---|---|
| the issue number | `iid` | `number` |
| what gets opened at the end of the work | merge request (MR) | pull request (PR) |
| how it is referenced | `!<number>` | `#<number>` |

In the skills “MR/PR” stands for “whichever of the two applies here”. When you write in the
issue, on the page or to the user, use **the word of the platform you are working on** — not
the slash.

On GitHub issues and pull requests **share the same number sequence**: the PR opened for
issue #12 will be #13 or #40, never #12. Do not assume they match and do not build the PR
number yourself: read it from the output of `gh pr create`.

## 4. Command mapping

An issue body **always goes through a file**, never inside shell quotes.

| what | GitLab | GitHub |
|---|---|---|
| list all issues | `glab issue list --all --output json` | `gh issue list --state all --limit 500 --json number,title` |
| read an issue | `glab issue view <n> --output json` | `gh issue view <n> --json number,title,body,state` |
| body only | `glab issue view <n> --output json --jq '.description'` | `gh issue view <n> --json body --jq '.body'` |
| create | `glab issue create --title T --description-file F --yes` | `gh issue create --title T --body-file F` |
| rewrite the body | `glab issue update <n> --description-file F` | `gh issue edit <n> --body-file F` |
| close | `glab issue close <n>` | `gh issue close <n>` |
| open MR/PR | `glab mr create --source-branch B --target-branch <base> --title T --description-file F --yes` | `gh pr create --head B --base <base> --title T --body-file F` |
| MR/PRs targeting a branch | `glab mr list --target-branch B` | `gh pr list --base B` |
| change the target of an MR/PR | `glab mr update <n> --target-branch <base>` | `gh pr edit <n> --base <base>` |
| MR/PR state | `glab mr view <B> --output json --jq '.state'` → `merged` | `gh pr view <B> --json state --jq '.state'` → `MERGED` |
| pipeline outcome | `glab mr view <n> --output json --jq '.head_pipeline.status'` | `gh pr checks <n> --watch --fail-fast` |
| merge — **only** into the parent branch | `glab mr merge <n> --sha <SHA> --auto-merge=false --remove-source-branch --yes` | `gh pr merge <n> --merge --match-head-commit <SHA> --delete-branch` |

## 5. The differences that bite

**The body field has a different name.** `description` on GitLab, `body` on GitHub.
It is the easiest mistake to make when copying a command from one skill to another: a `jq`
that picks the wrong field returns `null`, and you end up rewriting the issue with an empty
description. Always check that the file you wrote is not empty before sending it back up.

**`gh issue list` stops at 30.** The default of `--limit` is 30. `glab` paginates its own way,
and `--all` there means “every state”, not “every page”.

**The box count exists only on GitLab.** `glab issue view --output json` carries
`task_completion_status` (`{count, completed_count}`); `gh` exposes nothing equivalent.
The method that works on both is counting them in the body, and it is the one to always use:

```bash
grep -c '^[[:space:]]*- \[[ xX]\]' "$SCRATCH/roadmap.md"   # total
grep -c '^[[:space:]]*- \[[xX]\]'  "$SCRATCH/roadmap.md"   # ticked
grep -n  '^[[:space:]]*- \[ \]'    "$SCRATCH/roadmap.md"   # the ones left
```

**A body written from the GitHub web UI comes back with CRLF terminators.** The `grep`s above
still work — the pattern is not anchored to the end of the line — but any expression that is
(`- \[ \]$`, the `**Status:**` line) finds nothing, and the leftover `\r`s go back into the
issue when you rewrite it. A `sed -i 's/\r$//' "$SCRATCH/roadmap.md"` right after reading the
body removes the problem at the root, and is harmless if there are no `\r`s.

**`gh pr create` has neither `--related-issue` nor `--remove-source-branch`.** The link to the
issue is made **only** with `Closes #<number>` as the first line of the body — on GitHub it
closes the issue on merge if the PR targets the repo's default branch. An MR/PR that targets
the parent branch, on both platforms, closes nothing: `/issue-flow:close` closes the child
right after the merge. The branch, after the merge, is
deleted by hand (`git push origin --delete <branch>`) or by the repo's “Automatically
delete head branches” setting: it is not these skills' job.

**The MR/PR state has different casing.** `merged` on GitLab, `MERGED` on GitHub —
compare case-insensitively, or the outcome is always “not merged yet”.

**On GitHub the issue may already be closed.** If the PR contained `Closes #<n>` and has been
merged, GitHub closed it by itself. Before closing, check the state: if it is already `CLOSED`,
all that is left is updating the **Status:** line in the body. Closing an already closed issue
is not an error, but telling the user you closed it is.

**A checkbox that references an issue shows it live.** In the parent of `/issue-flow:big-plan`
the lines `- [ ] #13 title` are task lists like the others — they are counted with the same
`grep`s — and on top of that both platforms render `#13` as a link with the issue's title and
state. The state shown, though, is the issue's, not the tick: the box is flipped only by
`/issue-flow:close --merged`, and the count that matters remains the one in the body.

**`--yes` belongs to `glab`.** `gh` does not have it and does not need it: passing `--title`
and `--body-file` (and `--head` for the PR, with the branch already pushed) it asks nothing.

## 6. Language and markers

What the skills write — issue bodies, MR/PR bodies, `ROADMAP.md` — is in **the
user's language**: the one the user writes to you in. Commit messages follow the convention
already in the project's log, language included; with no history to follow, the user's
language.

**The markers stay in English, verbatim**, whatever the language of the text: every heading,
bold label and status value the templates give. The skills and the `Stop` hook find the
phases, the boxes, the parent and the dependencies by these strings, so a translated marker
is a marker that does not exist. Everything written under them is in the user's language.

Issues written by issue-flow 1.x have the markers in Italian. When you **read** one, the
Italian marker counts as its English equivalent; when you **rewrite** one, keep its markers as
they are — a body with half its markers in one language and half in the other is read by
nobody.

| English (2.x) | Italian (1.x) |
|---|---|
| `## Goal`, `## Context`, `## Plan`, `## Out of scope` | `## Obiettivo`, `## Contesto`, `## Piano`, `## Fuori perimetro` |
| `## How to update this roadmap` | `## Come si aggiorna questa roadmap` |
| `**Execution:**` | `**Esecuzione:**` |
| `### Phase N — …`, `Verification`, `Wrap-up` | `### Fase N — …`, `Verifica`, `Chiusura` |
| `**Done when:**`, `**Scope:**`, `**In parallel with:** Phase 4.`, `**Contract:**` | `**Fatto quando:**`, `**Perimetro:**`, `**In parallelo con:** Fase 4.`, `**Contratto:**` |
| `**Status:**`, `**Planned branch:**`, `**Roadmap:**`, `**Depends on:**`, `**Type:** roadmap` | `**Stato:**`, `**Branch previsto:**`, `**Roadmap:**`, `**Dipende da:**`, `**Tipo:** roadmap` |
| status `to do` · `in progress — phase N of M` · `implemented — awaiting merge request` (`pull request`) · `in review — !<n>` (`#<n>`) | `da fare` · `in corso — fase N di M` · `implementata — in attesa di merge request` (`pull request`) · `in revisione — !<n>` (`#<n>`) |
| status `closed — merged on YYYY-MM-DD` · `closed — merged into <parent-branch> on YYYY-MM-DD` · `closed — completed on YYYY-MM-DD` | `chiusa — unita il GG/MM/AAAA` · `chiusa — unita in <branch-madre> il GG/MM/AAAA` · `chiusa — completata il GG/MM/AAAA` |
| status `in progress — k of M issues merged` (`… merged into <parent-branch>`) | `in corso — k di M issue unite` (`… unite in <branch-madre>`) |
| `## Architecture`, `## Decisions`, `## Issues`, `## Parallelism`, `## How to proceed` | `## Architettura`, `## Decisioni`, `## Issue`, `## Parallelismo`, `## Come si avanza` |
| `**Wave N**` (`— in parallel`), `### Wave N — #14 ∥ #15`, `· depends on #13` | `**Ondata N**` (`— in parallelo`), `### Ondata N — #14 ∥ #15`, `· dipende da #13` |
| `**#14 touches:**`, `**Touched by neither:**` | `**#14 tocca:**`, `**Non tocca nessuna delle due:**` |
| “created by #(k)” | «nasce con #(k)» |

The MR/PR body (`## What changes`, `## How it was verified`, `## Deviations from the plan`,
`## Children`) and `ROADMAP.md` (`skills/roadmap/TEMPLATE.md`) follow the same rule: headings
and labels in English, the rest in the user's language.
