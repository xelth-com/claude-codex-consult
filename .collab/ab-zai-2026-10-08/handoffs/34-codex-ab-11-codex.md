# Handoff 34 - Codex: ab-11-codex

Date: 2026-10-08 03:05 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 4ae290d6-8f8a-48c3-894c-447dd2df3dc1.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-eb3f0855021b4cb1aa92b5d720ef6973.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a1190a-f936-7af0-9bee-767537e1b974` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/11-claude-ab-wave21-acceptance.md` (sha256 ba376a415b4b). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 426 s. Tokens: in 1123324 (cached 1012672), out 10485, reasoning 5732.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint verified the wave-21 panel invariants against the current code and found no new defect; all drift is already covered by the listed still-open findings. Findings: none. Structured reply: `handoffs/34-codex-ab-11-codex.reply.json`.
Raw event stream: `handoffs/34-codex-ab-11-codex.events.jsonl`.
Verbatim reply follows.

---

## Answers

**1. Prior findings F02-\*/F03-\*/F04-\*** — none of these ids exist in this task's prompt; the open findings here are F13-1…F33-3. I re-checked them against the current tree (details in `prior_findings`): **all still-open, none fixed**. Most are stale-brief/doc drift; the behavioral ones (F14-1 deadline check, F15-1 stall cut vs 'never cut', F21-1 unknown failure class ignored, F25-2/3/4 prose-gate gaps) are unchanged in code.

**2. New defects in the wave-21 concurrency/recovery/commit paths** — I found **no new defect** beyond the listed findings. Verified by reading code (no tests run, read-only):

- `Get-PanelPlan` (common:8872) merges fingerprint/agy groups, smallest-limit rule, `-PanelConcurrency` cap — plus the wave-29b E7 plan quota (F33-2, substance holds).
- `Get-PanelIgnorePrefixes` (common:8916) covers both stores, sibling handoffs and `Write-TextAtomic` temp prefixes.
- `Enter-WriteLock`/`Get-WriteLockTimeout` (common:9481/9492), `Enter/Complete/Exit-StoreCommit` (common:9559-9600) re-read stores under the lock, write findings then sessions; `Add-LedgerEntry` (common:9606) inserts by n.
- Member proof (consult:2437-2495): record must name panel/n/NN/parent, rewrite with own pid, then parent-alive check — matches D6/D1 and deviation 5.
- Parent holds the task lock, judges all records, numbers up front, writes every `reserved` record before launch; launch loop (consult:3045-3133) uses `Start-Process` + `HasExited` polling with 500 ms idle sleep and per-slot `Get-PanelMemberGuard` kills; summary carries panel wall clock and the counts commit (consult:3277-3292).
- `Test-PendingActive` (common:10254+) uses live-writer, never the name rule for panel records; `committing` is in `$script:PendingStates` (common:9621).
- `codex-findings.ps1` lists every record (179), `-Status` reads all records (418) and both `-Status` and `-Rate` write through the store commit (423/497, 561/589).

Drift vs the brief's letter (all already filed): 48 assertions → 62 Checks across 15 cases in `harness-panel.ps1` (F33-1); guard/test-hook picture widened (F33-3); commit `2de15e9` long superseded by waves 22-29c — I cite current lines instead, as the brief's preamble allows. The 'suite green under PS 5.1 / pwsh 7.6.6' claim was not re-run.

**3. Verdict** — ADVISE (mandated for this consultation). No new blocker/major at this checkpoint; acceptance-blocking status is unchanged from the still-open prior findings.

## Requested checks

- RC1: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-panel.ps1` in the repo root (workspace-write) — expect 62 PASS, 0 FAIL, 15 case names; ~2-5 min.
- RC2: `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1` in the repo root (workspace-write) — expect 22 harnesses, all PASS; ~30-60 min.

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - 22 harness files, 40 Checks in harness-fixes28d confirmed by count.
- F13-2 - still-open - common:12579 still returns 'stayed busy' when the spool file is missing.
- F14-1 - still-open - Flush rewrite still starts with Math.Max(100, remaining) after only the lock check (common:~12922).
- F15-1 - still-open - 'never cut' comment beside the 2x StallSec cut and OpenTools naming still present (common:10962-11036).
- F16-1 - still-open - Kick acknowledged only via <kick file>.ack within 10 s (consult:1277-1292).
- F16-2 - still-open - Literal old warning gone; cause-bearing texts at consult:6076/6122 confirmed.
- F16-3 - still-open - Contradictory Wait-EngineProcess header comment unchanged (common:10960-10972).
- F17-1 - still-open - not_spooled_seen/folded machinery and multi-line-ask reread present.
- F17-2 - still-open - README still says 'twentieth'; run-all registers 22 harnesses.
- F19-1 - still-open - harness-visibility has 122 Check calls (counted).
- F21-1 - still-open - Classifier returns 'unknown' for unmatched evidence (common:5752-5766); no fix seen.
- F21-2 - still-open - Format-QuotaWarning warns only with -SkipPreflight; blocking quota still refuses (common:~7930).
- F21-3 - still-open - Machine-wide health and plan-quota merge still present (common:6420-6431).
- F22-1 - still-open - Ordered FailureClassPatterns with widened quota regex confirmed (common:5751-5758).
- F23-1 - still-open - harness-detach has 51 Check calls (counted).
- F23-2 - still-open - Prune block also gates never-started/unreadable by log age (consult:1367-1390).
- F24-1 - still-open - PromptFile transport present (consult:1097-1136, 1484-1487).
- F25-1 - still-open - harness-format has 37 Check calls (counted).
- F25-2 - still-open - Drift checks compare numbered answers only (common:1786-1807); findings fields uncovered.
- F25-3 - still-open - Marker suppression still overrides refusal floors (common:1752).
- F25-4 - still-open - NumberedAnswerRe still lacks 'A1:'-style forms (common:1738).
- F27-1 - still-open - format_retry ledger and repair flow still implemented; brief framing stale.
- F28-1 - still-open - Prompt opens with FINAL OUTPUT CONTRACT before the ask (consult:~4050; header comment cc:21).
- F29-1 - still-open - Whole ZCODE_ prefix scrub present (common:7031).
- F29-2 - still-open - No wake-3/nine-hours rule in coordinate SKILL.md; 'warm ALWAYS' wording present.
- F31-1 - still-open - run-all lists 22 harnesses; visibility 122 Checks (counted).
- F31-2 - still-open - Ownerless lock held while younger than 30 s (common:12654/12698).
- F31-3 - still-open - Reread line repeats first ask line + '(+n more lines)', cut at 300 (consult:~4128-4141).
- F33-1 - still-open - harness-panel has 62 Check calls across 15 cases (counted).
- F33-2 - still-open - E7 plan-quota cap confirmed inside Get-PanelPlan.
- F33-3 - still-open - Guard adds Repair/DenialRetry/ContinueSec budgets (common:8937-8944).

## Verdict: ADVISE

Checkpoint verified the wave-21 panel invariants against the current code and found no new defect; all drift is already covered by the listed still-open findings.

### Blockers

_(none)_

### Unproven scenarios

- No harness or suite was executed (read-only consultation); the brief's 'suite green under Windows PowerShell 5.1 / harness-panel under pwsh 7.6.6' claim rests on the implementer's report.
- Behavioral prior findings (F14-1, F15-1, F21-1, F25-2/3/4) were verified by code reading, not by their trigger scenarios.

### First-run checklist (observable)

_(none)_
