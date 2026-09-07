# Exclusive CLAUDE.shared.md Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Every task in this plan is fully mechanical (exact file contents, exact commands) — Inline Execution via superpowers:executing-plans is the better fit; subagent-driven-development adds dispatch overhead with no judgement calls left to delegate.

**Goal:** `CLAUDE.shared.md` becomes structurally impossible to edit in the wrong repo — it is deleted from `config-claude-code-cloud` entirely (no synced mirror, no local copy at all) and lives exclusively in `config-claude`. Generation of `CLAUDE.md` in both repos moves from "an agent runs a script and commits the result as part of a PR" to "a GitHub Actions workflow does it automatically after a push to `main`," per the user's principle that the choice of which repo to edit — and the mechanical act of regenerating — should be enforced by a deterministic tool, not left to an LLM's judgement.

**Architecture:**
- `config-claude`'s `.github/workflows/generate-and-publish-claude-md.yml` (replaces `publish-shared-claude-md.yml`): on push to `main` touching `CLAUDE.local-only.md` or `CLAUDE.shared.md`, always regenerates and pushes `config-claude`'s own `CLAUDE.md` (same-repo `cat`, unchanged script). When the push's diff included `CLAUDE.shared.md` specifically (detected via `git diff --name-only "$before" "$after"`, not just "the workflow ran" — it also runs for local-only-only changes), it additionally checks out `config-claude-code-cloud` (existing `CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN` secret), regenerates that repo's `cloud/CLAUDE.md` directly from its own just-fetched `CLAUDE.shared.md` plus the checked-out `cloud/CLAUDE.cloud-only.md`, bumps `cloud/pointer.sh`'s version, and pushes. `CLAUDE.shared.md` itself is never written into `config-claude-code-cloud`'s working tree at any point in this path — only its *content*, already concatenated into `cloud/CLAUDE.md`.
- `config-claude-code-cloud`'s `.github/workflows/generate-claude-md.yml` (new): on push to `main` touching `cloud/CLAUDE.cloud-only.md`, runs `cloud/generate-claude-md.sh` (rewritten to fetch `CLAUDE.shared.md` live from `config-claude` via `gh api repos/todofixthis/config-claude/contents/CLAUDE.shared.md`, authenticated by the new `CONFIG_CLAUDE_READ_TOKEN` secret set as `GH_TOKEN`), bumps `cloud/pointer.sh`'s version, and pushes.
- `cloud/CLAUDE.shared.md` is deleted from `config-claude-code-cloud` — it never existed as a source file there again after this plan; the repo holds zero copies of shared content at rest.

**A verification limitation to be upfront about, not worked around:** this session's sandbox proxies `gh api` (`GH_TOKEN`/`GITHUB_TOKEN` are literally the string `proxy-injected`) and the Contents API call this design depends on returns 404 here — confirmed by testing it directly, both with and without the injected token — even though the same content is fetchable through Anthropic's own MCP GitHub integration (`mcp__github__get_file_contents`), which uses different, properly-scoped credentials. This is the sandbox's own restriction, not evidence the design is broken: on Phoenix's local machine, `gh auth login` provides a real, unrestricted token with access to both of Phoenix's own repos; inside the actual GitHub Actions runner, `GH_TOKEN` will be set from the real `CONFIG_CLAUDE_READ_TOKEN` secret, talking to the real `api.github.com` with no proxy in between. Task 2 tests everything about `cloud/generate-claude-md.sh` that doesn't require this specific call to actually succeed, and says exactly that plainly rather than papering over it with a fake success.

