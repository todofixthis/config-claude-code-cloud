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
