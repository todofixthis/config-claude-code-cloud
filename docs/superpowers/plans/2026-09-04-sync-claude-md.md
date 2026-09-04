# Sync CLAUDE.md Across Repos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task in this plan is fully mechanical (exact file contents, exact commands) — Inline Execution via superpowers:executing-plans is the better fit; subagent-driven-development adds dispatch overhead with no judgement calls left to delegate.

**Goal:** Stop `config-claude`'s and `config-claude-code-cloud`'s `CLAUDE.md` files drifting apart by making both generated from one canonical shared source plus a small repo-specific fragment, instead of two hand-maintained copies.

**Architecture:** The shared content lives in `cloud/CLAUDE.shared.md`, canonical in `config-claude-code-cloud` (public — the only repo whose raw content a cloud session's secret-free bootstrap, and `config-claude`'s private repo, can both fetch without auth). Each repo's real `CLAUDE.md` becomes a generated file: `config-claude-code-cloud`'s `cloud/CLAUDE.md` is `cat cloud/CLAUDE.cloud-only.md cloud/CLAUDE.shared.md` (same-repo, no network); `config-claude`'s `CLAUDE.md` is `cat CLAUDE.local-only.md` plus a `curl` fetch of the public `cloud/CLAUDE.shared.md`. A `generate-claude-md.sh` script in each repo does the concatenation.

