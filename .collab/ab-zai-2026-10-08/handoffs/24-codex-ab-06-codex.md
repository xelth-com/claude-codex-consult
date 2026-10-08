# Handoff 24 - Codex: ab-06-codex

Date: 2026-10-08 02:12 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 9d71b5af-7d3c-4e51-bd21-7bc4e11d8907.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-a043bc3682f34da8a9048655527f7680.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118db-0672-7692-b8e8-94af2b076526` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/06-claude-ab-wave25-acceptance.md` (sha256 f70ce935d776). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 492.1 s. Tokens: in 2154114 (cached 2067520), out 17850, reasoning 11397.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - All wave-25 invariants hold on the current tree with no blocker or major; the only drift is stale brief wording (counts, -Prune superset, prompt-file transport) already tracked as notes. Findings: 0 blocker, 0 major, 0 minor, 1 note (F24-1, tracked in `findings.json`). Structured reply: `handoffs/24-codex-ab-06-codex.reply.json`.
Raw event stream: `handoffs/24-codex-ab-06-codex.events.jsonl`.
Verbatim reply follows.

---

## Answers

Preliminary: the brief is a wave-25 verbatim re-ask; commit 53de158 is no longer the tree. All locations are current-tree lines.

**1. F02-1..11 — all resolved on the current code** (fixed, or the accepted D9 design):

- **F02-1 fixed** — `.gitignore:29` ignores `.consult.detached-*`.
- **F02-2 fixed** — foreground = dry-run plus pre-lock refusals (`codex-consult.ps1:1523-1530`): roster 2347/2866, launcher 2756/3792-3795, recovery record 3892, preflight 3650, `%` hazard 1113-1116.
- **F02-3 fixed** — background try/finally 1479-1500, `StopWithErrorHook` 1513-1519; the final write retries 3x and the background exits 6 when it still fails (common 968-976; 1499-1505).
- **F02-4 fixed** — `Get-DetachedBudget` (common 11178-11197); `-Wait` default 1402-1407.
- **F02-5 fixed** — `starting` written once 1126-1138; self-report 1461-1471; 60 s grace (detached.ps1:270, 443-450).
- **F02-6 fixed** — `Test-PidAlive` (detached.ps1:182-189); died 456-460. `-Prune` is now a superset (1367-1392 — F23-2).
- **F02-7 accepted limitation** (D9) — `.consult.` prefix kept; snapshot exclusion asserted by harness-detach UNIT.
- **F02-8 fixed** — UTF-8 before first output 1472-1474.
- **F02-9 fixed** — member states, host, elsewhere never judged (453-455; UNIT check).
- **F02-10 fixed** — 1347-1366; worst exit 1432-1438.
- **F02-11 fixed** — 1328-1331/1525-1526; absolute paths 1075-1077; cwd 1149/1156.

**2. New defects.** None blocker/major in the detach surface. Verified in code: argument transport (base64 CLIXML round-trip, common 11230-11255), status lifecycle, exit codes 0-4 (plus 6, a later documented addition), log/summary equivalence (1225-1228), panel member updates (3067-3243, 4650), T4 (`-ScriptsDir`/`CODEX_CONSULT_SCRIPTS_DIR` on run-all and all 22 harnesses). Drift, not defect: item 1's "arguments travel inside the `starting` record" — since wave 26 (F11-2) an inline `-Prompt` goes to `.consult.detached-<id8>.prompt.txt` and the record names only `PromptFile` (finding #1); item 5's count is stale (F23-1: 51 checks, 17 cases incl CARRY); item 2's `-Prune` wording understates (F23-2). The self-report itself sets running/pid/start_time/host; `budget_sec` comes from the foreground's starting record. Declared residuals still hold: the benign lock window, killing only the background, untested nohup.

**3.** On the brief's own criterion — no blocker or major in the wave-25 scope — the current tree would **ACCEPT**; everything open there is stale wording or documented residuals (the ADVISE verdict is this review's contract).

## Requested checks

- **RC1** (workspace-write, repo root, ~5 min): `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-detach.ps1` — expect 51 PASS / 0 FAIL and CARRY among the case names (F23-1, F02 sweep).
- **RC2** (workspace-write, ~2 min): `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28b.ps1 -Only STALL` — stall cut with named OpenTools passes (F15-1).
- **RC3** (workspace-write, ~3 min): `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28e.ps1` — NOTSPOOLED and ANCHOR cases pass (F17-1).

---

### Findings

