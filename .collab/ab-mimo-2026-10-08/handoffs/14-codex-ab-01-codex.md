# Handoff 14 - Codex: ab-01-codex

Date: 2026-10-08 01:41 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 24c443bf-daa7-48a9-8316-b3a8a61ec3d5.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-edf7be6fbc784082a145fa704f0d205d.md -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage mimo :: mimo-v2.6-pro in this task's ledger; other lineage(s): mimo-claude :: mimo-v2.6-pro [claude]). Result thread: `01a118be-5812-7661-aad3-aebf97d462b8` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/01-claude-ab-wave28d-acceptance.md` (sha256 c54a39cee3e0). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 519.7 s. Tokens: in 733547 (cached 98304), out 15216, reasoning 10372.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint of the current invariants: the wave 28d claims hold modulo the documented F13-5 drift and four open minor risks; no new blocker or major was found. Findings: none. Structured reply (prompt-only transport): `handoffs/14-codex-ab-01-codex.reply.json`.
Raw event stream: `handoffs/14-codex-ab-01-codex.events.jsonl`.
Verbatim reply follows.

---

## 1. Status of F48-1..4, F49-1..4, F50-1..2 (current tree, not d65e2e9)

- **F48-1**: fixed — atomic rewrite in `codex-consult-common.ps1:12571-12618` (lock, `<spool>.tmp`, flush, one replace; emptied file deleted). Caveat F13-2.
- **F48-2**: fixed — marker {pid, start_time, start_ticks, since} written (`common:13186`), removed in `finally` (`13224-25`), dead-owner marker healed (`11487-94`). Caveat F13-1.
- **F48-3**: fixed — `common:12656-12714`: record born with lock (`12663-69`), ownerless/unreadable lock held <30 s then removed (`12698-12705`), living owner never taken over, "sender stuck" after 30 min (`12690-92`). Caveat F13-3.
- **F48-4**: fixed — no prompt hash exists (hashes are brief/artifact shas only, `codex-consult.ps1:4285-89`); the appended re-read line is subtracted from the fork/resume estimate (`4169-72`).
- **F49-1**: fixed — unverified pids named beside survivors in the warning (`codex-consult.ps1:1779-80`) and outcome (`4712`) via `Get-KillUnverifiedText` (`1791`).
- **F49-2**: fixed — lock-free append (`common:12096-12106`); wave 28e made it one file per producer, so D4's wording is stale (F13-5).
- **F49-3**: fixed — same rewrite as F48-1.
- **F49-4**: fixed — same lock as F48-3.
- **F50-1**: fixed for the claude model match — both sides pass `ConvertTo-ClaudeModelBase` (lower-cases, `common:4390-92`) in `Test-ClaudeModelMatch` (`4411-12`); unverified whether F50-1 meant `Get-CoordinatorMatch`, still case-sensitive (`7399, 7405`).
- **F50-2**: fixed, accepted limitation — inline ask repeated (`codex-consult.ps1:4138-44`); multi-line ask keeps first line + count (F13-4).

## 2. New defects

None beyond F13-1..5. Verified in code: `<spool>.tmp` is serialized by the telemetry lock and recreated with FileMode Create (`12589, 12596`); a missing spool reports "stayed busy" (`11867`, `12579`) and the PS 5.1 fallback fails on a missing destination (F13-2); the lock record is complete before the no-overwrite move, so simultaneous senders cannot both own it (`12663-69`); the stuck line lives in the latest `.last` and clears on the next successful flush (inferred from `12982`); per-producer counter files remove PS 5.1 append contention (`12090-105`); multi-line repeat limitation is F13-4.

## Drift vs the brief (F13-5, still open)

HEAD is 65380b2 (0.6.0+), not d65e2e9; D4 is per-producer files; D1's `.tmp` is replaced or deleted, not merely removed; `tests\harness-*.ps1` is 22 files, not twenty.

## 3. Acceptance rule

No blocker or major remains on current code; with F13-5 corrected and F13-1..4 fixed or accepted as minor risks, the rule yields ACCEPT (checkpoint verdict: ADVISE).

## Requested checks

- **RC1** (F13-5, item 8): repo root, workspace-write: `powershell -File tests\harness-fixes28d.ps1; powershell -File tests\harness-fixes28e.ps1` — both end "0 failed"; 30 min.
- **RC2** (F13-1): repo root, read-only: spawn 500 short-lived processes, compare `Get-ProcessStartTicks` on distinct pids — any equal tick pair confirms coarse identity; 10 min.
- **RC3** (F13-2): temp dir, workspace-write: PS 5.1, native move stubbed off, delete spool after read before `Remove-TelemetrySpoolLines` — `File.Replace` errors after 8 tries; 15 min.
- **RC4** (F13-3): temp dir, workspace-write: two processes race `Exit-TelemetryFlushLock` against manual lock replacement — successor's lock disappears; 15 min.
- **RC5** (F13-4): workspace-write: run the REREAD case with a multi-line `-Prompt` whose first line exceeds 300 chars — assert the exact repeated tail line; 10 min.

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - Confirmed: Get-ProcessStartTicks parses Get-ProcessStartIso's 'o' string (codex-consult-detached.ps1:194-200 vs 141), and the flush-lock record still stores only pid+start_time (common:12659).
- F13-2 - still-open - Confirmed: common:12607 falls back to File.Replace with no missing-destination branch, unlike Write-TextAtomic's branch at 215-216.
- F13-3 - still-open - Confirmed: Exit-TelemetryFlushLock deletes at common:12763 after the handle is disposed at 12762.
- F13-4 - still-open - Confirmed: codex-consult.ps1:4138-4444 repeats only the first non-blank line (cut at 300) plus a line count; documented limitation.
- F13-5 - still-open - Drift confirmed on the current tree: HEAD 65380b2 (0.6.0+), 22 harness files, per-producer not-spooled files, tmp replace-or-delete semantics; the brief text is unchanged.

## Verdict: ADVISE

Checkpoint of the current invariants: the wave 28d claims hold modulo the documented F13-5 drift and four open minor risks; no new blocker or major was found.

### Blockers

_(none)_

### Unproven scenarios

- Race/timing behavior of pid reuse, the PS 5.1 replace fallback, Exit-TelemetryFlushLock, and the REREAD truncation was read but not executed (see RC2-RC5).
- Current harness suite results were not re-run read-only (RC1).

### First-run checklist (observable)

_(none)_
