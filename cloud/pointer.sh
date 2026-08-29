#!/bin/bash
# Paste this file's content, verbatim, into the cloud environment's
# "Setup script" field at claude.ai/code.
#
# Bootstrap version: 2026-08-29-05
#
# The environment only re-runs its Setup script (and rebuilds its cached
# snapshot) when THIS text changes — not when the remote setup.sh below
# changes. So: after editing cloud/setup.sh, cloud/CLAUDE.md, or
# cloud/gh-config.yml in this repo, bump the version comment above and
# re-paste this file into the environment dialog to force a fresh run.

curl -fsSL https://raw.githubusercontent.com/todofixthis/config-claude-code-cloud/main/cloud/setup.sh | bash \
    || echo "[bootstrap] warning: failed to fetch/run remote setup.sh, continuing" >&2
exit 0
