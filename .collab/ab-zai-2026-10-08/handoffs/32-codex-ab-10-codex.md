# Handoff 32 - Codex: ab-10-codex

Date: 2026-10-08 02:49 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: b3ade61e-3bee-4f8f-9461-0f7e5ca0920a.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-296f847ad3554c78a518ec9780a46c09.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118fc-b67f-79b0-ad1b-9b7510d636d0` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/10-claude-ab-wave28c-acceptance.md` (sha256 b14bbba7c8b8). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 531.8 s. Tokens: in 2464807 (cached 2395456), out 13984, reasoning 7773.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint found no new blocker or major; all confirmed drift is stale wording or counts already tracked as prior findings. Findings: none. Structured reply: `handoffs/32-codex-ab-10-codex.reply.json`.
Raw event stream: `handoffs/32-codex-ab-10-codex.events.jsonl`.
Verbatim reply follows.

---

Checkpoint against the current tree (wave 29c); code-read only, no suites run.

## 1. F41-1, F42-1..9, F43-1..7, F44-1..6
The substance of D1-D14 is present in the current code: closed per-vendor model lists with exact match after lower-casing, else `other` (`Get-TelemetryModelToken`, codex-consult-common.ps1 ~11689); `-Forget` sends DELETE first and removes the salt/spool/counters only after the intake confirms, with the `telemetry-forgetting` marker removed in `finally` (`Invoke-TelemetryForget`, common ~13139); proxy/trust allow-list variables (common ~4499-4520); `kill_unconfirmed` machinery for unreadable descendants/pgrep failures; journal `.bad` handling (common ~6443-6616); `compactions: unknown` (codex-consult.ps1 ~5602-5612); test-mode warning line; CHANGELOG `[0.5.0]`. F43-6/F44-3 remain accepted limitations and the repository README states so (README.md:3213; the plugin README defers to it). Three letter-drifts versus the current tree: D4 (F31-2, ownerless lock held under 30 s), D11 (F31-3, closing line also repeats the ask), item 10 counts (F31-1, 22 harnesses / visibility 122). Not individually verified: D5 beyond F14-1, D7 status-record wording, D12's dry-run line, and the item-10 "0 failed" runs on PS 5.1/7.6.6.

## 2. New defects
None new. Probes: model text reaches `details.model`/`tags` only through `Get-TelemetryModelToken`'s closed-list equality; no salt removal without a confirmed DELETE when `-PublicRef` was given (every early exit leaves files untouched); the spool rewrite is atomic (tmp file + Move-with-overwrite, crash test hook) so a mid-rewrite cut leaves the old or the new file; the re-read line is bridge text that takes no part in thread-continuation decisions (codex-consult.ps1 ~4160), so lineage is unchanged. All other drift seen is already covered by the prior findings below — each re-confirmed in code today.

## 3. Disposition
ADVISE per the contract. No blocker or major found in this checkpoint; the confirmed drift is stale wording/counts, already tracked.

## Requested checks
- RC1: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1` (repo root, workspace-write, ~15 min): 22 harnesses run, `0 failed`, harness-visibility prints 122 PASS lines (F31-1, F13-1).
- RC2: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28b.ps1 -Only STALL` (repo root, workspace-write, ~2 min): STALL passes with `Reason stall` and named OpenTools (F15-1).
- RC3: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28e.ps1` (repo root, workspace-write, ~5 min): NOTSPOOLED and ANCHOR cases pass (F17-1).

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - 22 harness files and 22 entries in run-all.ps1; harness-fixes28d has 40 Check calls.
- F13-2 - still-open - Open-TelemetrySpoolFile returns $null for a missing file; Remove-TelemetrySpoolLines then reports 'stayed busy'.
- F14-1 - still-open - Rewrite still called with Math.Max(100, remaining) after only the lock check; no literal deadline guard.
- F15-1 - still-open - Wait-EngineProcess cuts after 2x StallSec without stream growth while a tool is open (D12 block).
- F16-1 - still-open - -Kick waits only for <kick file>.ack with its id, up to 10 s; no 'kicked' pending state.
- F16-2 - still-open - Cause-bearing 'not updated at the commit/by the retry' texts present; old literal string absent.
- F16-3 - still-open - Wave-26c D3 comment ('never cut') still contradicts the D12 comment and code five lines below.
- F17-1 - still-open - Per-producer not-spooled files + Merge-TelemetryNotSpooled fold and the ask reread line are present.
- F17-2 - still-open - tests/README.md still calls harness-claude 'the twentieth harness of run-all.ps1'.
- F19-1 - still-open - harness-visibility.ps1 has 122 Check calls.
- F21-1 - still-open - Get-EndpointHealth fills Auth/Quota only for classes auth/quota; class 'unknown' is ignored.
- F21-2 - still-open - Format-QuotaWarning only with -SkipPreflight; without it a blocking usage limit refuses the run.
- F21-3 - still-open - Machine-wide health entries merged into Get-EndpointHealth (ConvertTo-MachineHealthEntries); providers exit-code part not re-checked.
- F22-1 - still-open - Payload-first classifier with widened quota pattern (credits, 402, billing, rate_limit_exceeded...).
- F23-1 - still-open - harness-detach.ps1 has 51 Check calls.
- F23-2 - still-open - -Prune comment/code also removes never-started and unreadable status files older than 7 days.
- F24-1 - still-open - Inline -Prompt travels via .consult.detached-<id8>.prompt.txt; record args name PromptFile only.
- F25-1 - still-open - harness-format.ps1 has 37 Check calls.
- F25-2 - still-open - Get-FormatRepairDrift compares RC ids, Q counts, F-id presence, verdict, >=60-char sentences; not findings[] fields.
- F25-3 - still-open - Markers (numbered style, F-id, RC, 'verdict') still suppress the refusal test.
- F25-4 - still-open - NumberedAnswerRe recognizes only listed styles; 'A1:' etc. fall to word floors.
- F27-1 - still-open - Format-repair retry fully implemented (Get-ProseGate, drift notes, ledger format_retry, .original.md).
- F28-1 - still-open - Structured prompt opens with the FINAL OUTPUT CONTRACT before the ask.
- F29-1 - still-open - Whole ZCODE_ prefix scrubbed (wave 27c D20/D21) beyond the exact names.
- F29-2 - still-open - Coordinate skill carries revision 6 (warm always while work runs); no wake-3 or nine-hours clause.
- F31-1 - still-open - Item 10 says nineteen/121; run-all registers 22, visibility has 122; detach 51 and format 37 match.
- F31-2 - still-open - Ownerless flush lock held while younger than TelemetryOwnerlessLockSec=30 (common ~12699).
- F31-3 - still-open - Closing line repeats the one-line ask, or first line + '(+n more lines)' cut at 300 (codex-consult.ps1 ~4144).

## Verdict: ADVISE

Checkpoint found no new blocker or major; all confirmed drift is stale wording or counts already tracked as prior findings.

### Blockers

_(none)_

### Unproven scenarios

- The item-10 full-suite '0 failed' runs on Windows PowerShell 5.1 and PowerShell 7.6.6 were not executed (read-only consultation).
- Item 10's per-harness counts other than visibility/detach/format/fixes28d were not recounted.
- D5's deadline accounting beyond F14-1, D7's status-record/console wording, and D12's dry-run test-mode line were read only at comment level.
- F21-3's codex-providers exit-code-1 detail was not re-verified in this pass.

### First-run checklist (observable)

_(none)_
