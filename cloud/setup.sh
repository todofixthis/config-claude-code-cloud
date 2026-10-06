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
# rekor.sigstore.dev and tuf-repo-cdn.sigstore.dev (for verifying
# trufflehog's signature).

set -uo pipefail

# Stage 1's installs each run in a background subshell, whose PID the wait
# after them must list. Most are guarded by `|| log` (uv's logs per step), and
# bash ignores set -e in a subshell on the left of ||, so adding it there
# silently changes nothing. An install that must stop at its first failure
# instead ends every step but the last with &&, so a failure skips the rest
# and logs the warning; cleanup goes in an EXIT trap, so the chain stays the
# subshell's last command.

log() { echo "[setup] $*"; }

# A stalled download would hold up stage 1's wait, and with it the session's
# start, so curl gets a connect timeout and an overall limit. The limit leaves
# room for the largest download here, cosign at about 130 MB, on a slow link;
# to give one call longer, pass --max-time on that call, since curl takes the
# last one given. As a shell function, this covers curl called by name here
# and in the stage subshells, but not curl run via xargs, env, timeout or
# bash -c, nor inside a vendor script piped to a shell: give those their own
# limits. Other network steps carry their own limit (git clone, cosign) or
# rely on their tool's timeouts (apt, uv, pip).
curl() { command curl --connect-timeout 20 --max-time 600 "$@"; }

# Prints a GitHub repo's latest release tag, or nothing. Release assets whose
# names carry the version need the tag first, and pinning one tag also stops a
# release landing between two downloads, so prefer it for any new release
# binary. GitHub redirects any name under releases/latest/download to the
# tagged release, and this platform's session proxy can deny the
# releases/latest page itself. Callers check for empty output: sed exits 0 on
# no match. If every install using this starts failing at once, suspect the
# redirect: GitHub may have stopped redirecting names it doesn't host.
latest_release_tag() {
    curl -sS -o /dev/null -w '%{redirect_url}' "https://github.com/$1/releases/latest/download/tag-probe" \
        | sed -n 's|.*/releases/download/\([^/]*\)/.*|\1|p'
}

REPO_RAW="https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud"

## --- Stage 1: independent installs, run in parallel ---

# apt-based tools: GitHub CLI (gh).
# Not pre-installed on the cloud image (unlike jq/make/unzip/gnupg, which
# already are). Steps are chained with && (see the top of the file); apt's
# cleanup runs on exit, whatever the outcome. Any other apt package goes in
# this stage too: a parallel apt-get would race it for the dpkg lock, and
# this trap's cleanup.
(
    set -uo pipefail
    trap 'apt-get clean; rm -rf /var/lib/apt/lists/*' EXIT
    apt-get update -y &&
    apt-get install -y --no-install-recommends apt-transport-https ca-certificates gnupg &&
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg &&
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | tee /etc/apt/sources.list.d/github-cli.list > /dev/null &&
    apt-get update -y &&
    apt-get install -y --no-install-recommends gh
) || log "warning: gh install failed, continuing" &
APT_PID=$!

# lefthook: git hooks manager, single binary from the latest release, verified
# against that release's checksum file. Steps are chained with && (see the top
# of the file).
(
    LEFTHOOK_TMP=$(mktemp -d) || exit 1
    trap 'rm -rf "${LEFTHOOK_TMP}"' EXIT
    LEFTHOOK_TAG=$(latest_release_tag evilmartians/lefthook) &&
    [ -n "${LEFTHOOK_TAG}" ] &&
    LEFTHOOK_BIN="lefthook_${LEFTHOOK_TAG#v}_Linux_$(uname -m)" &&
    LEFTHOOK_URL="https://github.com/evilmartians/lefthook/releases/download/${LEFTHOOK_TAG}" &&
    curl -sSfLo "${LEFTHOOK_TMP}/${LEFTHOOK_BIN}" "${LEFTHOOK_URL}/${LEFTHOOK_BIN}" &&
    curl -sSfLo "${LEFTHOOK_TMP}/checksums.txt" "${LEFTHOOK_URL}/lefthook_checksums.txt" &&
    # Exact-match lookup: fails on a missing entry, not only a wrong hash
    awk -v f="${LEFTHOOK_BIN}" -v d="${LEFTHOOK_TMP}" \
        '{ sub(/^\*/, "", $2) } $2 == f { print $1 "  " d "/" f; found = 1 } END { exit !found }' \
        "${LEFTHOOK_TMP}/checksums.txt" | sha256sum -c - &&
    install -m 0755 "${LEFTHOOK_TMP}/${LEFTHOOK_BIN}" /usr/local/bin/lefthook
) || log "warning: lefthook install failed, continuing" &
LEFTHOOK_PID=$!

