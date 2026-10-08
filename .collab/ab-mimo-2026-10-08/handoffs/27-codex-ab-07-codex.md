# Handoff 27 - Codex: ab-07-codex

Date: 2026-10-08 08:48 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: b00db3b2-dfe6-425a-801e-804d6bb01a70.
Recovery record: recovered reservation n=14, nn=26 (state 'running' of an interrupted run; writer pid 22020 gone; codex pid(s) 19924 [gone] no longer running; Win32_Process scan (children of the interrupted bridge pid 22020; started at or after 2026-10-08T03:39:55): none found; Win32_Process scan (children of the interrupted bridge pid 19924; started at or after 2026-10-08T03:39:55): none found; then Win32_Process scan (name codex*, or a command line containing the recorded launcher or @openai/codex; not the Codex app's servers and helpers; started at or after 2026-10-08T03:39:55): none found; the raw event stream of that run is at .collab/ab-mimo-2026-10-08/handoffs/26-codex-ab-07-codex.events.jsonl (it may hold a usable reply); no ledger entry was written); numbering continues past it.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-b071879984fb424f8dc80497e6383afe.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a11a45-4b48-73c0-a35e-81c8ffae4df1` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/07-claude-ab-wave14-review.md` (sha256 1b05147c21a3). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 382.8 s. Tokens: in 617108 (cached 147456), out 12039, reasoning 8901.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint: the brief's three current invariants hold on the tree, with claim-vs-wording drift already open as F25-1 and the repair/gate blind corners open as F25-2/F25-3. Findings: none. Structured reply (prompt-only transport): `handoffs/27-codex-ab-07-codex.reply.json`.
Raw event stream: `handoffs/27-codex-ab-07-codex.events.jsonl`.
Verbatim reply follows.

---

**Invariants (tree v0.6.0-1-g65380b2).** All three hold. (1) The repair resumes the same thread and re-sends the same consultation id (codex-consult.ps1:5255-5270); the entry keeps the original thread (a differing repair thread only adds a drift note, 5405-06) and the prose is copied to .original.md before the repair process starts (5258-62), kept on every outcome. (2) Repair needs -FormatRetry 1, structured mode, bridgeOutcome 'usable reply', a verified thread and substantive prose (5233-41; common:1739-56) - never on a failed run, timeout, provider failure, short reply, unverified thread, -Raw, chore or -FormatRetry 0. (3) A structurally valid object with a purpose-mismatched verdict keeps Valid=true with VerdictInvalid (common:1373-84), so it is not repaired. Drift: the brief's What-changed prose is stale (F25-1, still open).

**Q1.** Path: the repair's reply_markdown faithfully echoes the prose while findings[] is altered - e.g. a softened severity or replaced remedy (F25-2), or an added finding. Check 3 only proves F-ids named in the prose exist somewhere; check 5 matches sentences only against reply_markdown, so findings[] edits yield zero notes. A narrow seventh check (severity token and path:line set near each F-id versus its findings[] entry) is cheap and worth adding as a warning; full equivalence is not, so keep the rule that drift notes are warnings and the coordinator reads the original whenever a repair succeeded.

**Q2.** The record is running with the repair's child_pid/child_start_time, note 'format repair turn'; earlier it is launching and already carries original and first_reply. Killed mid-repair, the next run's Test-PendingActive (common:10254+) judges that pid by pid+start time/evidence rule: alive -> active (blocked); gone -> inactive and Get-PendingOriginalNote (common:10204-18) names the saved prose. The first reply is kept, not lost - .original.md is written before the repair process exists.

**Q3.** Wrongly accepts: a >120-word safety message opening 'This request is not something I can help with...' - no listed refusal phrase in the 200-char head, no F/RC/Verdict marker. Wrongly rejects: 'Q1. Yes. Q2. No.' (4 words) -> reply too short (4 words), though verbatim conversion would succeed (common:1737-56).

**Q4.** HOLD as a diff: no blockers; F25-2 (major) and F25-3 (minor) remain. Unproven: live repair turns, a bridge killed mid-repair, PS 5.1 hosts. First-run checklist: structured true on the first turn with format_retry null; exit 0.

## Requested checks
- RC1 (F25-2): workspace-write, ~2 min: run tests/harness-format.ps1 under pwsh and confirm 37 checks / 9 suites pass on the current tree.
- RC2 (F25-2): read-only, ~1 min: call Get-FormatRepairDrift with prose naming F25-2 and a Reply whose findings[] entry has a different severity and remedy - expect an empty notes array.

---

### Findings

_(none)_

### Prior findings

- F13-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F13-2 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F13-3 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F13-4 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F13-5 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F15-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F15-2 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F15-3 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F18-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F18-2 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F20-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F20-2 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F20-3 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F20-4 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F20-5 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F21-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F21-2 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F21-3 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F22-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F23-1 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F23-2 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F23-3 - not-checked - Outside brief 07's invariants; not re-verified in this checkpoint.
- F25-1 - still-open - Confirmed on the current tree: gate floors are common:1753-54, sentence check is 40 sentences >=60 chars (1824-31), format_retry carries events/schema_transport (codex-consult.ps1:5429-30), only codex omits --output-schema, and harness-format has 37 Check calls over 9 Want suites.
- F25-2 - still-open - Confirmed: Get-FormatRepairDrift (common:1793-1831) never compares findings[]/prior_findings content, so the described altered-severity repair yields zero notes.
- F25-3 - still-open - Confirmed: Get-ProseGate's phrase list and word floors (common:1737-56) reproduce both blind corners (unlisted safety wording; terse complete numbered answers).

## Verdict: ADVISE

Checkpoint: the brief's three current invariants hold on the tree, with claim-vs-wording drift already open as F25-1 and the repair/gate blind corners open as F25-2/F25-3.

### Blockers

_(none)_

### Unproven scenarios

- A live format-repair turn and a bridge killed mid-repair were not executed (read-only consultation); Q2 rests on Test-PendingActive/Get-PendingOriginalNote and the ORPHAN harness fixture.
- tests/harness-format.ps1 was not run on the current tree; its 37 Check calls and 9 Want suites were counted by reading the file.

### First-run checklist (observable)

_(none)_