- **F24-1** [note] `.collab/ab-zai-2026-10-08/handoffs/06-claude-ab-wave25-acceptance.md:17`, `plugins/codex-consult/scripts/codex-consult.ps1:1101` - Brief item 1's argument-transport sentence is stale: since wave 26 (F11-2) an inline -Prompt no longer travels inside the starting record — the foreground writes <task>/.consult.detached-<id8>.prompt.txt and the record's args name only PromptFile; the background reads and removes the file. Everything else (base64 CLIXML, only -Task/-CollabDir/-DetachId on the command line) still holds, and the change removes prompt text from the status file. Trigger: Reading the brief's item 1 against Start-DetachedRun's PromptFile block and the background's prompt-file read. Evidence: read-code: An inline Prompt is written to $paths.Prompt, removed from $bgArgs and replaced by PromptFile; the background (1482-1490) reads the file and deletes it.; read-code: The prompt-file transport and its removal are covered by the current harness. Verify: Run tests/harness-detach.ps1 and confirm the two CARRY F11-2 checks pass and the case list includes CARRY. Remedy: Amend the re-ask record: item 1 should say the arguments travel in the record except an inline -Prompt, which travels as a prompt file since wave 26.

### Prior findings

- F13-1 - still-open - Counted 22 harness-*.ps1 in tests/ and exactly 40 Check calls in harness-fixes28d.ps1; the 'twenty harnesses' claim stays stale.
- F13-2 - still-open - Open-TelemetrySpoolFile returns $null for a missing file (common 11867); Remove-TelemetrySpoolLines still reports 'stayed busy' (12579).
- F14-1 - still-open - Flush checks only lock ownership (12920) then rewrites with Math.Max(100, remaining) (12922), so a rewrite can start past the deadline.
- F15-1 - still-open - Wait-EngineProcess cuts a tool-open turn after 2x StallSec without stream growth (11030-11037); the wave-26c D3 'never cut' wording remains stale.
- F16-1 - still-open - No 'kicked' pending-record state exists; -Kick acknowledges only via <kick file>.ack within 10 s (1275-1301).
- F16-2 - still-open - The literal warning is gone; current texts at codex-consult.ps1:6076 and 6122 are the cause-bearing commit/retry variants with journal.
- F16-3 - still-open - Wait-EngineProcess header 10960-10962 ('never cut') still contradicts the D12 note 10972-10978 and the code at 11030-11037.
- F17-1 - still-open - Not-spooled is per-producer files with a flush fold (Add/Get/Merge-TelemetryNotSpooled at 12096/12196/12267, not_spooled_seen/folded) and the inline ask repeats its first line cut at 300 chars (4134-4141).
- F17-2 - still-open - tests/README.md:23 still says harness-claude is 'the twentieth harness' while run-all.ps1 registers 22.
- F19-1 - still-open - harness-visibility.ps1 now contains 122 Check calls, not 76.
- F21-1 - still-open - Get-EndpointHealth builds Auth/Quota only from classes auth/quota (6312-6320); a class-unknown failure reaches only LastFailure (6324), so the endpoint stays available.
- F21-2 - still-open - Format-QuotaWarning returns '' unless -SkipPreflight (7926-7928); a still-blocking usage limit refuses the run otherwise.
- F21-3 - still-open - Get-EndpointHealth merges machine-wide entries (6194-6199) and cross-route fingerprints (6179-6180), beyond 'this repository's ledgers within 24 h'.
- F22-1 - still-open - Classification is payload-first with the ordered FailureClassPatterns table (5748-5765) whose quota pattern covers credits exhausted, 402, billing, etc.; the decision is stored in provider_failure (6242-6264).
- F23-1 - still-open - harness-detach.ps1 has 51 Check calls across 17 case names (the listed 16 plus CARRY).
- F23-2 - still-open - -Prune also removes never-started and unreadable files older than 7 days (1367-1392), a superset of the brief's 'done and died'.

## Verdict: ADVISE

All wave-25 invariants hold on the current tree with no blocker or major; the only drift is stale brief wording (counts, -Prune superset, prompt-file transport) already tracked as notes.

### Blockers

_(none)_

### Unproven scenarios

- No test was executed in this read-only consultation: harness-detach's 51 PASS lines and the STALL/NOTSPOOLED cases are inferred from code and check counts, not observed.
- The macOS/Linux nohup background path remains untested.
- The 3-attempt final status write and exit 6 were read in code, not reproduced at runtime.

### First-run checklist (observable)

_(none)_
