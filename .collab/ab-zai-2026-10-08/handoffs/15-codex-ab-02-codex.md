# Handoff 15 - Codex: ab-02-codex

Date: 2026-10-08 01:33 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from -Provider, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 2 of 12 for -Provider ZAI (model applied).
Effort: high sent (requested medium, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: 7ecc2e1c-144b-4f37-86de-6bcc0d6b1c0f.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-d33a0a35d9df443bbe47e89b8a8ba446.md --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118b7-6d8f-75e3-bcbe-4f7a75054668` (source: events).
Brief: `.collab/ab-zai-2026-10-08/handoffs/02-claude-ab-wave26c-decisions.md` (sha256 087f36fa4147). Reviewed: b0fa03c, base b0fa03c2aa24fa8e5f5629db9385212552e2c3cb, tree sha256 08a985064631, 0 changed files.
Bridge outcome: usable reply. Wall time: 611.1 s. Tokens: in 4576264 (cached 4473088), out 12693, reasoning 6346.
Warnings: oversized_lines: 1 event line(s) longer than 1 MiB were not parsed by the stall timer's reader (its activity counts bytes; the reply is read from the whole stream).
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The current code substantiates D1, D2, D4, D5, and D6, while D3 contains one documented later-wave behavioral drift. Findings: 0 blocker, 0 major, 0 minor, 1 note (F15-1, tracked in `findings.json`). Structured reply: `handoffs/15-codex-ab-02-codex.reply.json`.
Raw event stream: `handoffs/15-codex-ab-02-codex.events.jsonl`.
Verbatim reply follows.

---

Reviewed the current tree at `b0fa03c`; no harnesses were run because this consultation is read-only.

**D1 — holds, with protocol evolution.** `Wait-EngineProcess` checks the kick before the loop, on each poll, and after `WaitForExit`; a late kick is consumed, acknowledged `late`, recorded as `kick_late`, and does not change the outcome. `-Kick` waits 10 s for an id-bearing `.ack`, with exits 0/1/3 and file behavior as claimed. The current acknowledgement signal is the `.ack`; no pending-record `state: kicked` path remains.

**D2 — holds in substance.** The health lock defaults to three 5 s attempts. A failed update is journaled at the ledger commit and retried after the write lock; failure appears in `warnings[]` and the summary while the ledger remains authoritative. Conversion carries stored `until` and `retry_after`; sorting makes same-time records choose the later `until`.

**D3 — partly stale.** Byte growth resets the timer, tool calls suspend it, the supported engine events are present, and the continuation text is exact. However, wave 28b now caps suspension at `2 x StallSec` without stream growth and then cuts while naming the open tool. Therefore the copied claim that a member running one long command is “never cut” no longer describes the current code; see finding #1.

**D4 — holds.** `Test-BlankField` treats absent/null, blank/whitespace, and empty enumerable fields as missing; completion joins by `consult_id`, and the harness covers an empty `model`.

**D5 — holds.** Required overflow raises the seat count, warns on console and in member warnings/header, records `size_asked` and `size_source: required`, and the routing line states the requested count.

**D6 — holds.** The role-file check rejects reparse points and outside-containment paths; README “Roles” states the accepted hard-link/hostile-repository limitation.

Prior findings: F13-1, F13-2, and F14-1 remain still-open as described in `prior_findings`.

---

### Findings

- **F15-1** [note] `.collab/ab-zai-2026-10-08/handoffs/02-claude-ab-wave26c-decisions.md:25`, `plugins/codex-consult/scripts/codex-consult-common.ps1:10997`, `plugins/codex-consult/scripts/codex-consult-common.ps1:11030`, `tests/harness-fixes28b.ps1:216` - The re-asked D3 invariant says an in-flight tool call is suspended so a long command is never cut, but the current implementation cuts after 2 x StallSec without stream growth while a tool remains open. Trigger: An engine starts a tool call and appends no stream bytes for at least twice the configured stall threshold before the hard timeout. Evidence: read-code: The brief states the unconditional never-cut behavior.; read-code: `toolQuietMs` is `2 * stallMs`; when an open tool and no byte growth reach that bound, Reason becomes stall and OpenTools names the call.; read-code: The current wave 28b harness explicitly expects a silent open muse tool to stall after 4 s with a 2 s StallSec. Verify: From the repository root, run `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/harness-fixes28b.ps1 -Only STALL`; the STALL check should pass with Reason stall and a named OpenTools value. Remedy: Update the re-asked D3 wording to the binding wave 28b D12 behavior—suspension continues only while the stream grows and is capped at 2 x StallSec—or remove the cap if the never-cut invariant is still required.

### Prior findings

- F13-1 - still-open - The tree still has 22 `tests/harness-*.ps1` scripts; `harness-fixes28d.ps1` still has 40 Check calls.
- F13-2 - still-open - `Open-TelemetrySpoolFile` still returns null for a missing FileMode.Open file, and `Remove-TelemetrySpoolLines` still maps that null to “stayed busy.”
- F14-1 - still-open - The rewrite call still uses `Math.Max(100, remaining)` after only the lock-ownership check, so a delivered-line rewrite can begin after the nominal deadline.

## Verdict: ADVISE

The current code substantiates D1, D2, D4, D5, and D6, while D3 contains one documented later-wave behavioral drift.

### Blockers

_(none)_

### Unproven scenarios

_(none)_

### First-run checklist (observable)

_(none)_
