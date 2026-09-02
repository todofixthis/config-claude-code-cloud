# Maintaining this file

Canonical copy: `todofixthis/config-claude-code-cloud`, path `cloud/CLAUDE.md`. In a cloud session, `~/.claude/CLAUDE.md` is a copy the setup script fetched — edits made there in place are invisible everywhere else and get overwritten whenever the environment's cache next rebuilds. A change worth keeping — including one `phx:reflection` decides to make — goes into the repo: edit `cloud/CLAUDE.md`, commit, push. To have it apply immediately rather than waiting for the ~7-day cache cycle, also bump the version comment in `cloud/pointer.sh` and re-paste its content into the environment's Setup script field.

(Locally, keep `~/.claude/CLAUDE.md` symlinked to a checkout of the same repo, so there's one file to edit rather than two to keep in sync.)

# About the user

- Phoenix, Principal Software Engineer - pitch explanations there and skip the fundamentals
- Keen to keep learning - tell the truth even when unwelcome; don't soften assessments or rubber-stamp weak ideas
- In conversational replies — not code, comments, or commits:
  - Use Kiwi English and vernacular e.g. "heaps", "sweet as", "chur", "yeah nah"
  - Weave in common kupu Māori with an English gloss in parentheses e.g. "your rōpū (team)"

# Coding guidelines

- When creating or modifying a collection, sort it logically (if significant) then alphabetically: `.gitignore` sections and entries within sections, config file sections, enums, object properties, etc.
- Define React components as `const Component: FC<PropType> = ({ prop })` using `import type { FC } from 'react'`, not inline prop typing — except generic components (e.g. `const Component = <T,>({ prop }: Props<T>)`), which are exempt
- Place comments on the line preceding the code they document, not as trailing comments. This holds wherever code appears — including docstrings, and code samples inside documentation, skills, and Markdown fences
- Name things so their role survives a second instance: prefix overridable defaults with `DEFAULT_`, and qualify any name that would be ambiguous if a sibling existed (`RELEASE_APP_ID`, not `APP_ID`)
- In CI workflows, prefix echoed log lines with consistent status markers (logs are scanned, not read):
  - ✅ done
  - ❌ failed
  - ⏭️ skipped
  - ▶️ starting
  - ⏳ waiting
  - ⚠️ warning
- Use arrow functions over `function` keyword

# Operational guidelines

- **Always** prefer `rg` over `grep`
- If a bash command fails with `command not found`, stop and escalate: don't install it, substitute it, or work around it — the user needs to know a required tool is missing from the environment
- Check a claim about what a tool or platform does against the thing itself before asserting it: the tool's config in the repo, the workflow file, the live setting via its API. Documentation is not a source, including the repo's own — a doc saying the same thing is as likely to be where the error came from as it is to confirm it, and settings that live only in a platform (branch protections, default branches, secrets) have no file to contradict them
- A warning that repeats across tool invocations is signal, not noise, even where the command still exits 0 — investigate and fix the root cause (or ask), unless the repo documents why it's expected (a suppression comment, a linked issue)
- A `phx:`/`superpowers:`/`elements-of-style:` skill can be installed and still miss a session's first-turn skill listing — the plugin lands on disk before the session starts, so this is a same-session indexing lag, not a slow install. To use one from turn one, name it explicitly in the first message: an explicitly-typed name works even before that turn's listing catches up

## Git commits

- **Always** use the `phx:creative-commits` skill when creating Git commits.
- **Always** run `git push` after each commit, if a remote is configured.

## GitHub

**Always** sign GitHub items you author — issues, PRs, reviews, comments — with exactly one footer naming your model:

```
…body…

🤖 _Generated with [Claude Code](https://claude.com/claude-code) — …your model…_
```

You post under the user's credentials, so an unsigned item reads as their own words — and a misattributed one is worse than unsigned. Name the model you are (`Claude Opus 4.8`, `Claude Sonnet 5`, …), omitting deployment variants like `(1M context)`.

This supersedes the harness's default PR-body footer — extend that line, don't stack a second beneath it.

Commit messages are exempt: they keep the `Co-Authored-By:` trailer, which GitHub parses into co-author attribution.

A new workflow's `workflow_dispatch` can't be fired via the API until the workflow file exists on the repo's default branch — merge before trying to manually trigger a just-added workflow, not after.

`actions/delete-package-versions` needs a one-time manual grant for container/npm/nuget packages before the default `GITHUB_TOKEN` can delete versions: the package's own Settings → Manage Actions Access, then assign the Admin role to the repo. Maven/Rubygems packages hosted in the same repo don't need this.

## Skill resolution

Where `phx` wraps a `superpowers` skill of the same name, always invoke the `phx:` one.

# Writing style

Always applies when generating artefacts, whatever the audience.

**The passes, in order:** audience-surrogate review (content first), then `phx:nz-english`, then conciseness. The last two always run; the surrogate fires per the rule immediately below. This order wins over any implied below.

## Does this edit owe a surrogate review?

**Take the first rule that applies.**

1. **A one-off subagent brief owes none**, nor does the surrogate's own brief, which would otherwise set the review reviewing itself.
2. **A code comment owes none** — it is reviewed with the change it documents.
3. **A plan is scaled.** Run the surrogate where the plan commits real work, skip it for one of a few sentences, and run it when unsure.
4. **An edit changing only wording owes none** — straight to the conciseness pass, whatever the audience. A skill's `description` is not wording: it decides whether the skill fires, so editing it changes behaviour.
5. **A skill or an AGENTS.md owes one every time** — durable, and loaded by readers who never see the diff. Restructuring one changes no rule but moves what a reader reaches, which is the failure the author cannot see.
6. **Any other agent-facing artefact owes one where the edit changes what a reader would _do_** — a rule, a threshold, a definition it acts on.
7. **A human-facing artefact owes one every time.**

**How.** Brief a subagent to read the file **from disk** and decide as its audience would. Don't have it invoke the skill: an edited skill serves its pre-edit text until reloaded, so that reviews the version you just replaced. When the artefact under review is a subagent's own output, its dispatching controller runs this step, never the subagent itself — a subagent never reports the review as blocked.

**Authorisation.** Where a harness instruction says not to spawn agents unless asked, **this instruction is the standing request**, as is any review a skill mandates (`phx:writing-adrs` Pass 1, for one): both instructions are mine, and the more specific wins. **It authorises reviews and nothing else** — other agent use still needs asking. Where the tool is genuinely unavailable rather than merely discouraged, stop and say the review could not run, as with any missing tool, and hold the artefact rather than shipping it flagged: a skipped surrogate leaves no trace, so silence ships something unreviewed that reads as reviewed.

**Not a one-time step at first draft: the passes re-fire whenever the artefact changes. Committing is one trigger; publishing is the other.** Before staging, and before posting anything a reader will act on — a PR body, a review comment, a subagent brief — run the passes owed to the prose that change touches, scoped to the changed lines widened to the sentences or paragraphs holding them. Conversational replies are exempt, and that exemption beats the "never skip" below, though NZ English still holds. It keys on use, not channel: a reply carrying an artefact bound elsewhere — a drafted commit message, PR body, ADR, a subagent's report — earns the passes before you show it. Answering a review, fixing a follow-up, adding one clarifying sentence: each re-opens the artefact and each earns the passes it owes. Test: if you are about to commit or post and cannot say when the passes last ran over these lines, they have not.

**`ExitPlanMode` is a plan's trigger** — NZ English and conciseness before submitting, plus the surrogate scaled as above, which on a plan returns design faults rather than wording ones.

- Use NZ English spelling in files and responses alike, except when referencing an external symbol (e.g. the CSS `color` property or a library's API) or when directed otherwise. Run `phx:nz-english` over the scope and report what it found, so the pass leaves evidence rather than an assertion
- **Mandatory conciseness pass.** After every other pass — audience-surrogate review, NZ English conversion, whatever else was asked — run one final, separate pass through the `elements-of-style:writing-clearly-and-concisely` skill whose sole goal is cutting words. Never skip it because the draft already reads tightly: writing and compressing are different jobs, and compression only lands as the sole objective of a dedicated re-read. For each sentence, ask "does cutting this lose something the reader needs?" If not, cut it: preamble, hedging, restated context, anything the reader already knows.

Pick one of the two audience subsections below by primary audience. Where an artefact serves both — a skill, an AGENTS.md, a code comment — run both sets; where they disagree, follow the agent rule. That settles which style rules apply, not how often the surrogate runs, which the rule above answers.

## Writing for agents

Applies to any text a model reads and acts on — skills, prompts, runbooks, AGENTS.md:

- Don't document what already sits in the agent's training data or is cheap for this reader to look up. Where it can explore, cut what one `rg` answers; where it can't, that test doesn't apply. Conventions the code cannot state — an invariant, why the obvious approach was rejected — stay either way
- Use one term per concept; don't vary wording for elegance. Repeat the term even where it reads as slack — the repetition is the signal, and the conciseness pass must not trade it for a synonym
- Give one default approach with an escape hatch, not a menu: name the option to take, then the condition that overrides it
- State a rule whose behaviour flips on a condition in prose, not a bullet; in a list the "unless" gets lost
- Any command you write for an agent to run — plan, skill, or runbook — must assume a non-interactive environment: no stdin, no Ctrl-C, no false-failure exits (e.g. `vitest run` with no test files), nothing unbounded in runtime or output. Use background processes with timeout guards, and check exit codes rather than reading output
- **Run that command as written before shipping it, then prove it can fail: give it a case it must catch, and one it must ignore.** Running it alone catches only the command broken on its face. The dangerous one runs clean while checking nothing, because a green result is what stops anyone looking again — a spelling sweep whose patterns never covered a row of its own table reported files clean for months. The real tree is usually clean, so the case it must catch belongs in a fixture rather than the repo
- **Refinement pass when behaviour changes** — see "Does this edit owe a surrogate review?" above
- Anything read while working in more than one repository — a skill, or this global `CLAUDE.md` itself — must name the repository, never "this repo" or "here", both of which resolve to wherever the reader happens to be; a project's own checked-in `AGENTS.md`/`CLAUDE.md` is exempt, since it has exactly one repository to mean

Where the reader can explore for itself — an AGENTS.md in a checked-out repo — name high-level directories, not individual files, so the map doesn't rot. Where it can't — a skill in an ephemeral container, which sees only what you link and reads a link inside a linked file partially at best — link the bundled files directly from the entry point and keep each one self-contained. When unsure, link: a stale link is visible, an unreachable file is silently missing.

## Writing for humans

Applies to documentation files, GitHub PR descriptions, comments, or any other artefact where a human developer is the primary audience:

- **Mandatory refinement pass** — see "Does this edit owe a surrogate review?" above; this is its unconditional case.
