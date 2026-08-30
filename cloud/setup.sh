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

# uv is already pre-installed in cloud sessions, but the snapshot can lag
# upstream releases enough to warn on directives (e.g. `system-certs`) that
# newer uv versions renamed or reinterpreted. Update it before adding the
# extra Python versions and semgrep on top — each step logged separately so
# a failure in one doesn't get lost in, or masked by, the others.
(
    uv self update || log "warning: uv self-update failed, continuing"
    uv python install 3.12 3.13 3.14 || log "warning: uv python install failed, continuing"
    uv tool install --python 3.13 semgrep || log "warning: uv tool install semgrep failed, continuing"
) &
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

## --- Stage 3: plugins, synced straight into the skills-dir ---
# The marketplace path (`claude plugin install`) clones the plugin into
# ~/.claude/plugins/cache fine, but run non-interactively from this script
# it never persists the "installed" record: installed_plugins.json comes
# out empty and none of the plugins' skills load, even though
# settings.json's enabledPlugins looks correct and the same command
# registers correctly when run interactively inside a live session.
#
# Bypass that path entirely. Claude Code also auto-loads any directory at
# ~/.claude/skills/<name>/ that carries a .claude-plugin/plugin.json, as
# "<name>@skills-dir" — no marketplace, no `claude plugin install`, no
# settings.json entry, and (confirmed live) it shows up in the skill
# listing immediately, without a restart. phx, superpowers, and
# elements-of-style already ship exactly the directory shape this
# mechanism expects, so mirror each straight from its own repo — not the
# superpowers-marketplace repo, which is just a pointer catalogue with no
# skill content of its own.
#
# Don't also register these three via extraKnownMarketplaces/enabledPlugins:
# an installed marketplace plugin takes precedence over a skills-dir plugin
# of the same name, so the copy synced below would silently stop loading.
sync_skills_dir_plugin() {
    local name="$1" repo_url="$2" tmp
    tmp="$(mktemp -d)"

    if ! git clone --depth 1 --quiet "$repo_url" "$tmp"; then
        log "warning: failed to clone $repo_url for $name, leaving skills/$name untouched"
        rm -rf "$tmp"
        return
    fi

    local dest=~/.claude/skills/"$name"
    rm -rf "$dest"
    mkdir -p "$dest"
    for part in .claude-plugin skills agents commands hooks .mcp.json; do
        [ -e "$tmp/$part" ] || continue
        cp -r "$tmp/$part" "$dest/$part" || log "warning: failed to copy $part for $name, plugin may be incomplete"
    done
    rm -rf "$tmp"
    log "$name synced to skills-dir"
}

sync_skills_dir_plugin phx "https://github.com/todofixthis/phx-claude-siat.git"
sync_skills_dir_plugin superpowers "https://github.com/obra/superpowers.git"
sync_skills_dir_plugin elements-of-style "https://github.com/obra/the-elements-of-style.git"

log "stage 3 complete: plugins synced to skills-dir"
log "setup script finished"
exit 0
