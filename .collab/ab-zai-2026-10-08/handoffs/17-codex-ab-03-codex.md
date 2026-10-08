# Handoff 17 - Codex: ab-03-codex

Date: 2026-10-08 01:47 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 0ca6c16a-135d-4ec5-80df-45920d44a03f.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-8c12a765242e49e4ab924066598e5522.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118c3-aa3a-7282-adfe-369dba8c613f` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/03-claude-ab-wave28d-decisions.md` (sha256 8e7a6383d633). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 321.2 s. Tokens: in 1463556 (cached 1398400), out 11425, reasoning 7030.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - All eight invariants hold in substance on the current tree; the only drift is wording (brief D1 deadline sentence per F14-1, brief D4/D7 predating wave 28e) plus stale harness-count texts, none blocking. Findings: 0 blocker, 0 major, 0 minor, 2 note (F17-1..F17-2, tracked in `findings.json`). Structured reply: `handoffs/17-codex-ab-03-codex.reply.json`.
Raw event stream: `handoffs/17-codex-ab-03-codex.events.jsonl`.
Verbatim reply follows.

---

**D1 — holds, with one wording drift.** `Remove-TelemetrySpoolLines` (codex-consult-common.ps1:12571) writes `$Path.tmp`, flushes to disk, and replaces the spool in one step (Move / MoveFileEx 0x9 / Replace); nothing truncates in place, a stray `.tmp` is replaced by the next rewrite, and the gated crash hook exists. Drift (F14-1, still open): the flush calls it with `Math.Max(100, …remaining)` (:12922), so a delivered-line rewrite always starts — even past the deadline, waiting at least 100 ms. The deadline bounds the pre-rewrite waits; it is not a start gate. Safe (at-least-once), but the brief's last D1 sentence is not literal.

**D2 — holds.** The marker holds pid, start_time (plus 28e `start_ticks`) and since; `-Forget` writes it under the telemetry lock and removes it in `finally`; `Resolve-TelemetryForgetting` removes a dead-owner/no-owner marker under the lock with one `.last` note; a living owner blocks producers and the sender.

**D3 — holds.** `Enter-TelemetryFlushLock` writes the owner record to `<lock>.<guid>.tmp` and moves it into place without overwriting; an ownerless/unreadable lock is HELD under 30 s, then removed under an exclusive handle; a living owner is never taken over; past 30 minutes `.last` and `-Status` say `sender stuck since <t> (pid <n>)`.

**D4 — substance holds, wording stale.** Since wave 28e the count lives in per-producer files `telemetry-not-spooled-<pid>-<ticks>.ndjson` (plus a staged legacy single file), appended without the telemetry lock; a flush folds gone producers' files into `.last` (`not_spooled_seen`/`not_spooled_folded`) and `-Status` sums complete lines since the last flush (finding #1).

**D5 — holds.** `Get-KillUnverifiedText` appends the unverified group beside survivors in the warning and the outcome text (turn, main turn, repair); 28e E1/E18 additionally keep the record for unverified-only kills.

**D6 — holds.** `Get-TelemetryModelToken` lower-cases both sides.

**D7 — holds for one-line asks; 28e E4 extended it.** A multi-line inline ask repeats its first line plus `(+<n> more lines)`, cut at 300 characters.

**D8 — holds.** No prompt-text hash exists; thread reuse is identity/endpoint/rollout-verified; the fork/resume context estimate subtracts the re-read line (codex-consult.ps1:4169-4172); the CHANGELOG states the audit.

**Harness cases / suites.** The D1-D7 cases exist in `harness-fixes28d` (REWRITE, MARKER, LOCK, NOTSPOOLED, KILL, MODEL, REREAD, DOCS, GUARD — exactly 40 `Check` calls). "Both full suites end `0 failed`" was not re-run here (read-only consultation). `run-all.ps1` now registers **22** harnesses; the tree's "twenty/twentieth" texts are stale (finding #2, F13-1).

## Requested checks
- **RC1** — `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28d.ps1` from the repo root (workspace-write; ~2 min): expect 40 PASS, 0 FAIL — settles D1-D7 runtime behavior.
- **RC2** — `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1` from the repo root (workspace-write): expect `22 harness(es), 0 failed`.
- **RC3** — `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28b.ps1 -Only STALL` from the repo root (workspace-write): expect Reason `stall` with a named `OpenTools` (F15-1).

---

### Findings

