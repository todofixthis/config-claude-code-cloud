# Maintaining this file

This is `todofixthis/config-claude-code-cloud`'s `cloud/CLAUDE.cloud-only.md`. `todofixthis/config-claude-code-cloud`'s `cloud/CLAUDE.md` is generated from this file (cloud-only content) plus `CLAUDE.shared.md` — canonical solely in `todofixthis/config-claude`, and never checked into `todofixthis/config-claude-code-cloud` at all, not even as a copy; `todofixthis/config-claude-code-cloud`'s own generation fetches it live instead.

Editing cloud-only content: change this file, in `todofixthis/config-claude-code-cloud`, commit, and push to `main`. `todofixthis/config-claude-code-cloud`'s own `.github/workflows/generate-claude-md.yml` takes over from that push: it fetches `todofixthis/config-claude`'s `CLAUDE.shared.md` live (via `gh api`, using the `CONFIG_CLAUDE_READ_TOKEN` repository secret), regenerates `cloud/CLAUDE.md`, bumps the version comment in `cloud/pointer.sh`, and pushes — running `cloud/generate-claude-md.sh` and committing its output is no longer something you need to do, though you can still run it locally to preview a change before pushing (it needs the same live fetch either way; your own `gh` login covers it locally, no token setup required).

Editing shared content: `todofixthis/config-claude-code-cloud` has no file for this — `CLAUDE.shared.md` only exists in `todofixthis/config-claude`. Change it in `todofixthis/config-claude` instead, on its `main` branch: `todofixthis/config-claude`'s own `.github/workflows/generate-and-publish-claude-md.yml` detects the change and pushes `todofixthis/config-claude-code-cloud`'s regenerated `cloud/CLAUDE.md` directly.

Either way, once `cloud/CLAUDE.md` is pushed: ask a human to re-paste `cloud/pointer.sh`'s content into the environment's Setup script field — no session or workflow can reach that dialog itself — to apply the change immediately rather than waiting for the ~7-day cache cycle. `todofixthis/config-claude-code-cloud`'s `cloud/setup.sh` is unaffected either way — it still fetches `cloud/CLAUDE.md` as one file; this design only changes how that file is built.

Locally, `~/.claude/CLAUDE.md` is symlinked to a `todofixthis/config-claude` checkout, not a `todofixthis/config-claude-code-cloud` one — `todofixthis/config-claude`'s own `CLAUDE.md` is generated the same way, from its own local-only fragment plus its own canonical `CLAUDE.shared.md`.

A cloud session editing `~/.claude/CLAUDE.md` in place — `phx:reflection` deciding to record a new pattern, say — is editing the fetched copy: invisible everywhere else, and gone at the next cache rebuild. Make the edit in whichever source file above it belongs in instead.

# `gh` CLI: check, don't assume

Some cloud session types — an automated PR/issue-driving session, for one — have a system prompt that forbids `gh` for GitHub work and names the GitHub MCP tools instead, even where a working `gh` is installed and the same prompt's environment notes list it. Follow that ban only when your own system prompt states it, never because a doc, an earlier session or another tool implies it. Unlike the shared "command not found" rule, the ban doesn't block you: the prompt names the substitute up front, so use it.

The MCP tools don't cover everything `gh` does — reading check-run annotations, for one, as of September 2026 — so check the tools you were given, deferred ones included, rather than assume a gap still holds. A prompt that bans `gh` usually bans direct GitHub API calls too, so `curl` is no way round a gap. Where a gap could change the answer, say what you couldn't read and ask the user to paste it or confirm you should go on without it — never to lift the ban.
