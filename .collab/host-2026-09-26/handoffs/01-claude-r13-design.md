# R13 - host invariance: the same bridge from a Codex-first (or any) coordinator (design for review, wave 26)

Goal (ROADMAP R13): the bridge scripts already run from any coordinator; what is Claude-Code-
specific is the packaging and the wording. R13 makes the host a parameter so a Codex CLI (or
Cursor, or a shell) coordinator installs and uses the same bridge from the README alone.

## Code facts

- The two skills (`skills/consult-codex/SKILL.md`, `skills/setup-providers/SKILL.md`) refer to
  the scripts through `${CLAUDE_PLUGIN_ROOT}` (set by Claude Code for an installed plugin).
- `hooks/hooks.json` (SessionStart) runs `codex-consult-hook.ps1`; `.claude-plugin/plugin.json`
  and the marketplace manifest are Claude Code packaging; `evals/` is `claude plugin eval`.
- Wording: the README and skills call the coordinator "Claude" in places, the handoff header
  names the judge, the reviewer's lineage is compared with nothing.
- Codex CLI reads `AGENTS.md` and supports skills in `~/.codex/skills/<name>/SKILL.md` (Agent
  Skills format - the same front matter our SKILL.md files use).

## Design

1. One root variable: the skills reference `$CODEX_CONSULT_ROOT`, resolved as (a) the env var
   when set, (b) `${CLAUDE_PLUGIN_ROOT}` when set (Claude Code), (c) the directory of the
   SKILL.md's plugin (`<skill dir>/../..`) as the documented fallback, spelled out once at the
   top of each skill. All script invocations in the skills use it.
2. Host-neutral wording: "the coordinator" / "the judge" instead of "Claude"; the README's
   install section gets three tabs: Claude Code (plugin, unchanged), Codex CLI (copy or symlink
   the two skills into `~/.codex/skills/`, add the availability one-liner and the consult rule to
   `AGENTS.md`, set `CODEX_CONSULT_ROOT`), any shell (the scripts directly). A `install/` folder
   with `AGENTS.snippet.md` and an `install-codex-host.ps1` that copies the skills and prints the
   AGENTS.md snippet (idempotent; no other side effects).
3. Coordinator identity: `CODEX_CONSULT_COORDINATOR=<provider> :: <model>` (optional); when a
   picked reviewer's lineage equals it, the run warns "the reviewer is the coordinator's own
   model - a second opinion from the same model" (not refused). The ledger records
   `coordinator` when set.
4. The SessionStart availability line for hosts without hooks: documented one-liner
   `powershell -NoProfile -File <root>/scripts/codex-consult-hook.ps1` the coordinator runs at
   session start (already works; documented for the Codex host, added to the AGENTS snippet).
5. Non-goals kept: no second packaging format, no rename of the plugin and marketplace ids (the
   C3 rename is the 1.0.0 change), `claude plugin eval` stays.

## Verification

A fresh Codex CLI session as the coordinator, from the README alone: `codex exec` with a prompt
"install the bridge for this host and run one checkpoint consultation with reviewer kimi ::
k3 on task r13-host" in a scratch clone; the ledger entry and handoff prove it. Harness: the
skills contain no `${CLAUDE_PLUGIN_ROOT}` except in the resolution line; `install-codex-host.ps1`
is idempotent and copies exactly the two skills; the coordinator warning.

## Questions for the reviewers

Q1. Is a plain copy of the two SKILL.md files into `~/.codex/skills/` the right Codex-side
    install, or should the bridge ship an AGENTS.md-only recipe (no skills) as the minimum?
Q2. Any wording or behaviour in the scripts themselves (not the docs) that assumes Claude Code
    is the host?
Q3. Should the coordinator identity be inferred (e.g. from `CLAUDECODE`/`CODEX_*` env markers)
    instead of a variable the user sets?

## R19 addendum (2026-09-27) - the coordinator's manual ships with the bridge

Why: the rules a coordinator needs to run consultations well live today in one operator's
private CLAUDE.md (a "supervisor / worker delegation" block) and in the operator's head; other
installs get the bridge without them. Seen the same day in another repository: a coordinator
wrote `state.md` while a muse member ran (the member was recorded failed), briefs drifted from
the language rule, a slow member held a panel for its whole budget with nobody knowing what to
do. A plugin cannot ship a CLAUDE.md (Claude Code does not load one from a plugin root), so:

6. A `coordinate` skill (host-neutral, English) with the coordinator's rules: waves and briefs
   (one objective per worker, the exact files and context, reference counts); a fresh worker per
   wave with its state on disk (a STATE.md, logs in files, the CHANGELOG entry as the report) so
   a worker never resumes a full context; non-blocking waits (`-Detach` for panels, background
   runs, a watchdog wake shorter than the prompt-cache TTL that reads the worker's state file
   and messages or `-Kick`s it - never a keep-alive turn for its own sake); context hygiene (the
   auto-compaction threshold, compaction at wave boundaries); never redoing a worker's work;
   the language rule (everything sent to reviewers in English, the operator's language only in
   the conversation, source material translated); the live-member rule (nothing written under
   the collab directory or the working tree, no git command, while an agy or muse member runs);
   rating every consultation; asking the operator before going on without a required reviewer.
7. Worker agent definitions in the plugin's `agents/` (an opus-tier, a sonnet-tier and a
   haiku-tier worker, named by tier with the model set by the host's names) for the Claude Code
   host; `install-codex-host.ps1` writes the Codex counterparts when that host supports agent
   files, else the AGENTS snippet describes the tiers in prose.
8. The SessionStart hook prints one pointer line beside the availability line
   (`codex-consult: coordinator rules - skill codex-consult:coordinate`); nothing else is added
   to every session.
9. The operator's private CLAUDE.md shrinks to a pointer (the migration is documented in the
   README's "For the coordinator" section; the plugin never edits a CLAUDE.md).

Q4. One skill `coordinate`, or a section inside `consult-codex` (listing cost per session vs
    the rule being found when a coordinator delegates without consulting)?
Q5. Which rules are Claude-Code-specific (subagents, scheduled wakes, compaction) and how should
    the skill phrase them so a Codex CLI coordinator gets the same discipline with its own means?
Q6. Should agent definitions ship at all (model names change faster than releases), or should
    the skill describe the tiers and leave the mapping to the host?
