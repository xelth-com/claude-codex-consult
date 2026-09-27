# Handoff 02 - Codex: reply-kimi

Date: 2026-09-27 23:18 local. Author: Codex (model k3, effort high), Codex CLI 0.155.1.
Reviewer: kimi :: k3 (provider from roster, model from roster; endpoint https://api.kimi.ai/coding/v1, wire_api: responses; provider fingerprint 8f7901d404b5; harness codex-cli 0.155.1).
Preflight: ok: env KIMI_API_KEY set.
Roster: C:/Users/Dmytro/AppData/Local/Temp/claude/C--Users-Dmytro-claude-codex-consult/2e5096df-2bb2-46b1-8e0e-f97f37eaab90/scratchpad/roster-companions-design.json - position 2 of 3, panel cdc84a42 member 1 of 3.
Effort: high sent (requested high, mapping kimi-v1, by caps-v1: api.kimi.ai, k3; not confirmed by the provider). Consultation id: 40e1149f-fa64-4e57-8d81-d451d8953ad9.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m k3 -c model_reasoning_effort="high" -c model_provider="kimi" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-275a80ae134c4eaca7c3d55a4edd9873.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0e4bc-0cb5-7fd1-8057-0f6b2caa1ab2` (source: events).
Brief: `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md` (sha256 6862934c8caa). Reviewed: 3360cb9 + uncommitted, base 3360cb9c85daaf2d8e75c52393791a307e9f7999, tree sha256 d18c2bb48637, 1 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 317.5 s. Tokens: in 381393 (cached 279040), out 6345, reasoning 2768.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The design is sound but the root-variable resolution mechanism silently breaks in exactly the Codex install path it is meant to enable, and copy staleness plus coordinator-env inference are unaddressed. Findings: 0 blocker, 1 major, 1 minor, 2 note (F02-1..F02-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/02-codex-reply-kimi.reply.json`.
Raw event stream: `handoffs/02-codex-reply-kimi.events.jsonl`.
Verbatim reply follows.

---

## Framing first

The brief frames install as "copy skills + set a variable", but it never lists the strongest alternative: **bake at install**. `install-codex-host.ps1` can rewrite the copied skills' root line to the absolute plugin path, making runtime resolution (a)/(b)/(c) unnecessary on the Codex host and turning finding #1 into a non-issue. A second unlisted option: ship the coordinator rules as `codex-consult.ps1 -Explain coordinate` output too, so skill-less hosts (plain shell) still get R19's manual. A third: treat the AGENTS.md-only recipe as the guaranteed floor and skills as enhancement, since skill triggering depends on description matching while AGENTS.md is always read.

To choose between copy/symlink/bake I'd need to know: does Codex CLI follow symlinks for skills on Windows (admin-mode problem), does it hot-reload `~/.codex/skills` or require restart, and are target users single-host (drift cost low) or multi-host (one source of truth matters)?

## Q1 - Copy vs AGENTS-only
Copy is right as the primary install (skills carry structure AGENTS.md prose cannot), but only with two guards the brief lacks: (1) the copy must be version-stamped and the availability line should warn on script/skill version mismatch, otherwise plugin updates silently desync Codex installs; (2) the fallback resolution (c) `<skill dir>/../..` must not be relied on for copies (finding #1). Keep the AGENTS.md-only recipe as the documented minimal floor for hosts that cannot load skills.

## Q2 - Script-side host assumptions
The scripts are clean. No `CLAUDE_PLUGIN_ROOT` or Claude env reads exist in `plugins/codex-consult/scripts/*.ps1`; handoff files are named `NN-<engine>-<slug>` by the *reviewer's* engine (codex-consult.ps1:126,336), which is host-neutral. What remains is wording, not behavior: the synopsis "Consult OpenAI Codex from Claude Code" (codex-consult.ps1:3), the hook header comment (codex-consult-hook.ps1:6-7), examples naming briefs `NN-claude-<slug>` (codex-consult.ps1:416-436; consult-codex/SKILL.md:104), and consult-codex/SKILL.md:364 ("Claude (this coordinator)"). The harness grep "no `${CLAUDE_PLUGIN_ROOT}` except the resolution line" should also grep for the `NN-claude-` example prefix or wording fixes will be incomplete.

## Q3 - Infer coordinator identity?
Keep the explicit variable. Inference from `CLAUDECODE`/`CODEX_*` markers is fragile for three reasons: (a) the bridge launches `codex exec` children - inherited env markers would make a *reviewer run* mis-identify itself as the coordinator; (b) the coordinator is often not one model (main session vs subagents, mid-session model switches), so a marker gives host, not lineage; (c) lineage comparison needs normalization rules (engine suffix, aliases) the brief doesn't spec. Middle option worth adding: when the var is unset, record the *inferred host* in the ledger as a hint, but never auto-warn on lineage equality from inference alone. Feasibility of Codex-side markers is unproven - see RC2.

## Q4 - Separate `coordinate` skill
Separate skill. The trigger context is delegation, not consulting; a section inside `consult-codex` only surfaces when a consultation is already contemplated - precisely the failure mode the addendum describes (state.md written while a muse member ran). Listing cost is one frontmatter line per session. Keep it lean and cross-link from `consult-codex`; also expose the same text via a script flag so skill-less shell hosts get it.

## Q5 - Claude-specific rules and phrasing
Claude-specific: subagent tiers (Task tool), scheduled wakes (cron/scheduled tasks), the auto-compaction threshold, and the prompt-cache-TTL watchdog interval (cache economics differ per host). Host-neutral invariants to phrase as the rule: state-on-disk per wave, poll-the-state-file instead of blocking waits, no writes under the collab dir while an agy/muse member runs, English to reviewers, rate every consultation. Then per-host appendices map means: Claude (scheduled task wake), Codex CLI (background shell job / `codex exec` resume), shell (cron). Phrase the TTL rule as "wake interval shorter than your host's prompt-cache TTL".

## Q6 - Ship agent definitions?
Ship Claude Code agent files using tier aliases (`opus`/`sonnet`/`haiku`), which are stable aliases, not versioned model names - the "names change faster than releases" argument applies to pinned versions, not aliases. Do not ship Codex agent files until Codex's agent-file format is confirmed (unproven); the AGENTS snippet describing tiers in prose is the right interim. So: agents/ for Claude, prose for Codex, exactly as design #7's fallback says - but make prose the default and agent files the Claude-only bonus.

## Requested checks
- RC1 (finding #1): copy `plugins/codex-consult/skills/consult-codex` to `%TEMP%\x\skills\consult-codex`, unset `CODEX_CONSULT_ROOT` and `CLAUDE_PLUGIN_ROOT`, resolve `<skill dir>/../..` and test whether `scripts/codex-consult.ps1` exists there. cwd: repo root; workspace-write (temp only); observation: fallback points at a non-plugin dir and fails silently vs loudly; budget 10 min.
- RC2 (Q3): inside a `codex exec` session, run a prompt that prints its environment (`Get-ChildItem env:` filtered to `CODEX|CLAUDE`) and compare with the parent shell's. cwd: scratch clone; read-only; observation: which Codex-set markers exist and whether children inherit them; budget 15 min.

---

### Findings

- **F02-1** [major] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md` - Root resolution fallback (c) '<skill dir>/../..' silently resolves to the wrong directory for the exact Codex install path the design creates: skills copied into ~/.codex/skills/<name>/ have ../.. = ~/.codex, not the plugin, so every script path built from it fails with a confusing not-found instead of a diagnostic. Trigger: Codex CLI host installs via the documented copy recipe without setting CODEX_CONSULT_ROOT (or the var is lost in a new shell), then invokes any script per the skill. Evidence: read-code: Fallback (c) documented as '<skill dir>/../..' with no validation that the resolved root contains scripts/.; read-code: Every script invocation builds its path from the plugin root variable; a wrong root breaks all of them.; inferred: Two levels up from the skill dir is ~/.codex, never the plugin directory. Verify: Run RC1: copy the skill to a temp two-level-deep location with no env vars set and observe what root resolution (c) yields and whether any existence check fires. Remedy: Have install-codex-host.ps1 rewrite the copied skills' root line to the absolute plugin path (bake at install); additionally the skills should mandate validating that $CODEX_CONSULT_ROOT/scripts/codex-consult.ps1 exists and printing the fix when it does not.
- **F02-2** [minor] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md` - 'Resolved once at the top of each skill' has no enforcement mechanism: SKILL.md is prose, so the host model must substitute the variable correctly on every one of the ~10 embedded invocations, and nothing detects a missed substitution. Trigger: A coordinator model paraphrases or partially substitutes the variable in one of the skill's many command lines. Evidence: read-code: At least eight separate command lines embed ${CLAUDE_PLUGIN_ROOT}; each is a substitution site. Verify: After a dry-run Codex-host session, grep the session transcript for any literal '$CODEX_CONSULT_ROOT' reaching a shell. Remedy: Bake the absolute path into copied skills at install time so no runtime substitution exists; extend the harness grep to the copied skills.
- **F02-3** [note] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md` - Copied skills drift from plugin updates: nothing stamps a version or warns when the copy and the plugin's scripts disagree, so a Codex host silently runs stale instructions against newer scripts. Trigger: Plugin upgraded via Claude Code marketplace while the Codex-side copies in ~/.codex/skills/ are not refreshed. Evidence: read-code: install-codex-host.ps1 specified as idempotent copy with no version stamp or mismatch check. Verify: Bump the plugin version, rerun the availability one-liner on the Codex host, and check whether any staleness warning appears. Remedy: Write a version file beside the copied skills at install; have codex-consult-hook.ps1's one-liner append a 'skills out of date - rerun install' phrase on mismatch.
- **F02-4** [note] `plugins/codex-consult/scripts/codex-consult.ps1:416`, `plugins/codex-consult/skills/consult-codex/SKILL.md:104` - The wording-neutralization plan and its harness grep cover ${CLAUDE_PLUGIN_ROOT} but not the coordinator-named brief prefix NN-claude-<slug> used throughout doc examples, so the Claude-host naming survives the pass. Trigger: Acceptance harness run that greps only for CLAUDE_PLUGIN_ROOT. Evidence: read-code: Four examples name briefs NN-claude-<slug>.; read-code: Skill embeds the same prefix and 'Claude (this coordinator)'. Verify: Grep repo-wide for 'NN-claude' and 'this coordinator' after the wording pass; expect zero outside the changelog. Remedy: Add 'NN-claude' and 'Claude (this coordinator)' patterns to the harness checks; rename example prefixes to NN-<coordinator>-<slug>.

### Prior findings

_(none)_

## Verdict: ADVISE

The design is sound but the root-variable resolution mechanism silently breaks in exactly the Codex install path it is meant to enable, and copy staleness plus coordinator-env inference are unaddressed.

### Blockers

_(none)_

### Unproven scenarios

- Which environment markers a Codex CLI session actually sets and whether codex exec children inherit them (Q3 inference feasibility).
- Whether Codex CLI loads copied skills from ~/.codex/skills without restart and whether it follows symlinks on Windows.
- Whether Codex CLI has an agent-file format at all (design #7's 'when that host supports agent files').
- Whether the lineage-equality comparison for the coordinator warning survives alias normalization (provider::model spellings across roster vs CODEX_CONSULT_COORDINATOR).

### First-run checklist (observable)

_(none)_