**Pre-work already done, on this same branch, before this plan was written:**
- `config-claude` commit `d38b45f`: rewrote `CLAUDE.local-only.md` and `README.md` for exclusive ownership and CI-driven generation, including the read-only-PAT setup instructions consumed by Task 2 below.
- `config-claude-code-cloud` commit `cb9e0b6`: rewrote `cloud/CLAUDE.cloud-only.md` and `README.md` to the same effect on the public-repo side.
- Both pairs of docs went through the NZ-English sweep (clean, same pre-existing `dialog`/`color` exemptions as prior rounds) and audience-surrogate review. The agent-facing review correctly flagged that the docs describe automation ( `generate-and-publish-claude-md.yml`, `generate-claude-md.yml`) that doesn't exist on disk yet — expected, since building it is this plan's job, not a defect in the docs themselves — and one real wording ambiguity (which workflow's push the docs were attributing a given action to), fixed before committing. The human-facing README review found nothing material.

**Tech Stack:** Bash (`set -euo pipefail`), GitHub Actions (`ubuntu-latest`, `actions/checkout@v4`), GitHub CLI (`gh api`) for the live cross-repo read.

**Spec:** The user's own four-point message in this conversation, verbatim in intent:
1. `CLAUDE.shared.md` lives exclusively in `config-claude`.
2. Local-only change → edit `CLAUDE.local-only.md` in `config-claude` (absent from `config-claude-code-cloud`) → on merge, CI generates and publishes `config-claude`'s own `CLAUDE.md`.
3. Cloud-only change → edit `CLAUDE.cloud-only.md` in `config-claude-code-cloud` (absent from `config-claude`) → on merge, CI generates and publishes `config-claude-code-cloud`'s own `cloud/CLAUDE.md`.
4. Shared change → edit `CLAUDE.shared.md` in `config-claude` → on merge, CI detects the shared file changed and generates + publishes `CLAUDE.md` in *both* repositories.

Valid = all four behaviours above, with `CLAUDE.shared.md` never present as a file in `config-claude-code-cloud` at any point (not even transiently committed). Invalid = any local copy or sync of `CLAUDE.shared.md` surviving in `config-claude-code-cloud`, an agent still expected to run a script and commit `CLAUDE.md` as part of a PR, or a workflow that fails to distinguish "local-only changed" from "shared changed" in `config-claude` (both must regenerate `config-claude`'s own file; only the latter must also touch `config-claude-code-cloud`).

**Worktree:** Same as prior plans on this branch — both repos checked out directly (no nested `git worktree add`):
- `/home/user/config-claude-code-cloud` (branch: `claude/sync-claude-md-repos-hjidow`)
- `/home/user/config-claude` (branch: `claude/sync-claude-md-repos-hjidow`)

## Global Constraints

- `CLAUDE.shared.md` must never be committed, even transiently, to `config-claude-code-cloud` by any script or workflow this plan adds — verify this by checking `git status`/`git diff --cached` in the dry runs, not just by reading the YAML.
- Both workflows' no-op guards must check for an actual content diff before bumping `cloud/pointer.sh`'s version comment, exactly as fixed in the prior round's review (bump-before-diff-check silently defeats the guard) — reuse that ordering, don't reintroduce the bug.
- `config-claude-code-cloud/cloud/setup.sh` does not change.
- Every new commit step (docs and code) that self-references a repo must name it explicitly (`todofixthis/config-claude` / `todofixthis/config-claude-code-cloud`) rather than "this repo"/"here" in any file whose content is concatenated into a global `~/.claude/CLAUDE.md` — this exact mistake has recurred twice already on this branch; grep every such file for `\b(here|there'?s?|this repo)\b` (case-insensitive) before committing, and read it too, since the grep alone has already been shown not to catch everything a careful read does.

---

### Task 1: `config-claude` — replace the publish workflow

**Files:**
- Delete: `.github/workflows/publish-shared-claude-md.yml`
- Create: `.github/workflows/generate-and-publish-claude-md.yml`

**Interfaces:**
- Consumes: `secrets.CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN` (already exists, per the user's message).
- Produces: on push to `main` touching `CLAUDE.local-only.md` and/or `CLAUDE.shared.md` (or manual `workflow_dispatch`), always regenerates and commits `config-claude`'s own `CLAUDE.md`; when the triggering diff included `CLAUDE.shared.md`, also regenerates and pushes `config-claude-code-cloud`'s `cloud/CLAUDE.md` directly.

- [ ] **Step 1: Delete the old workflow**

```bash
cd /home/user/config-claude
rm .github/workflows/publish-shared-claude-md.yml
```

- [ ] **Step 2: Write `.github/workflows/generate-and-publish-claude-md.yml`**

```yaml
name: Generate and publish CLAUDE.md

on:
  push:
    branches: [main]
    paths:
      - CLAUDE.local-only.md
      - CLAUDE.shared.md
  workflow_dispatch: {}

# write, not read: the default GITHUB_TOKEN this grants is what the
# self-checkout below pushes back to config-claude with — the separate
# cross-repo push to config-claude-code-cloud always uses its own PAT
# regardless of this setting.
permissions:
  contents: write

concurrency:
  group: generate-and-publish-claude-md
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout config-claude
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Regenerate and push this repo's CLAUDE.md
        run: |
          bash generate-claude-md.sh
          git add CLAUDE.md
          if git diff --cached --quiet; then
            echo "No changes to config-claude/CLAUDE.md"
          else
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git commit -m "Regenerate CLAUDE.md"
            git push
          fi

      - name: Check whether CLAUDE.shared.md changed
        id: shared_check
        run: |
          before="${{ github.event.before }}"
          if [ "$before" = "0000000000000000000000000000000000000000" ] || ! git cat-file -e "$before" 2>/dev/null; then
            before="$(git hash-object -t tree /dev/null)"
          fi
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "shared_changed=true" >> "$GITHUB_OUTPUT"
          elif git diff --name-only "$before" "${{ github.sha }}" | grep -qx "CLAUDE.shared.md"; then
            echo "shared_changed=true" >> "$GITHUB_OUTPUT"
          else
            echo "shared_changed=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Checkout config-claude-code-cloud
        if: steps.shared_check.outputs.shared_changed == 'true'
        uses: actions/checkout@v4
        with:
          repository: todofixthis/config-claude-code-cloud
          ref: main
          token: ${{ secrets.CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN }}
          path: config-claude-code-cloud

      - name: Regenerate config-claude-code-cloud's CLAUDE.md and check for changes
        if: steps.shared_check.outputs.shared_changed == 'true'
        id: regenerate_cloud
        working-directory: config-claude-code-cloud
        run: |
          {
            echo "<!-- GENERATED FILE — do not edit directly. Edit cloud/CLAUDE.cloud-only.md in todofixthis/config-claude-code-cloud, or CLAUDE.shared.md in todofixthis/config-claude, then re-run cloud/generate-claude-md.sh. -->"
            echo
            cat cloud/CLAUDE.cloud-only.md
            echo
            cat ../CLAUDE.shared.md
          } > /tmp/cloud-claude-md
          mv /tmp/cloud-claude-md cloud/CLAUDE.md
          git add cloud/CLAUDE.md
          if git diff --cached --quiet; then
            echo "changed=false" >> "$GITHUB_OUTPUT"
          else
            echo "changed=true" >> "$GITHUB_OUTPUT"
          fi

      - name: Bump pointer.sh version comment
        if: steps.shared_check.outputs.shared_changed == 'true' && steps.regenerate_cloud.outputs.changed == 'true'
        working-directory: config-claude-code-cloud
        run: |
          version="$(date -u +%Y-%m-%d)-$(git -C .. rev-parse --short HEAD)"
          sed -i "s/^# Bootstrap version: .*/# Bootstrap version: ${version}/" cloud/pointer.sh
          git add cloud/pointer.sh

      - name: Commit and push config-claude-code-cloud
        if: steps.shared_check.outputs.shared_changed == 'true' && steps.regenerate_cloud.outputs.changed == 'true'
        working-directory: config-claude-code-cloud
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit -m "Sync cloud/CLAUDE.md from config-claude@${{ github.sha }}"
          git push || (git fetch origin main && git rebase origin/main && git push)
```

The last step's `||` retry covers the rare case of `config-claude-code-cloud`'s `main` moving between this job's checkout and its push (e.g. `generate-claude-md.yml` from Task 2 pushing at the same time) — a plain rebase-and-retry, once, rather than leaving a failed push unresolved.

- [ ] **Step 3: Validate YAML syntax**

```bash
cd /home/user/config-claude
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/generate-and-publish-claude-md.yml')); print('YAML valid')"
```

Expected: prints `YAML valid`.

- [ ] **Step 4: Dry-run the "local-only changed" path (no cross-repo publish)**

Fully testable locally — no network, no secrets:

```bash
cd /home/user
cp -r config-claude /tmp/gha-dry-run-cc
cd /tmp/gha-dry-run-cc
before="$(git rev-parse HEAD)"
echo "- a dry-run-only local addition" >> CLAUDE.local-only.md
git add CLAUDE.local-only.md
git commit -q -m "dry run: local-only change"
after="$(git rev-parse HEAD)"
bash generate-claude-md.sh
git add CLAUDE.md
git diff --cached --quiet && echo "BUG: expected CLAUDE.md to change" || echo "CLAUDE.md changed: OK"
if git diff --name-only "$before" "$after" | grep -qx "CLAUDE.shared.md"; then
  echo "shared_changed=true-BUG"
else
  echo "shared_changed=false: OK (local-only-only change must not trigger the cross-repo path)"
fi
cd /home/user && rm -rf /tmp/gha-dry-run-cc
```

Expected: `CLAUDE.md changed: OK` and `shared_changed=false: OK`.

- [ ] **Step 5: Dry-run the "shared changed" path (cross-repo publish, no live fetch needed)**

Also fully testable locally: `config-claude`'s workflow never fetches anything live — it already owns `CLAUDE.shared.md` — so this exercises the real logic end-to-end except for the actual `actions/checkout`/PAT machinery, using local clones in their place:

```bash
cd /home/user
cp -r config-claude /tmp/gha-dry-run-cc
cp -r config-claude-code-cloud /tmp/gha-dry-run-cccc
cd /tmp/gha-dry-run-cc
before="$(git rev-parse HEAD)"
echo "- a dry-run-only shared addition" >> CLAUDE.shared.md
git add CLAUDE.shared.md
git commit -q -m "dry run: shared change"
after="$(git rev-parse HEAD)"
bash generate-claude-md.sh
if git diff --name-only "$before" "$after" | grep -qx "CLAUDE.shared.md"; then
  echo "shared_changed=true: OK"
else
  echo "shared_changed=false-BUG"
fi

cd /tmp/gha-dry-run-cccc
# Simulate the post-Task-2 state: at the point this workflow actually runs
# for real, Task 2 has already deleted cloud/CLAUDE.shared.md from
# config-claude-code-cloud. This scratch clone was copied from the repo as
# it stands *before* Task 2 runs, so remove it here to test the invariant
# meaningfully rather than against a file this step didn't itself create.
rm -f cloud/CLAUDE.shared.md
{
  echo "<!-- GENERATED FILE -->"
  echo
  cat cloud/CLAUDE.cloud-only.md
  echo
  cat /tmp/gha-dry-run-cc/CLAUDE.shared.md
} > /tmp/cloud-claude-md
mv /tmp/cloud-claude-md cloud/CLAUDE.md
git add cloud/CLAUDE.md
git diff --cached --quiet && echo "BUG: expected cloud/CLAUDE.md to change" || echo "cloud/CLAUDE.md changed: OK"
version="$(date -u +%Y-%m-%d)-$(git -C /tmp/gha-dry-run-cc rev-parse --short HEAD)"
sed -i "s/^# Bootstrap version: .*/# Bootstrap version: ${version}/" cloud/pointer.sh
head -5 cloud/pointer.sh
[ -e cloud/CLAUDE.shared.md ] && echo "BUG: CLAUDE.shared.md must never exist in config-claude-code-cloud's working tree" || echo "No CLAUDE.shared.md in config-claude-code-cloud: OK"

cd /home/user && rm -rf /tmp/gha-dry-run-cc /tmp/gha-dry-run-cccc
```

Expected: `shared_changed=true: OK`, `cloud/CLAUDE.md changed: OK`, the bumped version line, and `No CLAUDE.shared.md in config-claude-code-cloud: OK` — the last check tests the file's *existence*, not a diff against it, since a diff-based check (`git status --short`) cannot distinguish "file absent" from "file present and unchanged," and this repo currently has the file present and identical to `config-claude`'s copy until Task 2 deletes it for real.

- [ ] **Step 6: Commit**

Run `git status` to catch any related unstaged or untracked files, then use the `phx:creative-commits` skill. Stage the deleted `publish-shared-claude-md.yml` and the new `generate-and-publish-claude-md.yml`.

## Task 2: `config-claude-code-cloud` — remove the local copy, fetch live

**Files:**
- Delete: `cloud/CLAUDE.shared.md`
- Modify: `cloud/generate-claude-md.sh` (fetch `CLAUDE.shared.md` live instead of reading a local copy)
- Create: `.github/workflows/generate-claude-md.yml`

**Interfaces:**
- Consumes: `secrets.CONFIG_CLAUDE_READ_TOKEN` — a fine-grained PAT scoped to `todofixthis/config-claude` (Contents: Read-only), documented in `README.md`'s new "One-time setup" section, not yet created by the user (per their message, only `CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN` exists so far).
- Produces: `cloud/generate-claude-md.sh`, run as `bash cloud/generate-claude-md.sh` (needs `gh` authenticated — a human's own `gh auth login` locally, or `GH_TOKEN` set from the secret in CI). Writes `cloud/CLAUDE.md`, prints `cloud/CLAUDE.md regenerated` on success, exits non-zero with nothing printed to stdout on failure (`gh api` failing, or `cloud/CLAUDE.cloud-only.md` missing) and leaves any pre-existing `cloud/CLAUDE.md` untouched.

- [ ] **Step 1: Delete the local shared-content copy**

```bash
cd /home/user/config-claude-code-cloud
rm cloud/CLAUDE.shared.md
```

- [ ] **Step 2: Rewrite `cloud/generate-claude-md.sh`**

```bash
#!/bin/bash
# Regenerates cloud/CLAUDE.md from cloud/CLAUDE.cloud-only.md
# (todofixthis/config-claude-code-cloud) and CLAUDE.shared.md, fetched live
# from todofixthis/config-claude (private — never mirrored into
# todofixthis/config-claude-code-cloud) via the GitHub Contents API. Locally
# this uses your own `gh auth login`; in CI, the workflow sets GH_TOKEN from
# the CONFIG_CLAUDE_READ_TOKEN secret — see README.md for how to create it.

set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
    echo "<!-- GENERATED FILE — do not edit directly. Edit cloud/CLAUDE.cloud-only.md in todofixthis/config-claude-code-cloud, or CLAUDE.shared.md in todofixthis/config-claude, then re-run cloud/generate-claude-md.sh. -->"
    echo
    cat CLAUDE.cloud-only.md
    echo
    gh api repos/todofixthis/config-claude/contents/CLAUDE.shared.md --jq '.content' | base64 -d
} > "$tmp"

mv "$tmp" CLAUDE.md
echo "cloud/CLAUDE.md regenerated"
```

- [ ] **Step 3: Write `.github/workflows/generate-claude-md.yml`**

```yaml
name: Generate CLAUDE.md

on:
  push:
    branches: [main]
    paths:
      - cloud/CLAUDE.cloud-only.md
  workflow_dispatch: {}

# write, not read: the default GITHUB_TOKEN this grants is what the
# self-checkout below pushes back to this repo with.
permissions:
  contents: write

concurrency:
  group: generate-claude-md
  cancel-in-progress: false

jobs:
  publish:
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: ${{ secrets.CONFIG_CLAUDE_READ_TOKEN }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Regenerate cloud/CLAUDE.md
        run: bash cloud/generate-claude-md.sh

      - name: Check for changes, bump version, commit, and push
        run: |
          git add cloud/CLAUDE.md
          if git diff --cached --quiet; then
            echo "No changes to publish"
            exit 0
          fi
          version="$(date -u +%Y-%m-%d)-$(git rev-parse --short HEAD)"
          sed -i "s/^# Bootstrap version: .*/# Bootstrap version: ${version}/" cloud/pointer.sh
          git add cloud/pointer.sh
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git commit -m "Regenerate cloud/CLAUDE.md"
          git push
```

The diff check on `cloud/CLAUDE.md` runs before `cloud/pointer.sh` is touched, same ordering as Task 1 and the prior round's fix — the version bump must never be staged before the no-op guard evaluates it.

- [ ] **Step 4: Validate YAML syntax**

```bash
cd /home/user/config-claude-code-cloud
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/generate-claude-md.yml')); print('YAML valid')"
```

- [ ] **Step 5: Test everything except the live fetch, and say so explicitly**

The `gh api repos/todofixthis/config-claude/contents/CLAUDE.shared.md` call cannot be exercised from this session — confirmed by testing it directly: this sandbox's `GH_TOKEN`/`GITHUB_TOKEN` are proxy placeholders (`proxy-injected`) and the Contents API 404s through them, even though the same file is fetchable via Anthropic's own MCP GitHub integration using different credentials. This is not evidence the design is wrong — a real `gh auth login` (Phoenix's own machine) or a real `CONFIG_CLAUDE_READ_TOKEN` (CI) talks to `api.github.com` directly with no proxy in between. What this step tests instead: the failure path, and the concatenation logic once given real shared content by another means.

```bash
cd /home/user

# Failure path, against the real (unstubbed) script and the real repo:
# gh unauthenticated/unreachable is exactly what happens today, since the
# real secret doesn't exist yet — confirm it fails closed.
cd config-claude-code-cloud
cp cloud/CLAUDE.md /tmp/claude-md-good-copy 2>/dev/null || touch /tmp/claude-md-good-copy
bash cloud/generate-claude-md.sh; echo "exit: $?"
diff /tmp/claude-md-good-copy cloud/CLAUDE.md 2>/dev/null && echo "cloud/CLAUDE.md unchanged: OK"
rm /tmp/claude-md-good-copy
cd /home/user

# Success path: run the real, unmodified cloud/generate-claude-md.sh — in a
# scratch copy, not the live checkout — with `gh` shimmed on PATH so the
# script's own logic (mktemp, trap, cd, the header, the ordering of the two
# `cat`s) runs for real, rather than a hand-written reimplementation that
# could pass while the actual script is broken.
cp -r config-claude-code-cloud /tmp/gha-dry-run-cccc
mkdir -p /tmp/gh-stub-bin
cat > /tmp/gh-stub-bin/gh <<'STUB'
#!/bin/bash
# Test stub standing in for the real `gh` CLI, for the one call
# cloud/generate-claude-md.sh makes: emits the base64 of a local copy of
# CLAUDE.shared.md, as if `gh api ... --jq '.content'` had returned it.
if [ "$1" = "api" ] && [[ "$2" == repos/todofixthis/config-claude/contents/CLAUDE.shared.md* ]]; then
    base64 -w0 /tmp/claude-shared-stub-source.md
    exit 0
fi
echo "unexpected gh invocation: $*" >&2
exit 1
STUB
chmod +x /tmp/gh-stub-bin/gh
cp config-claude/CLAUDE.shared.md /tmp/claude-shared-stub-source.md

cd /tmp/gha-dry-run-cccc
PATH="/tmp/gh-stub-bin:$PATH" bash cloud/generate-claude-md.sh
head -5 cloud/CLAUDE.md
diff <(tail -n +3 cloud/CLAUDE.md) <(cat cloud/CLAUDE.cloud-only.md; echo; cat /tmp/claude-shared-stub-source.md) && echo "DIFF CLEAN"

cd /home/user
rm -rf /tmp/gha-dry-run-cccc /tmp/gh-stub-bin /tmp/claude-shared-stub-source.md
```

Expected: the unstubbed run against the real repo exits non-zero (no working `gh` auth) and leaves `cloud/CLAUDE.md` unchanged, proving the failure path is safe; the shimmed run of the real, unmodified script prints `cloud/CLAUDE.md regenerated`, and the `diff` against a fresh concatenation of the two real source files is clean, proving the script's own logic — not a hand-written stand-in for it — is correct end-to-end except for the one call the shim replaces. Note in the commit message and PR description that the live `gh api` call itself remains unverified pending the real secret.

- [ ] **Step 6: Commit**

Run `git status` to catch any related unstaged or untracked files, then use the `phx:creative-commits` skill. Stage the deleted `cloud/CLAUDE.shared.md`, the rewritten `cloud/generate-claude-md.sh`, and the new `.github/workflows/generate-claude-md.yml`.

## Task 3: Update both PR descriptions and wrap up

- [ ] **Step 1: Rewrite PR #9's description** (`todofixthis/config-claude-code-cloud`)

Run `git log --oneline main..HEAD` in `/home/user/config-claude-code-cloud` first for real SHAs. Replace the body to describe: `cloud/CLAUDE.shared.md` no longer exists in this repo at all (not a mirror, not present); `cloud/generate-claude-md.sh` fetches it live; the new `.github/workflows/generate-claude-md.yml`; the still-needed `CONFIG_CLAUDE_READ_TOKEN` secret; and the sandbox limitation from Task 2 Step 5, stated plainly rather than glossed over. Re-run the writing-style passes (NZ-English, conciseness, audience-surrogate) before posting.

- [ ] **Step 2: Rewrite PR #1's description** (`todofixthis/config-claude`)

Same treatment: `CLAUDE.shared.md` is exclusively canonical here; `.github/workflows/generate-and-publish-claude-md.yml` replaces `publish-shared-claude-md.yml`; generation for both local-only and shared changes is now CI-driven, not agent-driven. Note that `CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN` already exists (per the user) and no change is needed to it.

- [ ] **Step 3: Regenerate both repos' CLAUDE.md one more time and verify**

```bash
cd /home/user/config-claude && bash generate-claude-md.sh && git status --short
```

Expected: prints `CLAUDE.md regenerated` and `git status --short` is empty (config-claude's own generation is unaffected by this plan — still a same-repo `cat` — so it should already be up to date; this just re-confirms it). `config-claude-code-cloud`'s `cloud/CLAUDE.md` cannot be regenerated in this session for the reason in Task 2 Step 5 — do not attempt it here; note in the PR description that it needs a real regeneration once the secret exists and the workflow has run once (`workflow_dispatch`, after merge).

- [ ] **Step 4: Delete this plan file and commit**

```bash
cd /home/user/config-claude-code-cloud
rm docs/superpowers/plans/2026-09-04-exclusive-shared-ownership.md
git add docs/superpowers/plans/2026-09-04-exclusive-shared-ownership.md
git status
```

Use the `phx:creative-commits` skill for this commit.

- [ ] **Step 5: Push both repos and tell the user what's still needed**

Both already have their upstream set — plain `git push` in each repo suffices. Final message to the user must state plainly: (a) create the `CONFIG_CLAUDE_READ_TOKEN` secret per `config-claude-code-cloud/README.md`'s new section, (b) once created, `cloud/CLAUDE.md` there is stale until the workflow runs (merge, or `workflow_dispatch` after merging), (c) the live-fetch path in `cloud/generate-claude-md.sh` was not verified end-to-end from this session — only its failure path and its concatenation logic were.

## Intentional Decisions

*(Populated during review — reviewers must not re-raise these)*

- `config-claude`'s workflow inlines the `config-claude-code-cloud` concatenation logic rather than shelling out to `cloud/generate-claude-md.sh` there — that script now does a live `gh api` fetch, which would be a redundant network round-trip when `config-claude`'s own workflow already has both files checked out locally in the same job. The two code paths (this inline block, and the standalone script) implement the same three-line concatenation twice; accepted given how small and stable that logic is, versus the complexity of making one script serve both "fetch live" and "use an already-checked-out file" modes.
- The Task 1 Step 2 workflow's cross-repo push retries once via `git fetch && git rebase && git push` on failure — a cheap guard against the two independent workflows (this one, and Task 2's) racing to push `config-claude-code-cloud`'s `main` around the same time. It doesn't fully eliminate the race (GitHub Actions concurrency groups don't span repos), just narrows the window; a true fix would need cross-repo locking, out of scope for a personal two-repo setup.
- The live-fetch call in `cloud/generate-claude-md.sh` is shipped unverified end-to-end from this session, for the reason in Task 2 Step 5 — this is disclosed in the plan, the commit, and the PR description rather than worked around with a fake local success.

## Self-Review Checklist

- [ ] Does every task's spec requirement trace to a step? (Point 2 local-only: Task 1 Steps 2, 4. Point 3 cloud-only: Task 2 Steps 2–3, 5. Point 4 shared, both repos: Task 1 Steps 2, 5. Point 1 exclusive ownership: Task 2 Step 1 deletion, verified in Task 1 Step 5's last check.)
- [ ] Any placeholders ("TBD", "similar to Task N", steps without real content)? None — every step has full file contents or a literal runnable command.
- [ ] Do types/names/signatures stay consistent across tasks? Both workflow files use identical step-id/output-name patterns (`id: regenerate_cloud` / `outputs.changed`, `id: shared_check` / `outputs.shared_changed`) to the prior round's proven pattern; secret names (`CONFIG_CLAUDE_CODE_CLOUD_PUSH_TOKEN`, `CONFIG_CLAUDE_READ_TOKEN`) match between the YAML, the README instructions, and Task 3's user-facing summary.
- [ ] Does the plan header include a `**Worktree:**` field naming the existing worktree and branch? Yes.
- [ ] Does every commit step remind the agent to run `git status` first? Yes (Task 1 Step 6, Task 2 Step 6, Task 3 Step 4).
- [ ] Does the plan include an Intentional Decisions section? Yes, above.
- [ ] Does the final task delete the plan file? Yes (Task 3 Step 4).
