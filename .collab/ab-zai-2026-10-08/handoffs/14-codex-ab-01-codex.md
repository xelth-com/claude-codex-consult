# Handoff 14 - Codex: ab-01-codex

Date: 2026-10-08 01:25 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: b5cb34bb-9053-490e-bae9-48f2557b6a1d.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-ef5ec8f0d64a42fcad8f614180df8600.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread; no thread of lineage ZAI :: glm-5.3 in this task's ledger; other lineage(s): ZAI-claude :: glm-5.3 [claude]). Result thread: `01a118b0-021d-7442-bf1d-65f86ea72079` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/01-claude-ab-wave28d-acceptance.md` (sha256 c54a39cee3e0). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 475 s. Tokens: in 2915618 (cached 2783744), out 11389, reasoning 6036.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Checkpoint review found the wave’s substantive fixes present, with only a note-level deadline-wording drift plus the two already-listed open findings. Findings: 0 blocker, 0 major, 0 minor, 1 note (F14-1, tracked in `findings.json`). Structured reply: `handoffs/14-codex-ab-01-codex.reply.json`.
Raw event stream: `handoffs/14-codex-ab-01-codex.events.jsonl`.
Verbatim reply follows.

---

**Current tree:** HEAD is `b0fa03c`; `d65e2e9` is an ancestor, so I reviewed the later current code, not the named commit literally.

## 1. Finding statuses

- **F48-1 / F49-3 fixed** — `Remove-TelemetrySpoolLines` reads under the telemetry lock, writes flushed `$Path.tmp`, then atomically moves it over the spool; no in-place truncation (`codex-consult-common.ps1:12558-12618`).
- **F48-2 fixed** — markers record pid/start identity and are healed when their owner is gone; `-Forget` removes the marker in `finally` (`:11460-11495`, `:13172-13227`).
- **F48-3 / F49-4 fixed** — the flush lock is created as a complete owner record via a non-overwriting move; dead/old malformed locks are removed, living owners never taken over (`:12638-12714`).
- **F48-4 fixed** — no prompt hash occurs in the plugin; the re-read text is subtracted from the fork/resume estimate (`codex-consult.ps1:4167-4173`).
- **F49-1 fixed** — survivor and unverified-descendant groups are appended in warnings/outcomes (`codex-consult.ps1:1768-1805`, `:4710-4716`, `:5330-5338`).
- **F49-2 fixed** — not-spooled entries append without the telemetry lock; current producers use one file per process (`codex-consult-common.ps1:12088-12105`).
- **F50-1 fixed** — model and table entries are both lower-cased (`:11685-11698`).
- **F50-2 fixed** — inline asks are repeated for `context_tokens` members (`codex-consult.ps1:4129-4146`).

## 2. Requested edge cases

A stray `.tmp` is safely replaced with `FileMode.Create`; current senders cannot overlap because the flush lock is acquired first. A missing spool remains F13-2: `Open` returns null for absence, but the caller says “stayed busy” (`codex-consult-common.ps1:11861-11870`, `:12578-12579`). Current markers add full-resolution `start_ticks`; unknown identity fails closed (`:11463-11479`, `codex-consult-detached.ps1:191-217`). Racing senders serialize on the owner-bearing lock. The stuck line is not automatically recovered while its owner lives—manual stop/deletion is the designed limitation—but it is deduplicated and removed after the lock disappears (`:12689-12696`, `:12965`). Per-producer counter files remove the PS 5.1 shared-append race. Multi-line asks now repeat the first line plus “(+N more lines)” (`codex-consult.ps1:4132-4144`).

The only new drift is finding #1: the literal D1 “deadline checked before rewrite” clause no longer matches the always-attempt delivered-line rewrite.

The test count claim is stale: 22 harnesses exist and `run-all.ps1:20` names 22; `harness-fixes28d.ps1` still has exactly 40 checks. I did not execute the suites.

## 3. Verdict basis

No blocker or major remains; acceptance would otherwise be plausible after reconciling the deadline wording and stale test-count claim.

## Requested checks

- **RC1** — From the repository root, run `powershell -NoProfile -ExecutionPolicy Bypass -File tests\run-all.ps1` (workspace-write/temp-write). Confirm all 22 harnesses pass and `harness-fixes28d` reports `PASS=40 FAIL=0`; budget about 60 minutes.

---

### Findings

- **F14-1** [note] `plugins/codex-consult/scripts/codex-consult-common.ps1:12918`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12922`, `plugins/codex-consult/scripts/codex-consult-common.ps1:12574` - The current flush does not literally check that deadline remains before starting a delivered-line rewrite: after checking only lock ownership, it calls Remove-TelemetrySpoolLines with Math.Max(100, remaining time), so a rewrite can start after the deadline and wait at least 100 ms. This is safe against duplicate delivery but drifts from the D1 wording. Trigger: The final request consumes the entire flush budget after successfully delivering lines. Evidence: read-code: Only lock ownership is checked immediately before the rewrite; the rewrite wait is clamped to a minimum of 100 ms even when remaining time is negative.; read-code: The surrounding design comments explicitly make delivered-line rewrites an exception that is always attempted. Verify: In test mode, exhaust FlushMs immediately after a successful delivery and observe whether the rewrite still begins after the nominal deadline. Remedy: Either restore a pre-rewrite deadline gate with a documented delivered-lines exception, or update the invariant/comments/tests to state that delivered-line rewrites are intentionally deadline-exempt and bounded by Math.Max(100, remaining time).

### Prior findings

- F13-1 - still-open - The current tree has 22 harness scripts, run-all.ps1 names 22, and harness-fixes28d still has 40 checks; the brief’s “twenty harnesses” is stale.
- F13-2 - still-open - A missing spool still returns null from Open-TelemetrySpoolFile and is mislabeled “stayed busy” by Remove-TelemetrySpoolLines; behavior remains safe.

## Verdict: ADVISE

Checkpoint review found the wave’s substantive fixes present, with only a note-level deadline-wording drift plus the two already-listed open findings.

### Blockers

_(none)_

### Unproven scenarios

- No harness was executed in this read-only consultation, so current Windows PowerShell 5.1 and PowerShell 7 pass/fail counts are unverified.
- Concurrency and pid-reuse edge cases were assessed from code, not stress-tested.

### First-run checklist (observable)

_(none)_
