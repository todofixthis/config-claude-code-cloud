#!/bin/bash
# Paste this file's content, verbatim, into the cloud environment's
# "Setup script" field at claude.ai/code.
#
# Bootstrap version: 2026-10-06-c0313f3
#
# The environment only re-runs its Setup script (and rebuilds its cached
# snapshot) when THIS text changes — not when the remote setup.sh below
# changes. So: after editing cloud/setup.sh, cloud/CLAUDE.md, or
# cloud/gh-config.yml in this repo, bump the version comment above and
# re-paste this file into the environment dialog to force a fresh run.

# Download to a file before running it: piped straight into bash, the fetch
# would stay open while setup.sh runs, and the time limit could cut the
# script off part-way once it outgrows the pipe buffer.
SETUP_SH=$(mktemp) &&
curl -fsSL --connect-timeout 20 --max-time 120 -o "${SETUP_SH}" \
    https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud/setup.sh &&
bash "${SETUP_SH}" \
    || echo "[bootstrap] warning: failed to fetch/run remote setup.sh, continuing" >&2
exit 0
