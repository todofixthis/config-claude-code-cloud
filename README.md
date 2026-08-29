# config-claude-code-cloud

Bootstrap config for Phoenix's Claude Code on the web (cloud) environments — the cloud counterpart to the `config-leash` repo, which covers the local Leash/Docker setup instead. Cloud environments only take a single Setup script and a single `.env` snippet, pasted into a UI dialog with no version history — so the actual content lives here instead, and the dialog just points at it.

## Structure

- `cloud/pointer.sh` — paste verbatim into the environment's **Setup script** field. Fetches and runs `cloud/setup.sh` below.
- `cloud/setup.sh` — the real logic: installs `gh`, lefthook, hadolint, trufflehog, extra Python versions, and semgrep; writes `cloud/gh-config.yml` and `cloud/CLAUDE.md` (below) into place; registers the plugin marketplaces and enabled plugins in `~/.claude/settings.json`.
- `cloud/CLAUDE.md` — personal user-level instructions. Cloud sessions don't carry over `~/.claude/CLAUDE.md` from a local machine (only repo-committed `CLAUDE.md` files do), so this is the only way to get it into cloud sessions at all.
- `cloud/gh-config.yml` — `gh` CLI preferences. Note `git_protocol: https`, not `ssh` — cloud sessions have no SSH client, so `gh` needs HTTPS to have any credential to use.
- `cloud/environment.env` — paste verbatim into the environment's **Environment variables** field.

## One-time environment setup

1. At [claude.ai/code](https://claude.ai/code), open the environment dialog (the cloud icon above the message box → settings gear on the environment you're configuring).
2. Set **Network access** to **Custom**, keep "also include default list of common package managers" checked, and add `*.cloudsmith.io` (needed for lefthook's package repo — everything else installs from domains already on the Trusted default list).
3. Paste `cloud/pointer.sh`'s content into **Setup script**.
4. Paste `cloud/environment.env`'s content into **Environment variables**.
5. Save. The setup script runs once, on the first session in this environment, and is cached (~7 days, or until the setup script text or allowed domains change) for every session after that.

## Making changes

- **Editing `setup.sh`, `CLAUDE.md`, or `gh-config.yml`**: commit the change here, then bump the version comment at the top of `cloud/pointer.sh` and re-paste `pointer.sh`'s content into the environment's Setup script field. This step is the whole reason `pointer.sh` exists: the environment only re-runs its setup script (and rebuilds the cached snapshot) when *that field's own text* changes — never when the file it fetches does. Skipping the re-paste means the change sits in this repo but never reaches a session.
- **Editing `pointer.sh` or `environment.env` itself**: re-paste directly, no version bump needed (the text already changed).
- **Adding a plugin**: add it to the `extraKnownMarketplaces`/`enabledPlugins` block in `cloud/setup.sh`, then follow the bump-and-re-paste step above.
- **A cloud session editing `~/.claude/CLAUDE.md` in place** (e.g. `phx:reflection` deciding to record a new pattern): that's the fetched copy, not this repo — the edit is invisible everywhere else and is gone at the next cache rebuild. `cloud/CLAUDE.md` itself carries this same warning, since that's what a session is reading right when it'd make this mistake.

## Why this exists instead of one script pasted straight into the dialog

Two different things were living in one place: toolchain installs, which change rarely, and personal preferences (`CLAUDE.md`, in particular), which change often — and the dialog gives neither of them git history, diffs, or review. Splitting the real content into this repo fixes that; `pointer.sh` is the two-line adapter that makes the dialog agree to defer to it.

## What's deliberately not here

- **GPG commit signing.** Cloud environments have no secrets store, and Anthropic's own docs say signing keys are kept out of the session sandbox entirely — there's no code path for a personal key to plug into, quite apart from nowhere safe to store one.
- **PyPI publishing credentials.** Same reasoning — no secrets store, so no token lives here. Publish from local Leash instead.
- **SSH keys.** Cloud sessions have no SSH client at all; all GitHub git operations go through Anthropic's own GitHub proxy with short-lived scoped credentials instead.
