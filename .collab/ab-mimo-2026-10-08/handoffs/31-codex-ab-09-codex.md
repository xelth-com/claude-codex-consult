# Handoff 31 - Codex: ab-09-codex

Date: 2026-10-08 09:23 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 759cf9b8-9c10-46b7-b41a-dbfd4b564350.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-1c54fd3ff0b743669a87287f6f81777f.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11a65-3ee1-7410-b4d0-ea67ae3782b3` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/09-claude-ab-wave27b-addendum.md` (sha256 dd8a19c11bc7). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 788.8 s. Tokens: in 1698445 (cached 393216), out 9755, reasoning 5183.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint confirms B3 and parts of B8/B9 but finds stale wording in B1, B2, B8, B9 and the Verification paragraph; all listed prior findings remain open. Findings: none. Structured reply (prompt-only transport): `handoffs/31-codex-ab-09-codex.reply.json`.
Raw event stream: `handoffs/31-codex-ab-09-codex.events.jsonl`.
Verbatim reply follows.

---

The brief has no literal numbered questions; its numbered invariants are B1, B2, B3, B8, B9. B1. Partial drift: the exact CLAUDE_CODE_* names are scrubbed and CLAUDE_CODE_USE_BEDROCK/CLAUDE_PLUGIN_ROOT/CLAUDE_PLUGIN_DATA are kept, but the code scrubs every ZCODE_* via HostMarkerPrefixes, broader than the named ZCODE_* set (F30-1). B2. Drift: marker precedence is codex -> zcode -> claude-code -> unknown, but zcode triggers on any ZCODE_* and the path fallback can return qwen-code, outside the claimed set (F30-2). B3. Holds: README Install, Hooks on each host, and coordinate Means per host cover Z Code and Kimi Code. B8. Partial drift: harness-detach SINGLE is release-file gated with a 120 s cap; harness-panel RUN checks overlap and wall clock, GUARD is the 15 s parent kill guard, and the launch-time check is in SPEC (F30-3). B9. Partial drift: clauses 1-5 hold, but clauses 6-7 are superseded by coordinate rule 3: running or awaited work stays warm indefinitely and idle wake 2 hands over and removes the wake (F30-4). The Verification paragraph is stale versus v0.6.0-1-g65380b2 and 22 harness files (F30-5). F1-F4 are historical host observations; only F1's marker names are reflected in code here. All listed prior findings remain open; see prior_findings.

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - Start ticks still derive from the same ISO start-time string; flush-lock identity remains pid plus start_time, so the pid-reuse risk is unchanged.
- F13-2 - still-open - The PowerShell 5.1 spool fallback still calls File.Replace without a missing-destination branch.
- F13-3 - still-open - Exit-TelemetryFlushLock still deletes after disposing the read handle, leaving the successor-lock deletion race.
- F13-4 - still-open - The repeated ask still keeps only the first non-blank line after a 300-character cut plus a remaining-line count.
- F13-5 - still-open - The handoff's tmp, append-only spool, harness-count, and commit-range claims still differ from the tree.
- F15-1 - still-open - Kick acknowledgement is still only the id-matched .ack file; the brief's kicked pending state and exit-code description remain stale.
- F15-2 - still-open - The current health warnings and journal behavior still differ from the quoted brief wording.
- F15-3 - still-open - Long tool suspensions remain capped and the engine set includes claude beyond the brief's trio.
- F18-1 - still-open - The same tmp and per-producer not-spooled drift remains in handoffs/03.
- F18-2 - still-open - The suite claim remains stale: the tree has 22 harness files while the recorded run covers 20 and includes one failure.
- F20-1 - still-open - Roster timeouts still produce timeout_source roster, a third value beyond the brief's pair.
- F20-2 - still-open - harness-visibility now has 16 Want suites and 122 Check calls, not the claimed inventory.
- F20-3 - still-open - The 65f5649 / 0.5.0 commit framing still does not describe the tree.
- F20-4 - still-open - The 60-minute usage-limit rule holds, but a burst 429 is out for 10 minutes on the same surfaces.
- F20-5 - still-open - The brief's F-ids still collide with this task's finding namespace.
- F21-1 - still-open - A provider_failure class of unknown is still recorded without being promoted into endpoint health.
- F21-2 - still-open - Preflight now refuses recorded auth and quota failures and uses structured provider_failure first; the brief is stale.
- F21-3 - still-open - The 68353d7 / 0.3.0 / new-script framing still does not describe the tree.
- F22-1 - still-open - Unknown credential or login state still fails closed with a refusal; the brief's not-refused wording is stale.
- F23-1 - still-open - harness-detach now has 51 checks over 17 suites, not 46 over 16.
- F23-2 - still-open - The detached self-report, file list, judgement wording, and commit framing still differ from the brief.
- F23-3 - still-open - The brief's F02-1 through F02-11 ids remain from another task's namespace.
- F25-1 - still-open - Format-repair drift, substance, schema, and harness-format details still differ from the brief.
- F25-2 - still-open - Get-FormatRepairDrift still cannot detect finding-field changes when reply_markdown is faithful.
- F25-3 - still-open - Get-ProseGate still has the two described blind corners.
- F28-1 - still-open - Prompt assembly still has the FINAL OUTPUT CONTRACT first and the separated ask/brief tail; the brief is stale.
- F28-2 - still-open - The bridge is still four-engine and caps-v1, not dependency-free codex-only; the framing is stale.
- F29-1 - still-open - The Q-number drift check still compares counts only, not question identities.
- F30-1 - still-open - Scrub scope is every ZCODE_* prefix, broader than B1's named set.
- F30-2 - still-open - The host hint accepts any ZCODE_* and can return qwen-code, outside B2's closed set.
- F30-3 - still-open - harness-panel RUN and GUARD descriptions are stale; RUN checks overlap and wall clock, GUARD is the 15-second parent kill guard.
- F30-4 - still-open - Coordinate rule 3 revisions supersede B9 clauses 6 and 7.
- F30-5 - still-open - The 2026-09-29 final-code verification is stale versus v0.6.0-1-g65380b2 and 22 harness files.

## Verdict: ADVISE

Checkpoint confirms B3 and parts of B8/B9 but finds stale wording in B1, B2, B8, B9 and the Verification paragraph; all listed prior findings remain open.

### Blockers

_(none)_

### Unproven scenarios

- B8's claim that the SINGLE assertions are unchanged needs the earlier task tree or historical diff.
- Runtime-only prior risks were confirmed by static code reads, not executed.

### First-run checklist (observable)

_(none)_
