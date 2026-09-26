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
