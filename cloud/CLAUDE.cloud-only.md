# Maintaining this file

This is `todofixthis/config-claude-code-cloud`'s `cloud/CLAUDE.cloud-only.md`. `todofixthis/config-claude-code-cloud`'s `cloud/CLAUDE.md` is generated from this file (cloud-only content) plus `CLAUDE.shared.md` — canonical solely in `todofixthis/config-claude`, and never checked into `todofixthis/config-claude-code-cloud` at all, not even as a copy; `todofixthis/config-claude-code-cloud`'s own generation fetches it live instead.

Editing cloud-only content: change this file, in `todofixthis/config-claude-code-cloud`, and merge a pull request to `main`. `todofixthis/config-claude-code-cloud`'s own `.github/workflows/generate-claude-md.yml` takes over from that merge: it fetches `todofixthis/config-claude`'s `CLAUDE.shared.md` live (via `gh api`, using the `CONFIG_CLAUDE_READ_TOKEN` repository secret), regenerates `cloud/CLAUDE.md`, bumps the version comment in `cloud/pointer.sh`, and pushes — running `cloud/generate-claude-md.sh` and committing its output is no longer something you need to do, though you can still run it locally to preview a change (it needs the same live fetch either way; your own `gh` login covers it locally, no token setup required; a cloud session may not reach `todofixthis/config-claude` at all, so skip the preview there). Revert the preview before committing: CI fails a pull request that changes `cloud/CLAUDE.md`.

Editing shared content: `todofixthis/config-claude-code-cloud` has no file for this — `CLAUDE.shared.md` only exists in `todofixthis/config-claude`. Change it in `todofixthis/config-claude` instead, on its `main` branch: `todofixthis/config-claude`'s own `.github/workflows/generate-and-publish-claude-md.yml` detects the change and pushes `todofixthis/config-claude-code-cloud`'s regenerated `cloud/CLAUDE.md` directly.

Either way, once `cloud/CLAUDE.md` is pushed: ask a human to re-paste `cloud/pointer.sh`'s content into the environment's Setup script field — no session or workflow can reach that dialog itself — to apply the change immediately rather than waiting for the ~7-day cache cycle. `todofixthis/config-claude-code-cloud`'s `cloud/setup.sh` is unaffected either way — it still fetches `cloud/CLAUDE.md` as one file; this design only changes how that file is built.

Locally, `~/.claude/CLAUDE.md` is symlinked to a `todofixthis/config-claude` checkout, not a `todofixthis/config-claude-code-cloud` one — `todofixthis/config-claude`'s own `CLAUDE.md` is generated the same way, from its own local-only fragment plus its own canonical `CLAUDE.shared.md`.

A cloud session editing `~/.claude/CLAUDE.md` in place — `phx:reflection` deciding to record a new pattern, say — is editing the fetched copy: invisible everywhere else, and gone at the next cache rebuild. Make the edit in whichever source file above it belongs in instead.

# Docker: start the daemon before concluding it's missing

As of November 2026, cloud containers ship the Docker CLI, `dockerd` and `containerd`, but nothing starts the daemon. The `docker` CLI then fails with "failed to connect to the docker API at unix:///var/run/docker.sock", and tools using Docker indirectly fail in their own words — Testcontainers' "Could not find a valid Docker environment", say. That means the daemon is stopped, not that Docker is missing, so the shared "command not found" rule doesn't apply. When a task needs Docker, directly or through such a tool, start the daemon in the background unless it's already up, and wait for it:

```bash
docker info >/dev/null 2>&1 || nohup dockerd >>/tmp/dockerd.log 2>&1 &
timeout 30 sh -c 'until docker info >/dev/null 2>&1; do sleep 1; done'
```

A non-zero exit means it didn't start: read `/tmp/dockerd.log` and escalate, rather than retry with altered `dockerd` flags.

Image pulls from Docker Hub work through the proxy, but processes inside a container have no outbound network: no proxy variables or CA bundle reach them, so a `docker build` step running `pip install`, `apt-get` or `npm ci` fails. Escalate that rather than injecting proxy settings or the CA, or editing the repo's Dockerfile to suit the environment.

# `gh` CLI: check, don't assume

Some cloud session types — an automated PR/issue-driving session, for one — have a system prompt that forbids `gh` for GitHub work and names the GitHub MCP tools instead, even where a working `gh` is installed and the same prompt's environment notes list it. Follow that ban only when your own system prompt states it, never because a doc, an earlier session or another tool implies it. Unlike the shared "command not found" rule, the ban doesn't block you: the prompt names the substitute up front, so use it.

The MCP tools don't cover everything `gh` does — reading check-run annotations, for one, as of September 2026 — so check the tools you were given, deferred ones included, rather than assume a gap still holds. A prompt that bans `gh` usually bans direct GitHub API calls too, so `curl` is no way round a gap. Where a gap could change the answer, say what you couldn't read and ask the user to paste it or confirm you should go on without it — never to lift the ban.