# hadolint: Dockerfile linter, single binary from GitHub releases, verified
# against the release's checksum file. A release landing between the two
# downloads fails the check and is logged, never installed. Steps are chained
# with && (see the top of the file).
(
    HADOLINT_ARCH=$([ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64")
    HADOLINT_BIN="hadolint-linux-${HADOLINT_ARCH}"
    HADOLINT_URL="https://github.com/hadolint/hadolint/releases/latest/download"
    HADOLINT_TMP=$(mktemp -d) || exit 1
    trap 'rm -rf "${HADOLINT_TMP}"' EXIT
    curl -sSfLo "${HADOLINT_TMP}/${HADOLINT_BIN}" "${HADOLINT_URL}/${HADOLINT_BIN}" &&
    curl -sSfLo "${HADOLINT_TMP}/checksums.sha256" "${HADOLINT_URL}/checksums.sha256" &&
    # Exact-match lookup: fails on a missing entry, not only a wrong hash
    awk -v f="${HADOLINT_BIN}" -v d="${HADOLINT_TMP}" \
        '{ sub(/^\*/, "", $2) } $2 == f { print $1 "  " d "/" f; found = 1 } END { exit !found }' \
        "${HADOLINT_TMP}/checksums.sha256" | sha256sum -c - &&
    install -m 0755 "${HADOLINT_TMP}/${HADOLINT_BIN}" /usr/local/bin/hadolint
) || log "warning: hadolint install failed, continuing" &
HADOLINT_PID=$!

# trufflehog: secret scanner, from the latest release's tarball, verified
# against that release's checksum file (its install script is served from
# the repo's main branch, unpinned), and that checksum file against
# trufflehog's keyless cosign signature, requiring the certificate identity
# the user confirmed (as in config-paddock's baseline image). cosign itself
# is checked only against its own release's checksums: an accepted bootstrap
# exception, since verifying cosign needs a cosign already trusted. cosign
# and its Sigstore cache (TUF_ROOT) live in the stage's temp directory, so
# neither outlives the stage. Verifying needs rekor.sigstore.dev and
# tuf-repo-cdn.sigstore.dev; without them trufflehog isn't installed and the
# stage logs its warning. cosign warns that --certificate and --signature
# are deprecated, which is expected while trufflehog publishes no
# .sigstore.json bundle. Steps are chained with && (see the top of the file).
#
# cosign is pinned, unlike this file's other tools, so a release dropping
# those flags can't arrive unannounced and silently stop trufflehog
# installing. Keep COSIGN_TAG at todofixthis/config-paddock's COSIGN_VERSION
# (here with a v prefix: v3.1.3 for 3.1.3), which Renovate bumps and that
# repo's CI tests; bump it here only after that has merged.
(
    ARCH=$(dpkg --print-architecture)
    TRUFFLEHOG_TMP=$(mktemp -d) || exit 1
    trap 'rm -rf "${TRUFFLEHOG_TMP}"' EXIT
    COSIGN_TAG=v3.1.3
    COSIGN_BIN="cosign-linux-${ARCH}" &&
    COSIGN_URL="https://github.com/sigstore/cosign/releases/download/${COSIGN_TAG}" &&
    curl -sSfLo "${TRUFFLEHOG_TMP}/${COSIGN_BIN}" "${COSIGN_URL}/${COSIGN_BIN}" &&
    curl -sSfLo "${TRUFFLEHOG_TMP}/cosign_checksums.txt" "${COSIGN_URL}/cosign_checksums.txt" &&
    awk -v f="${COSIGN_BIN}" -v d="${TRUFFLEHOG_TMP}" \
        '{ sub(/^\*/, "", $2) } $2 == f { print $1 "  " d "/" f; found = 1 } END { exit !found }' \
        "${TRUFFLEHOG_TMP}/cosign_checksums.txt" | sha256sum -c - &&
    chmod +x "${TRUFFLEHOG_TMP}/${COSIGN_BIN}" &&
    TRUFFLEHOG_TAG=$(latest_release_tag trufflesecurity/trufflehog) &&
    [ -n "${TRUFFLEHOG_TAG}" ] &&
    TRUFFLEHOG_VERSION="${TRUFFLEHOG_TAG#v}" &&
    TRUFFLEHOG_TARBALL="trufflehog_${TRUFFLEHOG_VERSION}_linux_${ARCH}.tar.gz" &&
    TRUFFLEHOG_URL="https://github.com/trufflesecurity/trufflehog/releases/download/${TRUFFLEHOG_TAG}" &&
    curl -sSfLo "${TRUFFLEHOG_TMP}/${TRUFFLEHOG_TARBALL}" "${TRUFFLEHOG_URL}/${TRUFFLEHOG_TARBALL}" &&
    curl -sSfLo "${TRUFFLEHOG_TMP}/checksums.txt" "${TRUFFLEHOG_URL}/trufflehog_${TRUFFLEHOG_VERSION}_checksums.txt" &&
    curl -sSfLo "${TRUFFLEHOG_TMP}/checksums.txt.sig" "${TRUFFLEHOG_URL}/trufflehog_${TRUFFLEHOG_VERSION}_checksums.txt.sig" &&
    curl -sSfLo "${TRUFFLEHOG_TMP}/checksums.txt.pem" "${TRUFFLEHOG_URL}/trufflehog_${TRUFFLEHOG_VERSION}_checksums.txt.pem" &&
    TUF_ROOT="${TRUFFLEHOG_TMP}/sigstore" timeout 120 "${TRUFFLEHOG_TMP}/${COSIGN_BIN}" verify-blob \
        --certificate "${TRUFFLEHOG_TMP}/checksums.txt.pem" \
        --signature "${TRUFFLEHOG_TMP}/checksums.txt.sig" \
        --certificate-identity "https://github.com/trufflesecurity/trufflehog/.github/workflows/release.yml@refs/tags/${TRUFFLEHOG_TAG}" \
        --certificate-oidc-issuer https://token.actions.githubusercontent.com \
        "${TRUFFLEHOG_TMP}/checksums.txt" &&
    # Exact-match lookup: fails on a missing entry, not only a wrong hash
    awk -v f="${TRUFFLEHOG_TARBALL}" -v d="${TRUFFLEHOG_TMP}" \
        '{ sub(/^\*/, "", $2) } $2 == f { print $1 "  " d "/" f; found = 1 } END { exit !found }' \
        "${TRUFFLEHOG_TMP}/checksums.txt" | sha256sum -c - &&
    tar -xzf "${TRUFFLEHOG_TMP}/${TRUFFLEHOG_TARBALL}" -C "${TRUFFLEHOG_TMP}" trufflehog &&
    install -m 0755 "${TRUFFLEHOG_TMP}/trufflehog" /usr/local/bin/trufflehog
) || log "warning: trufflehog install failed, continuing" &
TRUFFLEHOG_PID=$!

# uv is already pre-installed in cloud sessions, but the snapshot can lag
# upstream releases enough to warn on directives (e.g. `system-certs`) that
# newer uv versions renamed or reinterpreted. `uv self update` needs GitHub's
# release API, which this platform's own session proxy can deny even though
# the rest of this script's GitHub traffic goes through fine — fall back to
# PyPI (confirmed always reachable) and copy the fresh binary over the
# pre-installed one so PATH keeps resolving to the update, not the original.
# Update before adding the extra Python versions and semgrep on top — each
# step logged separately so a failure in one doesn't get lost in, or masked
# by, the others.
(
    UV_BIN="$(command -v uv || true)"
    if ! uv self update; then
        log "warning: uv self-update failed, falling back to pip install --upgrade uv"
        if pip install --upgrade uv; then
            PIP_UV_BIN="$(python3 -c 'import sysconfig; print(sysconfig.get_path("scripts"))')/uv"
            if [ -n "$UV_BIN" ] && [ -x "$PIP_UV_BIN" ] && [ "$UV_BIN" != "$PIP_UV_BIN" ]; then
                cp "$PIP_UV_BIN" "$UV_BIN"
            fi
        else
            log "warning: pip install --upgrade uv also failed, continuing with pre-installed uv"
        fi
    fi
    uv python install 3.12 3.13 3.14 || log "warning: uv python install failed, continuing"
    uv tool install --python 3.13 semgrep || log "warning: uv tool install semgrep failed, continuing"
) &
UV_PID=$!

wait "$APT_PID" "$LEFTHOOK_PID" "$HADOLINT_PID" "$TRUFFLEHOG_PID" "$UV_PID"
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

    if ! timeout 300 git clone --depth 1 --quiet "$repo_url" "$tmp"; then
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