**Pre-work already done, on this same branch, before this plan was written** (per `phx:writing-plans`' convention of committing CLAUDE.md-guidance changes first):
- `config-claude-code-cloud` commit `fed1ea1`: added `cloud/CLAUDE.shared.md` (the merged shared content — union of both repos' prior content, since the drift ran both ways: `config-claude` had a newer "Writing style" section, `cloud/CLAUDE.md` had four bullets `config-claude` never got) and `cloud/CLAUDE.cloud-only.md` (the cloud-specific "Maintaining this file" note, rewritten for the new generated-file mechanism). Pushed to `origin/claude/sync-claude-md-repos-hjidow`.
- `config-claude` commit `8043815`: added `CLAUDE.local-only.md` (this repo's own "Maintaining this file" note) and allowlisted it plus the upcoming `generate-claude-md.sh` in `.gitignore` (this repo ignores everything by default, un-ignoring tracked files by name). Pushed to `origin/claude/sync-claude-md-repos-hjidow`.
- Both new prose files went through the NZ-English sweep (clean — one hit, the CSS `color` property, correctly exempted as an external symbol already documented in the shared file itself) and two rounds of audience-surrogate review (round 1 found a real defect — the shared-content edit procedure was missing a commit+push step and was ordered so a reader could regenerate `config-claude`'s `CLAUDE.md` before the source edit was pushed, silently picking up stale content; fixed and confirmed in round 2).

**Tech Stack:** Bash (`set -euo pipefail`, no dependencies beyond `curl`, already relied on elsewhere in `config-claude-code-cloud`).

**Spec:** This plan's own Architecture section above — there is no separate spec document. Session context: the user (Phoenix) approved "shared canonical file + generation step" after a design conversation that ruled out CI-only drift-detection and a pure procedural note (both still rely on someone remembering to reconcile by hand, which is the failure already observed) and a cross-repo `@import` (Claude Code's own `@path` import mechanism, verified against `code.claude.com/docs/en/memory.md` — it exists, but a user-scope memory file's imports outside the session's working directory are skipped in Cowork/cloud sessions, so it can't reach across repos there).

**Worktree:** No new worktree — both repos are already checked out at fixed paths with the branch this task must use pre-created by the harness, so that checkout *is* the isolated workspace (honouring the existing branch is `using-git-worktrees`'s "honour a declared preference" case, not a case for nested `git worktree add`):
- `/home/user/config-claude-code-cloud` (branch: `claude/sync-claude-md-repos-hjidow`)
- `/home/user/config-claude` (branch: `claude/sync-claude-md-repos-hjidow`)

## Global Constraints

- `config-claude-code-cloud/cloud/setup.sh` must not change — it keeps fetching `cloud/CLAUDE.md` as a single file; only how that file is built changes.
- No secrets, tokens, or authenticated fetches anywhere in `config-claude-code-cloud` (its bootstrap is deliberately secret-free — see its README's "What's deliberately not here").
- Every `curl` this plan adds must be bounded (`--max-time`) and hard-fail on error (`-f`) — no silent partial output, no indefinite hang.
- Both `generate-claude-md.sh` scripts write to a temp file and `mv` into place on success only — a failed run must never leave a truncated `CLAUDE.md`.
- Match each repo's existing shell-script convention: mode `644` (not executable), invoked as `bash <script>` (see `cloud/setup.sh`, `cloud/pointer.sh`, `statusline-command.sh` — none of them are `+x`, other than the one hook Claude Code itself invokes directly by path).

---

### Task 1: `config-claude-code-cloud` — generation script, README, first regeneration

**Files:**
- Create: `cloud/generate-claude-md.sh`
- Modify: `cloud/CLAUDE.md` (becomes generated output — full contents below, not hand-edited)
- Modify: `README.md:5-11` (Structure section), `README.md:29-34` (Making changes section)

**Interfaces:**
- Produces: `cloud/generate-claude-md.sh`, a script with no arguments, run as `bash cloud/generate-claude-md.sh` from anywhere (it `cd`s to its own directory first) or `bash generate-claude-md.sh` from inside `cloud/`. Writes `cloud/CLAUDE.md`, prints `cloud/CLAUDE.md regenerated` on success, exits non-zero with nothing printed to stdout on failure (input files unreadable) and leaves any pre-existing `cloud/CLAUDE.md` untouched.

- [ ] **Step 1: Write `cloud/generate-claude-md.sh`**

```bash
#!/bin/bash
# Regenerates cloud/CLAUDE.md from cloud/CLAUDE.cloud-only.md and
# cloud/CLAUDE.shared.md — see cloud/CLAUDE.cloud-only.md for what goes in
# which source file.

set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
    echo "<!-- GENERATED FILE — do not edit directly. Edit cloud/CLAUDE.cloud-only.md and/or cloud/CLAUDE.shared.md, then re-run cloud/generate-claude-md.sh. -->"
    echo
    cat CLAUDE.cloud-only.md
    echo
    cat CLAUDE.shared.md
} > "$tmp"

mv "$tmp" CLAUDE.md
echo "cloud/CLAUDE.md regenerated"
```

- [ ] **Step 2: Run it and inspect the result**

```bash
cd /home/user/config-claude-code-cloud
bash cloud/generate-claude-md.sh
head -5 cloud/CLAUDE.md
wc -l cloud/CLAUDE.md
```

Expected: prints `cloud/CLAUDE.md regenerated`; the file starts with the `<!-- GENERATED FILE -->` comment line, a blank line, then `# Maintaining this file` (the top of `CLAUDE.cloud-only.md`); line count is roughly `1 (comment) + 1 (blank) + 13 (cloud-only) + 1 (blank) + 199 (shared)` — 215 lines give or take.

- [ ] **Step 3: Prove the failure case — missing input**

```bash
cd /home/user/config-claude-code-cloud
cp cloud/CLAUDE.md /tmp/claude-md-good-copy
mv cloud/CLAUDE.shared.md /tmp/claude-shared-moved-aside
bash cloud/generate-claude-md.sh; echo "exit: $?"
diff /tmp/claude-md-good-copy cloud/CLAUDE.md && echo "CLAUDE.md unchanged: OK"
mv /tmp/claude-shared-moved-aside cloud/CLAUDE.shared.md
rm /tmp/claude-md-good-copy
```

Expected: the script exits non-zero (the `cat CLAUDE.shared.md` fails, `set -e` aborts before `mv`), and the `diff` prints nothing and `CLAUDE.md unchanged: OK` — the pre-existing generated file survived the failed run untouched. Restoring `cloud/CLAUDE.shared.md` and re-running Step 2's `bash cloud/generate-claude-md.sh` afterwards should reproduce the exact same `cloud/CLAUDE.md` as before this step (confirm with a third `diff` against a fresh copy taken right before this step, if in doubt).

- [ ] **Step 4: Update `README.md`'s Structure section**

Replace:
```markdown
- `cloud/CLAUDE.md` — personal user-level instructions. Cloud sessions don't carry over `~/.claude/CLAUDE.md` from a local machine (only repo-committed `CLAUDE.md` files do), so this is the only way to get it into cloud sessions at all.
- `cloud/gh-config.yml` — `gh` CLI preferences. Note `git_protocol: https`, not `ssh` — cloud sessions have no SSH client, so `gh` needs HTTPS to have any credential to use.
```

With:
```markdown
- `cloud/CLAUDE.md` — personal user-level instructions. Cloud sessions don't carry over `~/.claude/CLAUDE.md` from a local machine (only repo-committed `CLAUDE.md` files do), so this is the only way to get it into cloud sessions at all. Generated by `cloud/generate-claude-md.sh` from the two files below — see `cloud/CLAUDE.cloud-only.md` for how to edit and regenerate it.
- `cloud/CLAUDE.shared.md` — the personal instructions shared with `todofixthis/config-claude` (the local-machine counterpart). This repo is its canonical home, since it's public and `config-claude` is not.
- `cloud/CLAUDE.cloud-only.md` — the cloud-specific personal instructions, plus how to maintain and regenerate `cloud/CLAUDE.md`.
- `cloud/generate-claude-md.sh` — concatenates the two files above into `cloud/CLAUDE.md`.
- `cloud/gh-config.yml` — `gh` CLI preferences. Note `git_protocol: https`, not `ssh` — cloud sessions have no SSH client, so `gh` needs HTTPS to have any credential to use.
```

- [ ] **Step 5: Update `README.md`'s Making changes section**

Replace:
```markdown
- **Editing `setup.sh`, `CLAUDE.md`, or `gh-config.yml`**: commit the change here, then bump the version comment at the top of `cloud/pointer.sh` and re-paste `pointer.sh`'s content into the environment's Setup script field. This step is the whole reason `pointer.sh` exists: the environment only re-runs its setup script (and rebuilds the cached snapshot) when *that field's own text* changes — never when the file it fetches does. Skipping the re-paste means the change sits in this repo but never reaches a session.
- **Editing `pointer.sh` or `environment.env` itself**: re-paste directly, no version bump needed (the text already changed).
- **Adding a plugin**: add a `sync_skills_dir_plugin` call for it in `cloud/setup.sh` (see "Plugins" above), then follow the bump-and-re-paste step above.
- **A cloud session editing `~/.claude/CLAUDE.md` in place** (e.g. `phx:reflection` deciding to record a new pattern): that's the fetched copy, not this repo — the edit is invisible everywhere else and is gone at the next cache rebuild. `cloud/CLAUDE.md` itself carries this same warning, since that's what a session is reading right when it'd make this mistake.
```

With:
```markdown
- **Editing `setup.sh` or `gh-config.yml`**: commit the change here, then bump the version comment at the top of `cloud/pointer.sh` and re-paste `pointer.sh`'s content into the environment's Setup script field. This step is the whole reason `pointer.sh` exists: the environment only re-runs its setup script (and rebuilds the cached snapshot) when *that field's own text* changes — never when the file it fetches does. Skipping the re-paste means the change sits in this repo but never reaches a session.
- **Editing `CLAUDE.shared.md` or `CLAUDE.cloud-only.md`**: run `cloud/generate-claude-md.sh` to regenerate `cloud/CLAUDE.md`, then follow the bump-and-re-paste step above — see `cloud/CLAUDE.cloud-only.md` itself for the full procedure, including propagating a shared-content change to `config-claude`.
- **Editing `pointer.sh` or `environment.env` itself**: re-paste directly, no version bump needed (the text already changed).
- **Adding a plugin**: add a `sync_skills_dir_plugin` call for it in `cloud/setup.sh` (see "Plugins" above), then follow the bump-and-re-paste step above.
- **A cloud session editing `~/.claude/CLAUDE.md` in place** (e.g. `phx:reflection` deciding to record a new pattern): that's the fetched copy, not this repo — the edit is invisible everywhere else and is gone at the next cache rebuild. `cloud/CLAUDE.cloud-only.md` carries this same warning (which flows into the generated `cloud/CLAUDE.md`, and so into the fetched copy), since that's what a session is reading right when it'd make this mistake.
```

- [ ] **Step 6: Bump `cloud/pointer.sh`'s version comment**

`cloud/CLAUDE.md`'s content changed (even though its two sources didn't just now — this is the first regeneration), so treat it as a real content change for the pointer version, per `cloud/CLAUDE.cloud-only.md`'s own instructions. Edit the version comment line in `cloud/pointer.sh` (currently `# Bootstrap version: 2026-09-02-01`) to `# Bootstrap version: 2026-09-04-01`.

- [ ] **Step 7: Commit**

Run `git status` to catch any related unstaged or untracked files, then use the `phx:creative-commits` skill. Stage `cloud/generate-claude-md.sh`, `cloud/CLAUDE.md`, `README.md`, and `cloud/pointer.sh`.

## Task 2: `config-claude` — generation script, first regeneration

**Files:**
- Create: `generate-claude-md.sh`
- Modify: `CLAUDE.md` (becomes generated output — full contents below, not hand-edited)

**Interfaces:**
- Consumes: the public raw URL `https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud/CLAUDE.shared.md`, i.e. Task 1's `cloud/CLAUDE.shared.md` once merged to `config-claude-code-cloud`'s `main`. Overridable via the `CLAUDE_SHARED_URL` environment variable, needed below because at plan-execution time that content is only on the feature branch, not yet on `main`.
- Produces: `generate-claude-md.sh`, run as `bash generate-claude-md.sh` (optionally with `CLAUDE_SHARED_URL=... bash generate-claude-md.sh`) from anywhere (it `cd`s to its own directory first). Writes `CLAUDE.md`, prints `CLAUDE.md regenerated` on success, exits non-zero with nothing printed to stdout on failure (bad URL, unreachable host, local file missing) and leaves any pre-existing `CLAUDE.md` untouched.

- [ ] **Step 1: Write `generate-claude-md.sh`**

```bash
#!/bin/bash
# Regenerates CLAUDE.md from CLAUDE.local-only.md (this repo) and
# cloud/CLAUDE.shared.md (fetched from todofixthis/config-claude-code-cloud,
# its canonical home) — see CLAUDE.local-only.md for what goes in which
# source file.

set -euo pipefail
cd "$(dirname "$0")"

SHARED_URL="${CLAUDE_SHARED_URL:-https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud/CLAUDE.shared.md}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
    echo "<!-- GENERATED FILE — do not edit directly. Edit CLAUDE.local-only.md here, or cloud/CLAUDE.shared.md in todofixthis/config-claude-code-cloud, then re-run generate-claude-md.sh. -->"
    echo
    cat CLAUDE.local-only.md
    echo
    curl -fsSL --max-time 30 "$SHARED_URL"
} > "$tmp"

mv "$tmp" CLAUDE.md
echo "CLAUDE.md regenerated"
```

- [ ] **Step 2: Run it against the pushed feature branch and inspect the result**

`cloud/CLAUDE.shared.md` isn't on `config-claude-code-cloud`'s `main` yet — Task 1's commit is only on `origin/claude/sync-claude-md-repos-hjidow` until that repo's PR merges. Point the fetch at that branch for this proving run:

```bash
cd /home/user/config-claude
CLAUDE_SHARED_URL="https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/claude/sync-claude-md-repos-hjidow/cloud/CLAUDE.shared.md" \
    bash generate-claude-md.sh
head -5 CLAUDE.md
diff <(tail -n +3 CLAUDE.md) <(cat CLAUDE.local-only.md; echo; curl -fsSL --max-time 30 "https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/claude/sync-claude-md-repos-hjidow/cloud/CLAUDE.shared.md")
```

Expected: prints `CLAUDE.md regenerated`; the file starts with the `<!-- GENERATED FILE -->` comment line, a blank line, then `# Maintaining this file` (the top of `CLAUDE.local-only.md`); the `diff` prints nothing (the generated body, minus its 2-line header, matches a fresh concatenation of the two sources byte for byte).

Once `config-claude-code-cloud`'s PR merges to `main`, re-run without the override (`bash generate-claude-md.sh`, no `CLAUDE_SHARED_URL`) to confirm the default URL resolves the same content — content should be identical since nothing else touches `cloud/CLAUDE.shared.md` between now and merge; this plan does not add a task for it since it is a one-line confirmation, not new work, and is easy to fold into whichever session next touches this repo if it's not already been done by then.

- [ ] **Step 3: Prove the failure case — unreachable URL**

```bash
cd /home/user/config-claude
cp CLAUDE.md /tmp/claude-md-good-copy
CLAUDE_SHARED_URL="https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud/CLAUDE.does-not-exist.md" \
    bash generate-claude-md.sh; echo "exit: $?"
diff /tmp/claude-md-good-copy CLAUDE.md && echo "CLAUDE.md unchanged: OK"
rm /tmp/claude-md-good-copy
```

Expected: the script exits non-zero (`curl -f` fails on the 404, `set -e` aborts before `mv`), and the `diff` prints nothing and `CLAUDE.md unchanged: OK` — the file from Step 2 survived the failed run untouched.

- [ ] **Step 4: Commit**

Run `git status` to catch any related unstaged or untracked files, then use the `phx:creative-commits` skill. Stage `generate-claude-md.sh` and `CLAUDE.md`.

## Task 3: Wrap up

- [ ] **Step 1: Re-verify both generated files one more time**

```bash
cd /home/user/config-claude-code-cloud && bash cloud/generate-claude-md.sh && git status --short
cd /home/user/config-claude && CLAUDE_SHARED_URL="https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/claude/sync-claude-md-repos-hjidow/cloud/CLAUDE.shared.md" bash generate-claude-md.sh && git status --short
```

Expected: both `git status --short` calls print nothing — regenerating again reproduces the already-committed `CLAUDE.md` in each repo exactly, confirming the committed files really are what the scripts produce.

- [ ] **Step 2: Delete this plan file and commit**

```bash
cd /home/user/config-claude-code-cloud
rm docs/superpowers/plans/2026-09-04-sync-claude-md.md
git add docs/superpowers/plans/2026-09-04-sync-claude-md.md
git status
```

Use the `phx:creative-commits` skill for this commit (small, self-evident — a one-bullet body or none, per that skill's own scaling guidance).

- [ ] **Step 3: Push both repos and create pull requests**

Push `config-claude-code-cloud` and `config-claude` (both already have their upstream set from the pre-work commits — plain `git push` suffices). Create a pull request for each, following the harness's PR-creation instructions (check for a PR template in each repo first — neither currently has one, per this session's earlier exploration, but re-check rather than assuming) and the `GitHub` section of each repo's own `CLAUDE.md` for the sign-off footer format. Subscribe to both PRs' activity per the harness's standing instruction to watch PRs it creates.

## Intentional Decisions

*(Populated during review — reviewers must not re-raise these)*

- No CI drift-detection was added (the design-conversation's option 2). The user approved option 1 (generation script) specifically; option 2 is a smaller, complementary safeguard against someone hand-editing a generated `CLAUDE.md` directly, but it's out of this plan's scope and can be proposed separately if the manual-regeneration discipline proves insufficient in practice.
- `config-claude`'s `generate-claude-md.sh` hard-fails (`set -euo pipefail`, no best-effort fallback) unlike `config-claude-code-cloud/cloud/setup.sh`'s best-effort philosophy — deliberate: `setup.sh` must never block a cloud session from starting on a flaky download, but this is a manually-run local script where a loud failure beats a silently stale `CLAUDE.md`.
- The generated `CLAUDE.md` files are committed to their repos (not generated fresh at cloud-bootstrap time or via a pre-commit hook) — keeps `setup.sh` unchanged and avoids adding a network dependency to the cloud bootstrap's critical path; the cost is that a regeneration step can be forgotten, which is why both `CLAUDE.cloud-only.md` and `CLAUDE.local-only.md` state the regenerate-then-commit-then-push procedure explicitly rather than assuming it's remembered.

## Self-Review Checklist

- [ ] Does every task's spec requirement trace to a step? (Shared file extraction and merge: done in pre-work, Architecture section. Generation scripts: Task 1 Step 1, Task 2 Step 1. First regeneration + verification: Task 1 Steps 2-3, Task 2 Steps 2-3. Docs: Task 1 Steps 4-5, and the two pre-work `CLAUDE.md`-fragment files. Commits: every task's last step.)
- [ ] Any placeholders ("TBD", "similar to Task N", steps without real content)? None — every step has full file contents or a literal runnable command.
- [ ] Do types/names/signatures stay consistent across tasks? Both scripts are named `generate-claude-md.sh` (one term, per the "Writing for agents" rule already in the shared content itself); both source-file pairs (`CLAUDE.cloud-only.md`/`CLAUDE.shared.md` and `CLAUDE.local-only.md`/`cloud/CLAUDE.shared.md`) are referenced identically between the scripts, the maintenance docs (pre-work), and this plan.
- [ ] Does the plan header include a `**Worktree:**` field naming the existing worktree and branch? Yes (adapted for two repos, both on the same branch name).
- [ ] Does every commit step remind the agent to run `git status` first? Yes (Task 1 Step 7, Task 2 Step 4, Task 3 Step 2).
- [ ] Does the plan include an Intentional Decisions section? Yes, above.
- [ ] Does the final task delete the plan file? Yes (Task 3 Step 2).
