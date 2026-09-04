#!/bin/bash
# Regenerates cloud/CLAUDE.md from cloud/CLAUDE.cloud-only.md and
# cloud/CLAUDE.shared.md — see cloud/CLAUDE.cloud-only.md for what goes in
# which source file.

set -euo pipefail
cd "$(dirname "$0")"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

{
    echo "<!-- GENERATED FILE — do not edit directly. Edit cloud/CLAUDE.cloud-only.md and/or cloud/CLAUDE.shared.md, then re-run cloud/generate-claude-md.sh. -->"
    echo
    cat CLAUDE.cloud-only.md
    echo
    cat CLAUDE.shared.md
} > "$tmp"

mv "$tmp" CLAUDE.md
echo "cloud/CLAUDE.md regenerated"
