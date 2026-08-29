#!/bin/bash
# Fetched and run by cloud/pointer.sh — see that file for how this wires
# into the environment dialog, and README.md for the full picture.
#
# Runs once as root on a fresh Ubuntu 24.04 VM, before Claude Code launches.
# Anthropic snapshots the filesystem afterwards and reuses it for future
# sessions in this environment.
#
# Everything here is best-effort: a single flaky download must never stop
# the session from starting, so each stage is wrapped and failures are
# logged rather than propagated. Nothing here is a secret — GPG signing and
# PyPI publishing were deliberately left out of cloud sessions, since cloud
# environments have no secrets store.
#
# Requires "Custom" network access with the Trusted defaults included, plus
# *.cloudsmith.io added (for lefthook's package repo).

set -uo pipefail

log() { echo "[setup] $*"; }

REPO_RAW="https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud"

## --- Stage 1: independent installs, run in parallel ---

# apt-based tools: GitHub CLI (gh) + lefthook.
# Neither is pre-installed on the cloud image (unlike jq/make/unzip/gnupg,
# which already are).
(
    set -uo pipefail
    apt-get update -y
    apt-get install -y --no-install-recommends apt-transport-https ca-certificates gnupg

    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    curl -1sLf 'https://dl.cloudsmith.io/public/evilmartians/lefthook/setup.deb.sh' | bash

    apt-get update -y
    apt-get install -y --no-install-recommends gh lefthook
    apt-get clean
    rm -rf /var/lib/apt/lists/*
) || log "warning: gh/lefthook install failed, continuing" &
APT_PID=$!

# hadolint: Dockerfile linter, single binary from GitHub releases.
(
    HADOLINT_ARCH=$([ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64")
    curl -sLo /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-${HADOLINT_ARCH}"
    chmod +x /usr/local/bin/hadolint
) || log "warning: hadolint install failed, continuing" &
HADOLINT_PID=$!

# trufflehog: secret scanner, installed via upstream script.
(
    curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin
) || log "warning: trufflehog install failed, continuing" &
TRUFFLEHOG_PID=$!

# uv is already pre-installed in cloud sessions — only the extra Python
# versions and semgrep need adding on top of it.
(
    uv python install 3.12 3.13 3.14
    uv tool install --python 3.13 semgrep
) || log "warning: uv python/semgrep install failed, continuing" &
UV_PID=$!

wait "$APT_PID" "$HADOLINT_PID" "$TRUFFLEHOG_PID" "$UV_PID"
log "stage 1 complete"

## --- Stage 2: config files, fetched from this repo so edits stay diffable
##     and reviewable instead of living only in the environment dialog ---

mkdir -p ~/.config/gh
if curl -fsSL "${REPO_RAW}/gh-config.yml" -o ~/.config/gh/config.yml; then
    log "gh config written"
else
    log "warning: failed to fetch gh-config.yml, gh will use its defaults"
fi

mkdir -p ~/.claude
if curl -fsSL "${REPO_RAW}/CLAUDE.md" -o ~/.claude/CLAUDE.md; then
    log "user CLAUDE.md written"
else
    log "warning: failed to fetch CLAUDE.md, continuing without it"
fi

log "stage 2 complete"

## --- Stage 3: plugin marketplaces / auto-enabled plugins ---
# Confirmed necessary, not just belt-and-braces: there's no account-level
# sync that reaches this on its own — it has to land on disk somehow before
# Claude Code launches, and this is that somehow.
#
# Merge rather than overwrite, in case a prior run (before the ~7-day cache
# expiry) already wrote this file.
python3 - <<'PY_EOF'
import json
import os

path = os.path.expanduser("~/.claude/settings.json")
try:
    with open(path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings.setdefault("extraKnownMarketplaces", {})
settings["extraKnownMarketplaces"]["todofixthis"] = {
    "source": {"source": "github", "repo": "todofixthis/phx-claude-siat"},
}
settings["extraKnownMarketplaces"]["obra"] = {
    "source": {"source": "github", "repo": "obra/superpowers-marketplace"},
}

settings.setdefault("enabledPlugins", {})
settings["enabledPlugins"]["phx@todofixthis"] = True
settings["enabledPlugins"]["superpowers@obra"] = True
settings["enabledPlugins"]["elements-of-style@obra"] = True

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY_EOF

log "stage 3 complete: plugin marketplaces registered"
log "setup script finished"
exit 0