- **F17-1** [note] `.collab/ab-zai-2026-10-08/handoffs/03-claude-ab-wave28d-decisions.md:25`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12096`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12196`, `plugins/codex-consult/scripts/codex-consult.ps1:4136` - The brief's D4 and D7 wordings predate wave 28e: the not-spooled count is no longer one append-only file but per-producer files plus a flush fold (legacy file staged, not_spooled_seen/not_spooled_folded), and a multi-line inline ask repeats its first line plus '(+n more lines)', cut at 300 characters. The substance of both invariants (count cannot be lost, written without the telemetry lock, counted since the last flush; re-read line exists for inline prompts) still holds. Trigger: Reading the brief's D4/D7 against Add-TelemetryNotSpooled/Get-TelemetryNotSpooled/Merge-TelemetryNotSpooled and the reread-line block added by wave 28e E2/E4. Evidence: read-code: NotSpooledOwn per-producer file appended without the telemetry lock; Get-TelemetryNotSpooled sums all files less not_spooled_seen; Merge-TelemetryNotSpooled folds gone producers' files with not_spooled_folded and legacy staging.; read-code: Multi-line ask: first line repeated whole, cut at 300 chars, plus '(+n more lines)' (wave 28e E4).; read-code: Checks NOTSPOOLED (per-producer files, fold) and ANCHOR (multi-line ask) cover exactly these behaviors. Verify: Run tests/harness-fixes28e.ps1 and confirm the NOTSPOOLED and ANCHOR cases pass on the current tree. Remedy: When this brief is re-baselined, reword D4 (per-producer files + fold) and D7 (first line + count, 300-char cut) to the wave-28e behavior; no code change needed.
- **F17-2** [note] `tests/README.md:23`, `tests/run-all.ps1:1` - tests/README.md still says harness-claude.ps1 is 'the twentieth harness of run-all.ps1', but run-all.ps1 registers twenty-two harnesses with harness-claude last (harness-fixes28e and harness-claude were added after that sentence was written). Trigger: Comparing tests/README.md's count with the harness list in tests/run-all.ps1. Evidence: ran-command: 22 harness-*.ps1 scripts; run-all.ps1 line 1 says 'twenty-two, harness-claude the last'; tests/README.md line 23 says 'twentieth'. Verify: Count the entries in $harnesses in tests/run-all.ps1 (22) against the 'twentieth' sentence in tests/README.md. Remedy: Update tests/README.md to say twenty-second (or drop the ordinal).

### Prior findings

- F13-1 - still-open - tests/ holds 22 harness-*.ps1 scripts (run-all.ps1: 'twenty-two, harness-claude the last'); harness-fixes28d still has exactly 40 Check calls. The CHANGELOG's '20 harness(es)' lines are dated run records, but tests/README.md:23 still says 'twentieth' (finding #2).
- F13-2 - still-open - Remove-TelemetrySpoolLines (codex-consult-common.ps1:12578-12579) still returns 'the spool file ... stayed busy' when Open-TelemetrySpoolFile returns $null for a missing file (FileMode.Open).
- F14-1 - still-open - Invoke-TelemetryFlush still calls Remove-TelemetrySpoolLines with Math.Max(100, min(2000, remaining)) at :12922, so a delivered-line rewrite can start after the deadline; the 28c-D5 comment documents this as intentional (always attempt the rewrite).
- F15-1 - still-open - Wait-EngineProcess still ends the tool suspension after 2 x StallSec without stream growth and cuts (Reason stall, named OpenTools); harness-fixes28b STALL checks present at lines 199-226.
- F16-1 - still-open - No 'kicked' pending-record state exists; -Kick waits up to 10 s only for <kick file>.ack {id, result} (codex-consult.ps1:1277-1303).
- F16-2 - still-open - The literal 'machine-wide health not updated (lock timeout)' is absent; current texts at codex-consult.ps1:6076 and :6122 are the cause-bearing retry/journal wordings; substance (retry at commit, warn, ledger truth) holds.
- F16-3 - still-open - Wait-EngineProcess's wave-26c D3 header comment (~:10960) still says a long command 'is never cut', contradicting the D12 note (~:10972) and the body's 2 x StallSec tool-open cut.

## Verdict: ADVISE

All eight invariants hold in substance on the current tree; the only drift is wording (brief D1 deadline sentence per F14-1, brief D4/D7 predating wave 28e) plus stale harness-count texts, none blocking.

### Blockers

_(none)_

### Unproven scenarios

- The 'both full suites end 0 failed' claim was not re-run (read-only consultation); only harness content and code were read.
- Runtime behaviors of the fold crash-hooks (E20/E24/E26) and the rewrite-crash hook were verified by reading code and harness expectations, not by execution.

### First-run checklist (observable)

_(none)_
