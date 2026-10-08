# Handoff 17 - Codex: ab-03-codex

Date: 2026-10-08 02:10 local. Author: Codex (model mimo-v2.6-pro, effort medium), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from -Provider, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/.codex/codex-consult-roster-0.6.json - entry 3 of 12 for -Provider mimo (model, codex_config applied).
Effort: medium sent (requested medium, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: a9f3942b-7c2c-49a1-a81f-d54074f420de.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="medium" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-a945ab9808b548dea416700b3dcc6802.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a118d9-3759-7310-844e-71af65775195` (source: events).
Brief: `.collab/ab-mimo-2026-10-08/handoffs/03-claude-ab-wave28d-decisions.md` (sha256 8e7a6383d633). Reviewed: 65380b2, base 65380b2c73417519c2066af0ee4734b7bdabcfd8, tree sha256 8b59695d4998, 0 changed files.
Bridge outcome: usable reply. Wall time: 642.6 s. Tokens: in 1639345 (cached 519296), out 14775, reasoning 8185.
Timeout: 1800 s (-TimeoutSec); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The current code preserves the D1-D8 behavioral invariants, but wording drift and the eight listed prior risks remain open. Findings: none. Structured reply (prompt-only transport): `handoffs/17-codex-ab-03-codex.reply.json`.
Raw event stream: `handoffs/17-codex-ab-03-codex.events.jsonl`.
Verbatim reply follows.

---

**D1.** Holds on the main path: the spool rewrite is serialized, writes a flushed `<spool>.tmp`, then replaces the spool; an emptied spool is deleted and `.tmp` cleaned. The deadline is checked before a rewrite. Drift: the PS 5.1 `File.Replace` fallback is not atomic and lacks a missing-destination branch (F13-2); `.tmp` handling is replace-or-delete (F13-5).

**D2.** Holds: the marker records pid/start_time/start_ticks/since, is removed in `finally`, dead-owner markers are healed under the lock, and living owners block. Pid-reuse identity risk remains (F13-1).

**D3.** Holds: the owner record is flushed to a temp file and moved into place without overwrite; ownerless/unreadable locks are held for 30 s then removed; living owners are never taken over and `sender stuck since ...` appears after 30 minutes. Lock-delete race remains (F13-3).

**D4.** Count preservation holds without the telemetry lock, but current code uses one append-only file per producer plus legacy/staged files, not one shared file (F13-5).

**D5.** Holds: survivors and unverified descendants are both named in warning and outcome text.

**D6.** Holds: model comparison lower-cases both sides.

**D7.** Holds: inline prompts get a repeated tail ask. Multi-line asks repeat only the first non-blank line plus a count (F13-4).

**D8.** Holds: the re-read line is excluded from the thread-continuation estimate and the root CHANGELOG records the audit. Current tree is HEAD 65380b2 (0.6.0+); historical commit/range and harness-count wording are stale (F13-5).

---

### Findings

_(none)_

### Prior findings

- F13-1 - still-open - Marker ticks are recorded, but flush-lock identity still stores only pid+start_time; pid-reuse collision risk remains.
- F13-2 - still-open - PS 5.1 File.Replace fallback still has no missing-destination branch.
- F13-3 - still-open - Exit-TelemetryFlushLock still deletes after disposing its read handle.
- F13-4 - still-open - Multi-line inline re-read still keeps only the first non-blank line plus a count.
- F13-5 - still-open - Current drift persists: per-producer not-spooled files, replace-or-delete .tmp semantics, 22 test files, and stale historical commit/range wording.
- F15-1 - still-open - Kick acknowledgement remains id-matched .ack with stopped|late and exit 4 for refused queries; legacy plain-text `kicked` parsing exists but no pending `kicked` state.
- F15-2 - still-open - Health warnings use the newer commit/retry wording and the journal preserves the record.
- F15-3 - still-open - Tool suspension is capped at 2 x StallSec and claude tool_use/tool_result is supported, so `never cut` is conditional.

## Verdict: ADVISE

The current code preserves the D1-D8 behavioral invariants, but wording drift and the eight listed prior risks remain open.

### Blockers

_(none)_

### Unproven scenarios

- The harness suites were not run in this read-only checkpoint.
- The pid-reuse, PS 5.1 fallback, and lock-delete race cases were not executed.
- The brief's `0 failed` suite result was not reproduced here.

### First-run checklist (observable)

_(none)_
