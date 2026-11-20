# CI checks for pull requests

## Why

Coding agents write every change to this repository. Pull requests get no checks today, because the only workflow, `.github/workflows/generate-claude-md.yml`, runs after a push to `main`. The checks are a safety net for the mistakes agents make here:

- hand-editing the generated `cloud/CLAUDE.md`
- breaking a script in `cloud/`
- writing a workflow that parses but misbehaves
- committing a secret

## Goals

- Every pull request to `main` runs the checks below. A failure blocks the merge.
- Each check fails only because of the pull request's own content, never because of state outside it.

## Non-goals

- Running `cloud/setup.sh` end to end. The cloud image isn't public, and the script downloads from many hosts, so a green run in CI would prove little about the real environment.
- Checking NZ English spelling. `phx:nz-english` is a skill, not a command CI can run.
- Local hooks through lefthook.

## Anti-goals

- A check that needs a repository secret. The checks run on agent-written pull requests.
- A check that goes red when nothing in the pull request is wrong. Examples: a `main` that moved on after the branch point, or a network failure.
- A tool version that changes without a commit. Agents can't tell a new tool's finding from their own regression.

## Approaches

**Chosen: one workflow that runs each tool directly.** Each job installs a pinned tool and runs it. Agents already receive CI results through their pull-request subscriptions, so CI alone gives them the feedback they need.

Rejected: a lefthook config as the single source, with CI running lefthook. It would add local runs, but `cloud/setup.sh` doesn't run `lefthook install` in any repository, and CI would still have to install every tool lefthook calls.

Rejected: running `cloud/setup.sh` in a container, for the reason under "Non-goals".

## Design

### The workflow

A new workflow, `.github/workflows/ci.yml`, runs on `pull_request` with no path filter. A required check that a path filter skips never reports, and so it blocks the merge. The workflow has `permissions: contents: read`. It has one job per check, so each job appears as its own required check. Job names are the required-check names, so keep them stable: a renamed job leaves a required check that never reports.

### The checks

- **Shell scripts.** Run `bash -n` and `shellcheck` on every file `git ls-files '*.sh'` lists. Fail if that list is empty, so the job can't pass by checking nothing. Use the runner's preinstalled `shellcheck`. Every job runs on `ubuntu-24.04`, not `ubuntu-latest`, so the `shellcheck` version is fixed by the Ubuntu release and changes only with a commit that changes `runs-on`. Confirm that the runner image installs `shellcheck` from Ubuntu's own packages. If it doesn't, install a pinned version with `apt-get install shellcheck=<version>` instead.
- **Workflows.** Run `actionlint` on `.github/workflows/`. Download a pinned release with `curl --retry`, and verify it against the checksums file in the same release. That catches a corrupt download, not a compromised release. `actionlint` runs the runner's `shellcheck` on `run:` blocks.
- **Renovate config.** Run `renovate-config-validator --strict` on `renovate.json`, from a pinned `renovate` npm version, under a Node version that `actions/setup-node` pins.
- **Secrets.** Run trufflehog from the `trufflesecurity/trufflehog` action over the commits between the pull request's base and head, with `fetch-depth: 0`. Pass `--results=verified` explicitly in `extra_args`, and confirm against the pinned action's entrypoint that nothing else widens it. Unverified results are pattern matches, and unknown results come from failed verification calls, such as a network error. Failing on either would break the second anti-goal.
- **Generated files.** Fail if the pull request changes `cloud/CLAUDE.md`. Compare the merge base with the head (`git diff --name-only <base>...<head>`, with `fetch-depth: 0`), not `main` with the head. The bot often pushes regenerations to `main`, so a branch cut before the latest one would otherwise fail. The bot and `todofixthis/config-claude`'s workflow push regenerations straight to `main`, never through a pull request, so a pull request that changes the file has a hand edit in it. The failure message tells the author to edit `cloud/CLAUDE.cloud-only.md` instead.

The actionlint, Renovate config, and secrets checks download their tools at run time, so a GitHub or npm outage can still turn a job red. The trufflehog action also pulls its own container image, which can hit a registry's rate limit. Both are accepted residual risk.

### Changes to existing files

- **`generate-claude-md.yml`.** Add `cloud/generate-claude-md.sh` to its `paths:`. Without it, a pull request that changes the generator can't update `cloud/CLAUDE.md`: the new check blocks the edit, and the regeneration never runs.
- **`renovate.json`.** Every action is pinned to a commit digest, as `renovate.json` already enforces. Add custom regex managers for the `actionlint`, `renovate`, and trufflehog image version pins in `ci.yml`, and group the trufflehog action and image bumps, like the existing `COSIGN_TAG` manager, which matches only `cloud/setup.sh`. Renovate's `github-actions` manager tracks `runs-on` labels, so it opens a pull request to move `ubuntu-24.04` to a newer Ubuntu release. That pull request changes the `shellcheck` version, and its CI run shows any new findings.
- **`README.md`.** Add `ci.yml` to "Structure", and say that it is no longer the only workflow. Rewrite the "Merging a Renovate PR that touches `.github/workflows/`" item, which says those pull requests get no CI. Record the step below.

### Required checks

After the workflow's first run, a person adds each job to the existing `main` ruleset as a required status check, using the exact names that run shows. No session can change the ruleset. Use the existing ruleset, not a new one or a branch-protection rule. The bot's App bypasses only that ruleset, so a separate rule would reject its direct pushes to `main`.

## Left to the builder

- The exact tool versions, job names, and trufflehog flags.
- The wording of the README changes.
