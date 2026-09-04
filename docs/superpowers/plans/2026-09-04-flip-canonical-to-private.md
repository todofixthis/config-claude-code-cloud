# Flip Canonical Shared CLAUDE.md to Private Repo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task in this plan is fully mechanical (exact file contents, exact commands) — Inline Execution via superpowers:executing-plans is the better fit; subagent-driven-development adds dispatch overhead with no judgement calls left to delegate.

**Goal:** Replace the runtime `curl` pull (public repo canonical, private repo fetches at generation time) with a GitHub Actions push (private repo canonical, a workflow there publishes to the public repo), so the shared CLAUDE.md content is edited in one place — the private repo — without ever requiring the public repo's secret-free bootstrap to hold a credential.

**Architecture:** `config-claude/CLAUDE.shared.md` is now canonical (moved there in this branch's prior commit `307c722`). `config-claude/generate-claude-md.sh` goes back to a same-repo `cat` (no network) — the same shape `config-claude-code-cloud/cloud/generate-claude-md.sh` already has and keeps unchanged. A new workflow, `config-claude/.github/workflows/publish-shared-claude-md.yml`, triggers on push to `main` touching `CLAUDE.shared.md`: it checks out both repos, copies the file across, regenerates `config-claude-code-cloud`'s `cloud/CLAUDE.md`, bumps that repo's `cloud/pointer.sh` version comment, and pushes — using a PAT stored as a `config-claude` repository secret, since only a private repo's Actions secrets are a safe place for a credential in this whole setup.

**Pre-work already done, on this same branch, before this plan was written:**
- `config-claude` commit `307c722`: added `CLAUDE.shared.md` (moved verbatim from `config-claude-code-cloud`, now canonical here), rewrote `CLAUDE.local-only.md`'s maintenance note for the push model, allowlisted `CLAUDE.shared.md` and `.github/workflows/*.yml` in `.gitignore`.
- `config-claude-code-cloud` commits `5262787` and `fde66b5`: rewrote `cloud/CLAUDE.cloud-only.md` and `README.md` to describe `cloud/CLAUDE.shared.md` as a synced mirror (not canonical), and regenerated `cloud/CLAUDE.md` to match.
- Both new/changed maintenance-note files went through the NZ-English sweep (clean) and two rounds of audience-surrogate review. Round 1 found a real defect — both files still had bare "this repo"/"here" self-references (the exact mistake this branch was already corrected for once, on the original design) — fixed by naming both repos explicitly throughout and mechanically verified with `grep -i '\b(here|there|this repo)\b'` returning no matches in either file. Round 2's only reported finding (a claimed contradiction between two paragraphs of `config-claude/CLAUDE.local-only.md`) did not reproduce against the actual file content on disk (verified directly via `Read`) and was treated as a subagent-review artifact rather than a real defect — both files are confirmed internally consistent and mutually consistent as written.
- `config-claude`'s `.gitignore` already allowlists `.github/workflows/*.yml`, so this plan's new workflow file will be trackable without a further `.gitignore` change.

**Tech Stack:** Bash (`set -euo pipefail`) for the simplified script; GitHub Actions (`ubuntu-latest`, `actions/checkout@v4`) for the publish workflow.

**Spec:** This plan's own Architecture section — there is no separate spec document. Session context: the user (Phoenix) asked to rework the already-in-review sync mechanism so the private repo (`config-claude`) is canonical, and to explore replacing the runtime pull with a GitHub Actions publish workflow instead — the two are the same change, since a public bootstrap that's deliberately secret-free can never authenticate a pull from a private repo, so canonical-in-private only works via a push from somewhere that *can* hold a credential (a private repo's own Actions secrets).

**Worktree:** Same as the prior plan on this branch — both repos checked out directly (no nested `git worktree add`), on the harness-provided branch:
- `/home/user/config-claude-code-cloud` (branch: `claude/sync-claude-md-repos-hjidow`)
- `/home/user/config-claude` (branch: `claude/sync-claude-md-repos-hjidow`)

## Global Constraints

- `config-claude-code-cloud/cloud/generate-claude-md.sh` and `cloud/setup.sh` do not change in this plan — the public repo's role (receive a plain committed file, fetch it at cloud-bootstrap time) is unaffected by how its `cloud/CLAUDE.shared.md` gets updated.
- The new workflow must never leave either repo's `CLAUDE.md` truncated or stale on a partial failure — same temp-file-then-`mv` discipline as the existing scripts, and the workflow's own commit step must no-op cleanly (exit 0, no commit) when there's nothing to publish, rather than fail or commit an empty diff.
- No secret this plan adds may be usable for anything beyond pushing to `config-claude-code-cloud` — a fine-grained PAT scoped to that one repo's Contents (read/write) is the target credential shape, not a classic PAT with broad access.
- Creating the actual PAT and adding it as a `config-claude` repository secret is a human action no session can perform — this plan documents the requirement precisely (secret name, required scope) but does not claim to have completed it.

---

### Task 1: `config-claude` — simplify the generation script

**Files:**
- Modify: `generate-claude-md.sh` (remove the `curl`/`CLAUDE_SHARED_URL` network fetch, back to a same-repo `cat`)
- Modify: `CLAUDE.md` (becomes generated output — regenerated by the simplified script, not hand-edited)

**Interfaces:**
- Produces: `generate-claude-md.sh`, run as `bash generate-claude-md.sh` from anywhere (it `cd`s to its own directory first). No arguments, no environment variables (the `CLAUDE_SHARED_URL` override is removed — nothing external to fetch any more). Writes `CLAUDE.md`, prints `CLAUDE.md regenerated` on success, exits non-zero with nothing printed to stdout on failure (an input file unreadable) and leaves any pre-existing `CLAUDE.md` untouched.

- [ ] **Step 1: Rewrite `generate-claude-md.sh`**

```bash
#!/bin/bash
# Regenerates CLAUDE.md from CLAUDE.local-only.md and CLAUDE.shared.md — see
# CLAUDE.local-only.md for what goes in which source file.

set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
    echo "<!-- GENERATED FILE — do not edit directly. Edit CLAUDE.local-only.md and/or CLAUDE.shared.md, then re-run generate-claude-md.sh. -->"
    echo
    cat CLAUDE.local-only.md
    echo
    cat CLAUDE.shared.md
} > "$tmp"

mv "$tmp" CLAUDE.md
echo "CLAUDE.md regenerated"
```

- [ ] **Step 2: Run it and inspect the result**

```bash
cd /home/user/config-claude
bash generate-claude-md.sh
head -5 CLAUDE.md
diff <(tail -n +3 CLAUDE.md) <(cat CLAUDE.local-only.md; echo; cat CLAUDE.shared.md) && echo "DIFF CLEAN"
```

Expected: prints `CLAUDE.md regenerated`; file starts with the `<!-- GENERATED FILE -->` comment, a blank line, then `# Maintaining this file`; the `diff` prints nothing.

- [ ] **Step 3: Prove the failure case — missing input**

```bash
cd /home/user/config-claude
cp CLAUDE.md /tmp/claude-md-good-copy
mv CLAUDE.shared.md /tmp/claude-shared-moved-aside
bash generate-claude-md.sh; echo "exit: $?"
diff /tmp/claude-md-good-copy CLAUDE.md && echo "CLAUDE.md unchanged: OK"
mv /tmp/claude-shared-moved-aside CLAUDE.shared.md
rm /tmp/claude-md-good-copy
```

Expected: exits non-zero (the `cat CLAUDE.shared.md` fails, `set -e` aborts before `mv`); `diff` prints nothing and `CLAUDE.md unchanged: OK`.

- [ ] **Step 4: Commit**

Run `git status` to catch any related unstaged or untracked files, then use the `phx:creative-commits` skill. Stage `generate-claude-md.sh` and `CLAUDE.md`.

## Task 2: `config-claude` — add the publish workflow

**Files:**
- Create: `.github/workflows/publish-shared-claude-md.yml`

**Interfaces:**
- Consumes: `secrets.CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN` — a fine-grained GitHub PAT scoped to `todofixthis/config-claude-code-cloud` only, with Contents: Read and write. **A human must create this token and add it as a repository secret in `config-claude` before this workflow's first real run succeeds** — no session can do either (token creation needs GitHub's own UI or API with a broader credential than this session holds; adding it as this specific repo's secret is a settings-page action). Until it exists, a push to `main` touching `CLAUDE.shared.md` triggers the workflow, and it fails at the `config-claude-code-cloud` checkout step with an authentication error — visible as a red check on the commit, not a silent no-op.
- Produces: on push to `config-claude`'s `main` touching `CLAUDE.shared.md` (or manual `workflow_dispatch`), updates `config-claude-code-cloud`'s `cloud/CLAUDE.shared.md`, `cloud/CLAUDE.md`, and `cloud/pointer.sh`'s version comment, committed and pushed to that repo's `main` as `github-actions[bot]`.

- [ ] **Step 1: Write `.github/workflows/publish-shared-claude-md.yml`**

```yaml
name: Publish shared CLAUDE.md

on:
  push:
    branches: [main]
    paths:
      - CLAUDE.shared.md
  workflow_dispatch: {}

permissions:
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout config-claude
        uses: actions/checkout@v4
        with:
          path: config-claude

      - name: Checkout config-claude-code-cloud
        uses: actions/checkout@v4
        with:
          repository: todofixthis/config-claude-code-cloud
          ref: main
          token: ${{ secrets.CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN }}
          path: config-claude-code-cloud

      - name: Copy shared file and regenerate cloud/CLAUDE.md
        run: |
          cp config-claude/CLAUDE.shared.md config-claude-code-cloud/cloud/CLAUDE.shared.md
          cd config-claude-code-cloud
          bash cloud/generate-claude-md.sh

      - name: Bump pointer.sh version comment
        working-directory: config-claude-code-cloud
        run: |
          version="$(date -u +%Y-%m-%d)-$(git -C ../config-claude rev-parse --short HEAD)"
          sed -i "s/^# Bootstrap version: .*/# Bootstrap version: ${version}/" cloud/pointer.sh

      - name: Commit and push
        working-directory: config-claude-code-cloud
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add cloud/CLAUDE.shared.md cloud/CLAUDE.md cloud/pointer.sh
          if git diff --cached --quiet; then
            echo "No changes to publish"
            exit 0
          fi
          git commit -m "Sync cloud/CLAUDE.shared.md from config-claude@${{ github.sha }}"
          git push
```

- [ ] **Step 2: Validate YAML syntax**

```bash
cd /home/user/config-claude
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/publish-shared-claude-md.yml')); print('YAML valid')"
```

Expected: prints `YAML valid`. (No `actionlint` or `yamllint` is installed in this environment — this is a syntax check only, not a schema/semantics check. GitHub validates the workflow schema itself on push; a schema error would show as a failed/skipped run in the Actions tab, not a local failure here.)

- [ ] **Step 3: Dry-run the workflow's shell logic against real local checkouts**

The `actions/checkout` steps and the cross-repo push can't be exercised locally (no GitHub Actions runner, no way to test the PAT before it exists). What *can* be verified locally is that the shell logic the workflow runs is correct, using the already-present local clones in place of the checkout steps:

```bash
cd /home/user
cp -r config-claude-code-cloud /tmp/gha-dry-run-cccc
cp config-claude/CLAUDE.shared.md /tmp/gha-dry-run-cccc/cloud/CLAUDE.shared.md
cd /tmp/gha-dry-run-cccc
bash cloud/generate-claude-md.sh
version="$(date -u +%Y-%m-%d)-$(git -C /home/user/config-claude rev-parse --short HEAD)"
sed -i "s/^# Bootstrap version: .*/# Bootstrap version: ${version}/" cloud/pointer.sh
head -5 cloud/pointer.sh
git add cloud/CLAUDE.shared.md cloud/CLAUDE.md cloud/pointer.sh
git diff --cached --stat
cd /home/user && rm -rf /tmp/gha-dry-run-cccc
```

Expected: `cloud/generate-claude-md.sh` prints `cloud/CLAUDE.md regenerated`; `cloud/pointer.sh`'s first lines show the new `# Bootstrap version: <date>-<short-sha>` line (matching the `<short-sha>` of `config-claude`'s current `HEAD`); `git diff --cached --stat` shows changes only if the copied `CLAUDE.shared.md` actually differs from the dry-run clone's existing one, or if the version-comment line changed (it always will, since the sha is fresh) — confirming the no-op guard's condition (`git diff --cached --quiet`) is meaningful and not vacuously true or false. Delete the scratch clone afterward regardless of outcome.

- [ ] **Step 4: Commit**

Run `git status` to catch any related unstaged or untracked files, then use the `phx:creative-commits` skill. Stage `.github/workflows/publish-shared-claude-md.yml`.

## Task 3: Update both PR descriptions and wrap up

- [ ] **Step 1: Rewrite PR #9's description** (`todofixthis/config-claude-code-cloud`)

Use `mcp__github__update_pull_request` (or equivalent) to replace the body, reflecting that `cloud/CLAUDE.shared.md` is now a synced mirror (not canonical) and that `config-claude`'s new workflow publishes to it — cite the actual commits on this branch (`5262787`, `fde66b5`, plus this plan's Task 1/2 commits' SHAs once known). Re-run the writing-style passes (NZ-English, conciseness, audience-surrogate — a PR description is an explicit rule-4 durable artefact) on the new body before posting, per this repo's own `cloud/CLAUDE.shared.md`.

- [ ] **Step 2: Rewrite PR #1's description** (`todofixthis/config-claude`)

Same treatment, reflecting that `CLAUDE.shared.md` is now canonical here, `generate-claude-md.sh` no longer does a network fetch, and a new workflow requires a manually-created PAT secret (name it, name the required scope, and state plainly that this PR cannot merge safely — or rather, can merge, but the workflow will fail loudly until the secret exists — without that human step). This is the PR body's job to say clearly, since it's the point where the human decides whether to add the secret before or after merging.

- [ ] **Step 3: Re-verify both generated files reproduce cleanly**

```bash
cd /home/user/config-claude-code-cloud && bash cloud/generate-claude-md.sh && git status --short
cd /home/user/config-claude && bash generate-claude-md.sh && git status --short
```

Expected: both `git status --short` calls print nothing.

- [ ] **Step 4: Delete this plan file and commit**

```bash
cd /home/user/config-claude-code-cloud
rm docs/superpowers/plans/2026-09-04-flip-canonical-to-private.md
git add docs/superpowers/plans/2026-09-04-flip-canonical-to-private.md
git status
```

Use the `phx:creative-commits` skill for this commit.

- [ ] **Step 5: Push both repos**

Both already have their upstream set — plain `git push` in each repo suffices. The existing PR subscriptions (already active from the prior round) will pick up the new pushes; no need to re-subscribe.

## Intentional Decisions

*(Populated during review — reviewers must not re-raise these)*

- The workflow pushes straight to `config-claude-code-cloud`'s `main`, no PR gate on the public side — the content is already reviewed via `config-claude`'s own PR, and a second review gate on an automated mirror-sync would just be a rubber stamp. Revisit if `config-claude-code-cloud` ever gains branch protection requiring reviews on `main`.
- The workflow auto-bumps `cloud/pointer.sh`'s version comment using `<UTC date>-<short SHA of the triggering commit>` rather than the existing manual `<date>-<sequential number>` convention — guarantees uniqueness even for multiple same-day publishes without needing to inspect git history for a same-day counter, at the cost of the two conventions looking slightly different where a human bumps the file by hand (for `setup.sh`/`gh-config.yml` changes) versus where the workflow bumps it. Both are still `# Bootstrap version: <string>` and both work identically for cache-busting purposes.
- No CI validation was added to reject a `CLAUDE.shared.md` edit that isn't followed by regenerating `CLAUDE.md` in the same commit (a drift-detection safety net) — out of scope for this plan, same reasoning as the earlier design conversation: it's a complementary safeguard, not what was asked for.

## Self-Review Checklist

- [ ] Does every task's spec requirement trace to a step? (Script simplification: Task 1. Workflow: Task 2. PR description updates and final verification: Task 3.)
- [ ] Any placeholders ("TBD", "similar to Task N", steps without real content)? None — every step has full file contents or a literal runnable command.
- [ ] Do types/names/signatures stay consistent across tasks? `generate-claude-md.sh` named identically to its `config-claude-code-cloud` counterpart; the secret name `CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN` is used identically in the workflow YAML and in Task 3's PR-description instructions.
- [ ] Does the plan header include a `**Worktree:**` field naming the existing worktree and branch? Yes.
- [ ] Does every commit step remind the agent to run `git status` first? Yes (Task 1 Step 4, Task 2 Step 4, Task 3 Step 4).
- [ ] Does the plan include an Intentional Decisions section? Yes, above.
- [ ] Does the final task delete the plan file? Yes (Task 3 Step 4).
