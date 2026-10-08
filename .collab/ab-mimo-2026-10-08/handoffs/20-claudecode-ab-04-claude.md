# Handoff 20 - Claude (claude): ab-04-claude

Date: 2026-10-08 02:37 local. Author: Claude (claude) (model mimo-v2.6-pro, effort medium), claude-cli 2.1.293.0.
Reviewer: mimo-claude :: mimo-v2.6-pro [claude] (provider from -Provider, model from roster; engine claude (C:\users\dmytro\.local\bin\claude.exe), endpoint https://token-plan-ams.xiaomimimo.com/anthropic (token from env MIMO_API_KEY); provider fingerprint f615a41b2fe4; harness claude-cli 2.1.293.0).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 12 of 12 for -Provider mimo-claude (engine, model applied).
Effort: medium sent (requested medium, mapping claude-v1, by caps-v1: engine:claude, any model; not confirmed by the provider). Consultation id: 32395df9-e93b-47b5-af7e-9045589dd1f6.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; claude --restricted --tools Read,Grep,Glob --permission-mode dontAsk --strict-mcp-config, proven by each turn's init event; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules or files outside the repository; managed settings and their hooks still apply), purpose: checkpoint). Argv: `claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model mimo-v2.6-pro --effort medium --json-schema "{"$schema":"http://json-schema.org/draft-07/schema#","title":"codex-consult reply v1","type":"object","additionalProperties":false,"required":["schema_version","verdict","verdict_reason","reply_markdown","findings","prior_findings","unproven","first_run_checklist"],"properties":{"schema_version":{"type":"string","enum":["1"]},"verdict":{"type":"string","enum":["ACCEPT","HOLD","REJECT","ADVISE"]},"verdict_reason":{"type":"string"},"reply_markdown":{"type":"string"},"findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["severity","locations","claim","trigger","evidence","verification","remedy","supersedes"],"properties":{"severity":{"type":"string","enum":["blocker","major","minor","note"]},"locations":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["path","line"],"properties":{"path":{"type":"string"},"line":{"type":["integer","null"]}}}},"claim":{"type":"string"},"trigger":{"type":"string"},"evidence":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["kind","reference","observation"],"properties":{"kind":{"type":"string","enum":["read-code","ran-command","inferred","assumed"]},"reference":{"type":"string"},"observation":{"type":"string"}}}},"verification":{"type":"string"},"remedy":{"type":"string"},"supersedes":{"type":"array","items":{"type":"string"}}}}},"prior_findings":{"type":"array","items":{"type":"object","additionalProperties":false,"required":["id","status","note"],"properties":{"id":{"type":"string"},"status":{"type":"string","enum":["fixed","still-open","not-checked","unknown-id"]},"note":{"type":"string"}}}},"unproven":{"type":"array","items":{"type":"string"}},"first_run_checklist":{"type":"array","items":{"type":"string"}}}}" --session-id 396134da-9327-4811-8268-eb1257595655` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `396134da-9327-4811-8268-eb1257595655` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md` (sha256 105cd6dbd192). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 697.2 s. Tokens: in 289693 (cached 229248), out 30928, reasoning ?.
Engine turns: 1 (claude -p, auth endpoint; model mimo-v2.6-pro; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint of wave 24's claims on the current tree: the behavioural invariants hold and only wording/counts drift (findings #1-#5), none of them a blocker or major. Findings: 0 blocker, 0 major, 2 minor, 3 note (F20-1..F20-5, tracked in `findings.json`). Structured reply: `handoffs/20-claudecode-ab-04-claude.reply.json`.
Raw event stream: `handoffs/20-claudecode-ab-04-claude.events.jsonl`.
Verbatim reply follows.

---

# Wave 24 claims vs the current tree (checkpoint)

The brief is a verbatim copy re-asked on the current tree: **commit 65f5649 / "0.5.0 candidate" no longer describes it** (0.6.0, waves 25-29c in between), so all cites below are current lines (finding #3).

**Claims 1-6**
1. Continuation **holds** — default `min(timeout,900)` (codex-consult.ps1:2214), same-thread resume (5001-02), ingest with `usable reply (after a timeout continuation)` (5587) and `timeout_continue {thread, wall_seconds, outcome, events, usage}` (5062, 6012); no continuation after survivors (5039), changed files (5047-52) or quota/billing/auth (5058-59) — also after an unconfirmed kill (5040) or failed proof (5037); panel guard grows by `-ContinueSec` (common:8942).
2. Salvage **holds** — `NN-<engine>-<slug>.partial.md` (5651), messages/reasoning/tools (common:5606-27), resume footer (5621), `partial_reply` (5985), summary names it (3194); `-Thread` takes a killed agy/muse run (common:9198).
3. Mostly holds — purpose defaults incl. acceptance 3600 (2024-27), `-Range` shortstat in prompt+ledger (4069; common:406), 1500/2400 warning (2032-33). **Drift:** `timeout_source` gained `roster` (finding #1).
4. **Holds** — launch guard `-Fresh` re-reads muse `auth.json` (1722, 4610).
5. **Holds** — `-NoNetwork` per-entry verdicts (common:9054), groups over the whole roster, walk verdict on rows/`-Short`/`-Json`/hook (codex-providers.ps1:322, 375; hook:78), 60-min no-reset (common:6291; harness 288/295), LAST FAILURE (harness 298), `endpoint health: <dir>` (providers:464). Carve-out: finding #4.
6. **Drift** — harness-visibility is 16 suites / 122 checks, CONT split, no GUARD suite there; "(76)" stale (finding #2).

**Ask 1.** Ids F02-9…F04-10 are the earlier task's wave-24 set — unknown here (finding #5). This prompt's ten are ruled in `prior_findings`: F13-2, F13-5, F15-1, F15-2, F18-1, F18-2 still-open (re-verified by read/grep); F13-1, F13-3, F13-4, F15-3 not-checked (companion-wave, per instruction).

**Ask 2.** No behavioural defect surfaced in the wave-24 mechanics by static reading (they were hardened in waves 24b/24c/29b); the concrete defects are claim-vs-tree drift, findings #1-#5. Verified: every line cite above. Inferred: end-to-end continuation/salvage runs; claim 6's "field-order assertions … four harnesses".

**Ask 3.** No blocker or major remains in wave 24's invariants on this tree; were this an acceptance run: ACCEPT, amending claim wording per findings #1-#2 (docs only).

## Requested checks
- **RC1** (finding #2, F18-2) — repo root, workspace-write: `pwsh -NoProfile -File tests/run-all.ps1`, then `powershell -NoProfile -File tests/run-all.ps1`; observe every harness incl. harness-visibility's 122 checks ending 0 failed on both hosts; budget 30-60 min.
- **RC2** (finding #3, F13-5) — main checkout, read-only: `git log --oneline 65f5649..HEAD -- plugins/codex-consult tests`; observe the waves landed after 65f5649; budget 1 min.
- **RC3** (F15-3) — repo root, workspace-write: `pwsh -NoProfile -File tests/harness-fixes28b.ps1 -Only <tool-cap case label from the file's Want labels>`; observe the stall cut naming the open tool call after 2x-StallSec; budget 5 min.

---

### Findings

- **F20-1** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:351`, `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md:25` - Claim 3's closed set `timeout_source: purpose|explicit` has drifted: since wave 26b (D11) a roster entry's own timeout yields `timeout_source roster`, so the ledger can carry a third value. The purpose defaults, timeout_sec and the -Range invariants themselves hold. Trigger: A run or panel member whose roster entry supplies a timeout (Timeout line ends '(roster)'). Evidence: read-code: help text: 'timeout_source purpose|explicit' for -TimeoutSec, then 'timeout_source roster' for a roster entry's timeout exception; read-code: member slot reads timeout_source from the panel assignment (default 'explicit'). Verify: Run codex-consult.ps1 with a roster entry that sets `timeout` and read the ledger's timeout_source (expect 'roster'). Remedy: Amend claim 3 to `timeout_source: purpose|explicit|roster` (cite wave 26b D11).
- **F20-2** [minor] `tests/harness-visibility.ps1:269`, `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md:34` - Claim 6's `harness-visibility (76): UNIT, AVAIL, AGREE, QUOTA60, HOOK, DEFAULTS, RANGE, CONT (codex/agy/muse), PANEL, GUARD` is stale: the file now has 16 Want suites (UNIT, UNIT24B, UNIT24C, AVAIL, AGREE, QUOTA60, HOOK, DEFAULTS, RANGE, CONT, CONTAGY, CONTMUSE, GATES, GATES24C, BURST, PANEL), 122 Check calls, CONT split in three, and no GUARD suite in this harness (GUARD checks live in harness-claude/companions/engines). The named wave-24 cases still exist. Trigger: Reading claim 6 against harness-visibility's Want labels and Check count. Evidence: ran-command: 16 suite blocks at lines 269-1058; labels as listed; no GUARD block; ran-command: both counts 122 => 122 Check calls and zero GUARD occurrences (vs claimed 76 cases incl. GUARD); read-code: Check 'GUARD' ... lives in harness-claude (also harness-companions:561, harness-engines:758). Verify: RC1, or recount `^\s*Check '` and the Want labels in tests/harness-visibility.ps1. Remedy: Update claim 6 to the current suite list and count; attribute GUARD to the harnesses that own it.
- **F20-3** [note] `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md:7` - 'Commit under review: 65f5649 (main, 0.5.0 candidate)' no longer describes the tree (0.6.0, waves 25-29c in between; the continuation alone carries wave 24b/24c/29b gates), so 'cite lines of 65f5649' is impossible and all cites here are current-tree lines. Same drift class as F13-5. Trigger: Treating the brief's commit framing as the state of the reviewed code. Evidence: read-code: wave 24b (F08-2/F08-3) and wave 29b (E12) continuation gates beyond the wave-24 claim text; assumed: no git log run in this read-only consultation. Verify: RC2. Remedy: Re-frame the brief on the current release/commit range.
- **F20-4** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:6291`, `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md:29` - Claim 5's 'a usage limit without a reset time is out for exactly 60 minutes on every surface' holds for usage limits (Until = Hit+60; still out at 59 min, cleared at 61), but since wave 24c a bare burst 429 without a limit is out 10 minutes on the same surfaces; the absolute wording hides the second constant. Trigger: A burst 429 with no usage-limit phrase and no reset time (the byteplus message the harness classifies). Evidence: read-code: 'the 60 minutes it stays out ((wave 24c) 10 for a burst)'; read-code: 60-min Until and 59/61-min boundary checks for a quota without reset; burst 429 asserted out for 10 min. Verify: RC1 (the harness's UNIT24C/BURST cases). Remedy: Extend claim 5: 60 min for a usage limit, 10 min for a bare burst 429.
- **F20-5** [note] `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md:28`, `.collab/ab-mimo-2026-10-08/handoffs/04-claude-ab-wave24-acceptance.md:39` - The brief's finding ids are the earlier task's and collide with this task's: claim 4's 'F15-1' (muse billing guard -Fresh) is the muse task's id while THIS task's F15-1 is the kick-ack drift finding, and ask 1's F02-9, F02-10, F02-11, F03-4, F03-5, F04-9, F04-10 are not open ids of this task (its open set is F13-*/F15-*/F18-*). Those seven are ruled unknown-id here. Trigger: Ask 1's instruction to rule F02-9…F04-10 against this prompt's open-findings list. Evidence: read-code: brief cites 'F15-1' for the muse guard and names F02-9…F04-10 as wave 24's findings; inferred: that list's F15-1 claim is the kick acknowledgement drift, not muse auth.json. Verify: Grep .collab/ab-mimo-2026-10-08/findings.json for F02-9 (expect absent) and F13-1 (expect present). Remedy: Namespace brief-local finding ids per task (e.g. wave24-F15-1).

### Prior findings

- F13-1 - not-checked - pid/start-time reuse race on the flush lock and -Forget marker not re-examined (outside this checkpoint).
- F13-2 - still-open - Re-read common:12596-12617: the PS 5.1 fallback still ends in [IO.File]::Replace (12607) with no missing-destination branch, unlike Write-TextAtomic (common:187: File.Move when the destination does not exist).
- F13-3 - not-checked - Exit-TelemetryFlushLock's delete-after-dispose window not re-read.
- F13-4 - not-checked - Repeated-ask first-line truncation not re-read.
- F13-5 - still-open - tests/ still has 22 harness-*.ps1 (brief 01's 'twenty'); the stale commit-range half needs RC2.
- F15-1 - still-open - Grep finds no pending-record state `kicked` - only the legacy ack-text parse (common:10752-53) and the unrelated $kickedContinuation flag; brief 02 D1 wording unchanged.
- F15-2 - still-open - Warnings still read 'machine-wide health not updated at the commit/... by the retry after the commit' (codex-consult.ps1:6076, 6122); the literal '(lock timeout)' string is absent.
- F15-3 - not-checked - Tool-suspension cap (2x-StallSec) and the claude tool_use path not re-read this session (see RC3).
- F18-1 - still-open - NotSpooledOwn per-producer file at common:11380; Remove-TelemetrySpoolLines still FileMode.Create on a fixed .tmp (12596), deleted only on the emptied path (12592).
- F18-2 - still-open - 22 harness files now vs the recorded 20-harness suite runs; 'Both full suites end 0 failed' still unconfirmable read-only (RC1).

## Verdict: ADVISE

Checkpoint of wave 24's claims on the current tree: the behavioural invariants hold and only wording/counts drift (findings #1-#5), none of them a blocker or major.

### Blockers

_(none)_

### Unproven scenarios

- End-to-end continuation and salvage behaviour (static read only; no engine run).
- Claim 6's 'field-order assertions updated in four harnesses' - not located in code.
- 0-failed suite results on this tree (RC1).
- Prior findings F13-1, F13-3, F13-4, F15-3 (not re-examined).

### First-run checklist (observable)

_(none)_
